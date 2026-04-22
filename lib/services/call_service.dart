import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/call_models.dart';
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
  }) {
    return _updateCallStatus(
      callId: callId,
      status: status,
      endedAt: Timestamp.now(),
    );
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

  Future<Map<String, String>> _loadCurrentUserProfile() async {
    final uid = currentUserId;
    final fallbackName = _auth.currentUser?.displayName?.trim() ?? 'User';
    final fallbackAvatar = _auth.currentUser?.photoURL?.trim() ?? '';
    if (uid.isEmpty) {
      return {'name': fallbackName, 'avatar': fallbackAvatar};
    }

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data() ?? const <String, dynamic>{};
      final name = (data['name'] ?? fallbackName).toString();
      final avatar = (data['avatar'] ?? fallbackAvatar).toString();
      return {'name': name, 'avatar': avatar};
    } catch (_) {
      return {'name': fallbackName, 'avatar': fallbackAvatar};
    }
  }
}
