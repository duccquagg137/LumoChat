import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/call_models.dart';
import '../utils/app_logger.dart';
import '../utils/retry_policy.dart';
import 'notification_service.dart';

class CallService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _calls =>
      _firestore.collection('calls');

  Future<String> startOutgoingCall({
    required String calleeId,
    required String calleeName,
    required String calleeAvatar,
    required CallType type,
  }) async {
    final callerId = currentUserId;
    if (callerId.isEmpty || calleeId.isEmpty) {
      throw StateError('missing-call-participant');
    }

    final callerProfile = await _loadCurrentUserProfile();
    final now = Timestamp.now();
    final doc = _calls.doc();

    await RetryPolicy.run(
      operation: 'calls.start',
      task: () async {
        await doc.set({
          'callerId': callerId,
          'callerName': callerProfile['name'] ?? '',
          'callerAvatar': callerProfile['avatar'] ?? '',
          'calleeId': calleeId,
          'calleeName': calleeName,
          'calleeAvatar': calleeAvatar,
          'participants': [callerId, calleeId],
          'type': type.key,
          'status': CallStatus.ringing.key,
          'createdAt': now,
          'updatedAt': now,
          'acceptedAt': null,
          'endedAt': null,
          'offer': null,
          'answer': null,
          'callerCandidates': const <Map<String, dynamic>>[],
          'calleeCandidates': const <Map<String, dynamic>>[],
        });
      },
    );

    final callerName = (callerProfile['name'] ?? '').trim();
    final notification = NotificationService();
    final callKind = type == CallType.video ? 'video' : 'voice';
    await notification.createNotification(
      recipientId: calleeId,
      type: 'incoming_$callKind',
      title: type == CallType.video ? 'Cuộc gọi video đến' : 'Cuộc gọi đến',
      body: callerName.isEmpty
          ? 'Bạn đang có một cuộc gọi mới'
          : '$callerName đang gọi cho bạn',
      senderId: callerId,
      entityId: doc.id,
      data: {'callId': doc.id, 'callType': type.key},
    );

    return doc.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingRingingCalls() {
    if (currentUserId.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _calls
        .where('calleeId', isEqualTo: currentUserId)
        .where('status', isEqualTo: CallStatus.ringing.key)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCall(String callId) {
    return _calls.doc(callId).snapshots();
  }

  Future<AppCall?> getCallById(String callId) {
    return _readCall(callId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCallHistory() {
    if (currentUserId.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _calls
        .where('participants', arrayContains: currentUserId)
        .snapshots();
  }

  Future<void> acceptCall(String callId) {
    return _updateCallStatus(
      callId: callId,
      status: CallStatus.accepted,
      acceptedAt: Timestamp.now(),
    );
  }

  Future<void> declineCall(String callId) async {
    final call = await _readCall(callId);
    if (call == null) return;
    await _completeCall(callId: callId, status: CallStatus.declined);

    final callerId = call.callerId;
    if (callerId.isNotEmpty && callerId != currentUserId) {
      await NotificationService().createNotification(
        recipientId: callerId,
        senderId: currentUserId,
        type: 'call_declined',
        title: 'Cuộc gọi bị từ chối',
        body: '${call.calleeName} đã từ chối cuộc gọi',
        entityId: callId,
        data: {'callId': callId},
      );
    }
  }

  Future<void> cancelCall(String callId) {
    return _completeCall(callId: callId, status: CallStatus.cancelled);
  }

  Future<void> markMissed(String callId) async {
    final call = await _readCall(callId);
    if (call == null || call.status != CallStatus.ringing) return;

    await _completeCall(callId: callId, status: CallStatus.missed);
    final callerId = call.callerId;
    if (callerId.isNotEmpty && callerId != currentUserId) {
      await NotificationService().createNotification(
        recipientId: callerId,
        senderId: currentUserId,
        type: 'call_missed',
        title: 'Cuộc gọi nhỡ',
        body: '${call.calleeName} chưa trả lời cuộc gọi',
        entityId: callId,
        data: {'callId': callId},
      );
    }
  }

  Future<void> endCall(String callId) {
    return _completeCall(callId: callId, status: CallStatus.ended);
  }

  Future<void> setOffer({
    required String callId,
    required Map<String, dynamic> offer,
  }) async {
    if (callId.isEmpty || currentUserId.isEmpty) return;
    await _calls.doc(callId).set({
      'offer': offer,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> setAnswer({
    required String callId,
    required Map<String, dynamic> answer,
  }) async {
    if (callId.isEmpty || currentUserId.isEmpty) return;
    await _calls.doc(callId).set({
      'answer': answer,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> addIceCandidate({
    required String callId,
    required bool isCallerSide,
    required Map<String, dynamic> candidate,
  }) async {
    if (callId.isEmpty || currentUserId.isEmpty) return;
    final key = isCallerSide ? 'callerCandidates' : 'calleeCandidates';
    await _calls.doc(callId).set({
      key: FieldValue.arrayUnion([candidate]),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> _completeCall({
    required String callId,
    required CallStatus status,
  }) async {
    final call = await _readCall(callId);
    if (call == null) return;

    if (_isTerminalStatus(call.status)) {
      final endedAt = call.endedAt == null
          ? Timestamp.now()
          : Timestamp.fromDate(call.endedAt!);
      await _tryWriteCallChatMessage(
        call: call,
        status: call.status,
        endedAt: endedAt,
      );
      return;
    }

    final endedAt = Timestamp.now();
    await _updateCallStatus(
      callId: callId,
      status: status,
      endedAt: endedAt,
    );
    await _tryWriteCallChatMessage(
      call: call,
      status: status,
      endedAt: endedAt,
    );
  }

  Future<void> _tryWriteCallChatMessage({
    required AppCall call,
    required CallStatus status,
    required Timestamp endedAt,
  }) async {
    try {
      await _writeCallChatMessage(
        call: call,
        status: status,
        endedAt: endedAt,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unable to write call history message',
        tag: 'call',
        error: error,
        stackTrace: stackTrace,
        context: {
          'callId': call.id,
          'status': status.key,
        },
      );
    }
  }

  Future<void> _updateCallStatus({
    required String callId,
    required CallStatus status,
    Timestamp? acceptedAt,
    Timestamp? endedAt,
  }) async {
    if (callId.isEmpty || currentUserId.isEmpty) return;
    final updates = <String, dynamic>{
      'status': status.key,
      'updatedAt': Timestamp.now(),
    };
    if (acceptedAt != null) updates['acceptedAt'] = acceptedAt;
    if (endedAt != null) updates['endedAt'] = endedAt;
    await _calls.doc(callId).update(updates);
  }

  Future<AppCall?> _readCall(String callId) async {
    if (callId.isEmpty) return null;
    final doc = await _calls.doc(callId).get();
    if (!doc.exists) return null;
    return AppCall.fromDocument(doc);
  }

  Future<void> _writeCallChatMessage({
    required AppCall call,
    required CallStatus status,
    required Timestamp endedAt,
  }) async {
    if (call.callerId.isEmpty || call.calleeId.isEmpty) return;
    final senderId = currentUserId;
    if (!call.isParticipant(senderId)) return;
    final receiverId = call.peerIdFor(senderId);

    final roomId = _buildChatRoomId(call.callerId, call.calleeId);
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc('call_${call.id}');
    final durationSeconds = _callDurationSeconds(call, endedAt);
    final text = _callMessageText(
      type: call.type,
      status: status,
      durationSeconds: durationSeconds,
    );

    await RetryPolicy.run(
      operation: 'chat.write_call_message',
      task: () async {
        await roomRef.set({
          'lastMessage': text,
          'lastTimestamp': endedAt,
          'participants': [call.callerId, call.calleeId],
        }, SetOptions(merge: true));

        await messageRef.set({
          'id': messageRef.id,
          'senderId': senderId,
          'receiverId': receiverId,
          'senderName': 'Hệ thống',
          'text': text,
          'type': 'system',
          'timestamp': endedAt,
          'sentAt': endedAt,
          'isRead': true,
          'status': 'read',
          'systemGenerated': true,
          'callId': call.id,
          'callType': call.type.key,
          'callStatus': status.key,
          'callDurationSeconds': durationSeconds,
          'callAcceptedAt': call.acceptedAt == null
              ? null
              : Timestamp.fromDate(call.acceptedAt!),
          'callEndedAt': endedAt,
        }, SetOptions(merge: true));
      },
    );
  }

  int _callDurationSeconds(AppCall call, Timestamp endedAt) {
    final acceptedAt = call.acceptedAt;
    if (acceptedAt == null) return 0;
    final seconds = endedAt.toDate().difference(acceptedAt).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  String _callMessageText({
    required CallType type,
    required CallStatus status,
    required int durationSeconds,
  }) {
    final kind = type == CallType.video ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
    switch (status) {
      case CallStatus.ended:
        return '$kind - ${_formatCallDuration(durationSeconds)}';
      case CallStatus.missed:
        return '$kind nhỡ';
      case CallStatus.declined:
        return '$kind bị từ chối';
      case CallStatus.cancelled:
        return '$kind đã hủy';
      case CallStatus.ringing:
      case CallStatus.accepted:
      case CallStatus.unknown:
        return kind;
    }
  }

  String _formatCallDuration(int totalSeconds) {
    final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;
    if (hours > 0) {
      return '$hours giờ ${minutes.toString().padLeft(2, '0')} phút';
    }
    if (minutes > 0) {
      return '$minutes phút ${seconds.toString().padLeft(2, '0')} giây';
    }
    return '$seconds giây';
  }

  String _buildChatRoomId(String firstUserId, String secondUserId) {
    final ids = [firstUserId, secondUserId]..sort();
    return ids.join('_');
  }

  bool _isTerminalStatus(CallStatus status) {
    return status == CallStatus.declined ||
        status == CallStatus.cancelled ||
        status == CallStatus.missed ||
        status == CallStatus.ended;
  }

  Future<Map<String, String>> _loadCurrentUserProfile() async {
    final uid = currentUserId;
    final fallbackName = _fallbackCurrentUserName();
    final fallbackAvatar = _auth.currentUser?.photoURL?.trim() ?? '';
    if (uid.isEmpty) {
      return {'name': fallbackName, 'avatar': fallbackAvatar};
    }

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data() ?? const <String, dynamic>{};
      final name = _firstDisplayName([
        data['name'],
        data['username'],
        fallbackName,
      ]);
      final avatar = (data['avatar'] ?? fallbackAvatar).toString();
      return {'name': name, 'avatar': avatar};
    } catch (_) {
      return {'name': fallbackName, 'avatar': fallbackAvatar};
    }
  }

  String _fallbackCurrentUserName() {
    final display = _auth.currentUser?.displayName?.trim();
    if (display != null && display.isNotEmpty && !_looksLikeEmail(display)) {
      return display;
    }
    final phone = _auth.currentUser?.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    final email = _auth.currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first.trim();
    return 'User';
  }

  String _firstDisplayName(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && !_looksLikeEmail(text)) return text;
    }
    final fallback = values
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'User');
    return fallback.contains('@') ? fallback.split('@').first.trim() : fallback;
  }

  bool _looksLikeEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }
}
