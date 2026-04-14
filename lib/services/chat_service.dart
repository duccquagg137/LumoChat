import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/retry_policy.dart';

class ChatService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static const int _batchSize = 400;

  String get _currentUserId => _auth.currentUser!.uid;

  String buildChatRoomId(String receiverId) {
    final ids = [_currentUserId, receiverId]..sort();
    return ids.join('_');
  }

  DocumentReference<Map<String, dynamic>> _chatRoomRef(String receiverId) {
    return _firestore.collection('chat_rooms').doc(buildChatRoomId(receiverId));
  }

  DocumentReference<Map<String, dynamic>> _currentUserRef() {
    return _firestore.collection('users').doc(_currentUserId);
  }

  Future<void> _updateChatMeta(String receiverId, Map<String, dynamic> fields) async {
    final chatRoomId = buildChatRoomId(receiverId);
    final userRef = _currentUserRef();

    await userRef.set({}, SetOptions(merge: true));

    final updates = <String, dynamic>{};
    for (final entry in fields.entries) {
      updates['chatMeta.$chatRoomId.${entry.key}'] = entry.value;
    }

    await userRef.update(updates);
  }

  Stream<QuerySnapshot> getMessagesStream(String receiverId) {
    return _chatRoomRef(receiverId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> sendMessage(String receiverId, String text, {String? replyTo}) async {
    final timestamp = Timestamp.now();
    final chatRoomRef = _chatRoomRef(receiverId);
    final messageRef = chatRoomRef.collection('messages').doc();

    final newMessage = <String, dynamic>{
      'id': messageRef.id,
      'senderId': _currentUserId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
      'sentAt': timestamp,
      'isRead': false,
      'status': 'sent',
      'type': 'text',
      if (replyTo != null) 'replyTo': replyTo,
    };

    await RetryPolicy.run(
      operation: 'chat.send_message',
      task: () async {
        await messageRef.set(newMessage, SetOptions(merge: true));
        await chatRoomRef.set({
          'lastMessage': text,
          'lastTimestamp': timestamp,
          'participants': [_currentUserId, receiverId],
        }, SetOptions(merge: true));
        await markConversationVisible(receiverId);
      },
    );
  }

  Future<void> sendImageMessage(String receiverId, File imageFile, {String? replyTo}) async {
    final timestamp = Timestamp.now();
    final chatRoomRef = _chatRoomRef(receiverId);
    final messageRef = chatRoomRef.collection('messages').doc();

    final cloudinary = CloudinaryPublic('dds49mcmb', 'lumo_preset', cache: false);
    final imageUrl = await RetryPolicy.run<String>(
      operation: 'chat.upload_image',
      task: () async {
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            imageFile.path,
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        return response.secureUrl;
      },
    );

    final newMessage = <String, dynamic>{
      'id': messageRef.id,
      'senderId': _currentUserId,
      'receiverId': receiverId,
      'text': imageUrl,
      'timestamp': timestamp,
      'sentAt': timestamp,
      'isRead': false,
      'status': 'sent',
      'type': 'image',
      if (replyTo != null) 'replyTo': replyTo,
    };

    await RetryPolicy.run(
      operation: 'chat.send_image_message',
      task: () async {
        await messageRef.set(newMessage, SetOptions(merge: true));
        await chatRoomRef.set({
          'lastMessage': '📷 [image]',
          'lastTimestamp': timestamp,
          'participants': [_currentUserId, receiverId],
        }, SetOptions(merge: true));
        await markConversationVisible(receiverId);
      },
    );
  }

  Future<void> updateTypingStatus(String receiverId, bool isTyping) async {
    await _chatRoomRef(receiverId).set({
      'typing': {
        _currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getChatRoomStream(String receiverId) {
    return _chatRoomRef(receiverId).snapshots();
  }

  Future<void> toggleReaction(String receiverId, String messageId, String emoji) async {
    final docRef = _chatRoomRef(receiverId).collection('messages').doc(messageId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final reactions = Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
    final users = List<dynamic>.from(reactions[emoji] ?? []);

    if (users.contains(_currentUserId)) {
      users.remove(_currentUserId);
    } else {
      users.add(_currentUserId);
    }

    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }

    await docRef.update({'reactions': reactions});
  }

  DocumentReference<Map<String, dynamic>> _messageRef(String receiverId, String messageId) {
    return _chatRoomRef(receiverId).collection('messages').doc(messageId);
  }

  Future<void> recallMessageForMe(String receiverId, String messageId) async {
    final ref = _messageRef(receiverId, messageId);
    await ref.update({
      'deletedFor': FieldValue.arrayUnion([_currentUserId]),
    });
  }

  Future<void> recallMessageForEveryone(String receiverId, String messageId) async {
    final ref = _messageRef(receiverId, messageId);
    await ref.update({
      'type': 'deleted',
      'text': 'Tin nh?n dã thu h?i',
      'recalledForEveryone': true,
      'recalledAt': Timestamp.now(),
      'reactions': FieldValue.delete(),
    });

    final roomSnapshot = await _chatRoomRef(receiverId).get();
    final roomData = roomSnapshot.data();
    final pinned = roomData?['pinnedMessage'];
    if (pinned is Map && pinned['messageId']?.toString() == messageId) {
      await clearPinnedMessage(receiverId);
    }
  }

  Future<void> deleteMessage(String receiverId, String messageId) async {
    await recallMessageForEveryone(receiverId, messageId);
  }

  Future<void> setChatPinned(String receiverId, bool pinned) async {
    await _updateChatMeta(receiverId, {
      'pinned': pinned,
    });
  }

  Future<void> setPinnedMessage(
    String receiverId, {
    required String messageId,
    required String previewText,
    required String messageType,
    String? senderId,
    String? senderName,
  }) async {
    await _chatRoomRef(receiverId).set({
      'pinnedMessage': {
        'messageId': messageId,
        'previewText': previewText,
        'messageType': messageType,
        'senderId': senderId ?? '',
        'senderName': senderName ?? '',
        'pinnedBy': _currentUserId,
        'pinnedAt': Timestamp.now(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> clearPinnedMessage(String receiverId) async {
    await _chatRoomRef(receiverId).set({
      'pinnedMessage': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> hideConversation(String receiverId) async {
    await _updateChatMeta(receiverId, {
      'hidden': true,
      'hiddenAt': Timestamp.now(),
    });
  }

  Future<void> unhideConversation(String receiverId) async {
    await _updateChatMeta(receiverId, {
      'hidden': false,
      'hiddenAt': FieldValue.delete(),
    });
  }

  Future<void> markConversationVisible(String receiverId) async {
    await _updateChatMeta(receiverId, {
      'hidden': false,
      'deletedAt': FieldValue.delete(),
    });
  }

  Future<void> deleteConversationForMe(String receiverId) async {
    final roomRef = _chatRoomRef(receiverId);
    final snapshot = await roomRef.collection('messages').get();

    final docs = snapshot.docs;
    for (int i = 0; i < docs.length; i += _batchSize) {
      final end = (i + _batchSize < docs.length) ? i + _batchSize : docs.length;
      final chunk = docs.sublist(i, end);

      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {
          'deletedFor': FieldValue.arrayUnion([_currentUserId]),
        });
      }
      await batch.commit();
    }

    await _updateChatMeta(receiverId, {
      'hidden': true,
      'deletedAt': Timestamp.now(),
    });
  }

  Future<int> markMessagesDelivered(String receiverId) async {
    final now = Timestamp.now();
    final snapshot = await _chatRoomRef(receiverId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .limit(_batchSize)
        .get();

    if (snapshot.docs.isEmpty) {
      return 0;
    }

    final batch = _firestore.batch();
    var updated = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final senderId = data['senderId']?.toString();
      final receiver = data['receiverId']?.toString();
      final status = data['status']?.toString() ?? 'sent';

      final isIncoming = senderId != _currentUserId && receiver == _currentUserId;
      if (!isIncoming || status == 'delivered' || status == 'read') {
        continue;
      }

      batch.update(doc.reference, {
        'status': 'delivered',
        'deliveredAt': now,
      });
      updated++;
    }

    if (updated > 0) {
      await batch.commit();
    }

    return updated;
  }

  Future<int> markMessagesRead(String receiverId) async {
    final now = Timestamp.now();
    final snapshot = await _chatRoomRef(receiverId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .limit(_batchSize)
        .get();

    if (snapshot.docs.isEmpty) {
      return 0;
    }

    final batch = _firestore.batch();
    var updated = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final senderId = data['senderId']?.toString();
      final receiver = data['receiverId']?.toString();

      final isIncoming = senderId != _currentUserId && receiver == _currentUserId;
      if (!isIncoming) {
        continue;
      }

      final updateData = <String, dynamic>{
        'isRead': true,
        'status': 'read',
        'readAt': now,
      };
      if (data['deliveredAt'] == null) {
        updateData['deliveredAt'] = now;
      }

      batch.update(doc.reference, updateData);
      updated++;
    }

    if (updated > 0) {
      await batch.commit();
    }

    return updated;
  }
}

