import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.entityId,
    this.readAt,
    this.data = const <String, dynamic>{},
  });

  final String id;
  final String recipientId;
  final String senderId;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? entityId;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  factory AppNotificationModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final raw = doc.data() ?? const <String, dynamic>{};
    final data = raw['data'];
    return AppNotificationModel(
      id: doc.id,
      recipientId: (raw['recipientId'] ?? '').toString(),
      senderId: (raw['senderId'] ?? '').toString(),
      type: (raw['type'] ?? '').toString(),
      title: (raw['title'] ?? '').toString(),
      body: (raw['body'] ?? '').toString(),
      createdAt: _readTimestamp(raw['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: raw['isRead'] == true,
      entityId: raw['entityId']?.toString(),
      readAt: _readTimestamp(raw['readAt']),
      data: data is Map
          ? data.map((key, value) => MapEntry(key.toString(), value))
          : const <String, dynamic>{},
    );
  }

  static DateTime? _readTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    return null;
  }
}
