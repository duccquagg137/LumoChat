import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType {
  voice,
  video,
}

extension CallTypeX on CallType {
  String get key {
    switch (this) {
      case CallType.voice:
        return 'voice';
      case CallType.video:
        return 'video';
    }
  }

  static CallType fromKey(String? raw) {
    switch (raw) {
      case 'video':
        return CallType.video;
      default:
        return CallType.voice;
    }
  }
}

enum CallStatus {
  ringing,
  accepted,
  declined,
  cancelled,
  missed,
  ended,
  unknown,
}

extension CallStatusX on CallStatus {
  String get key {
    switch (this) {
      case CallStatus.ringing:
        return 'ringing';
      case CallStatus.accepted:
        return 'accepted';
      case CallStatus.declined:
        return 'declined';
      case CallStatus.cancelled:
        return 'cancelled';
      case CallStatus.missed:
        return 'missed';
      case CallStatus.ended:
        return 'ended';
      case CallStatus.unknown:
        return 'unknown';
    }
  }

  static CallStatus fromKey(String? raw) {
    switch (raw) {
      case 'ringing':
        return CallStatus.ringing;
      case 'accepted':
        return CallStatus.accepted;
      case 'declined':
        return CallStatus.declined;
      case 'cancelled':
        return CallStatus.cancelled;
      case 'missed':
        return CallStatus.missed;
      case 'ended':
        return CallStatus.ended;
      default:
        return CallStatus.unknown;
    }
  }
}

class AppCall {
  const AppCall({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.calleeId,
    required this.calleeName,
    required this.calleeAvatar,
    required this.type,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.endedAt,
    this.updatedAt,
  });

  final String id;
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String calleeId;
  final String calleeName;
  final String calleeAvatar;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final DateTime? updatedAt;

  bool isParticipant(String userId) {
    if (userId.isEmpty) return false;
    return callerId == userId || calleeId == userId;
  }

  bool isIncomingFor(String userId) => calleeId == userId;

  String peerIdFor(String userId) => isIncomingFor(userId) ? callerId : calleeId;

  String peerNameFor(String userId) => isIncomingFor(userId) ? callerName : calleeName;

  String peerAvatarFor(String userId) =>
      isIncomingFor(userId) ? callerAvatar : calleeAvatar;

  factory AppCall.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppCall(
      id: doc.id,
      callerId: (data['callerId'] ?? '').toString(),
      callerName: (data['callerName'] ?? '').toString(),
      callerAvatar: (data['callerAvatar'] ?? '').toString(),
      calleeId: (data['calleeId'] ?? '').toString(),
      calleeName: (data['calleeName'] ?? '').toString(),
      calleeAvatar: (data['calleeAvatar'] ?? '').toString(),
      type: CallTypeX.fromKey(data['type']?.toString()),
      status: CallStatusX.fromKey(data['status']?.toString()),
      createdAt: _readTimestamp(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      acceptedAt: _readTimestamp(data['acceptedAt']),
      endedAt: _readTimestamp(data['endedAt']),
      updatedAt: _readTimestamp(data['updatedAt']),
    );
  }

  static DateTime? _readTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    return null;
  }
}
