import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/retry_policy.dart';

class NotificationService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyNotifications() {
    if (currentUserId.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _notifications
        .where('recipientId', isEqualTo: currentUserId)
        .snapshots();
  }

  Future<void> createNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    String? senderId,
    String? entityId,
    Map<String, dynamic>? data,
  }) async {
    if (recipientId.isEmpty) return;
    final now = Timestamp.now();
    final resolvedSenderId = (senderId ?? currentUserId).trim();
    if (resolvedSenderId.isEmpty) return;

    await RetryPolicy.run(
      operation: 'notifications.create',
      task: () async {
        await _notifications.add({
          'recipientId': recipientId,
          'senderId': resolvedSenderId,
          'type': type,
          'title': title,
          'body': body,
          'entityId': entityId ?? '',
          'data': data ?? const <String, dynamic>{},
          'isRead': false,
          'createdAt': now,
          'readAt': null,
        });
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty || currentUserId.isEmpty) return;
    await _notifications.doc(notificationId).update({
      'isRead': true,
      'readAt': Timestamp.now(),
    });
  }

  Future<void> markAllAsRead() async {
    if (currentUserId.isEmpty) return;
    final query = await _notifications
        .where('recipientId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();
    if (query.docs.isEmpty) return;

    final batch = _firestore.batch();
    final now = Timestamp.now();
    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': now,
      });
    }
    await batch.commit();
  }
}
