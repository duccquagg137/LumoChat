import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Lấy stream tin nhắn cho một cuộc trò chuyện cụ thể
  Stream<QuerySnapshot> getMessagesStream(String receiverId) {
    final ids = [_auth.currentUser!.uid, receiverId]..sort();
    final chatRoomId = ids.join('_');

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Gửi tin nhắn mới
  Future<void> sendMessage(String receiverId, String text, {String? replyTo}) async {
    final currentUserId = _auth.currentUser!.uid;
    final timestamp = Timestamp.now();

    final ids = [currentUserId, receiverId]..sort();
    final chatRoomId = ids.join('_');

    final newMessage = <String, dynamic>{
      'senderId': currentUserId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
      'isRead': false,
      'type': 'text',
      if (replyTo != null) 'replyTo': replyTo,
    };

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage);

    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': text,
      'lastTimestamp': timestamp,
      'participants': [currentUserId, receiverId],
    }, SetOptions(merge: true));
  }

  // Gửi tin nhắn hình ảnh
  Future<void> sendImageMessage(String receiverId, File imageFile) async {
    final currentUserId = _auth.currentUser!.uid;
    final timestamp = Timestamp.now();

    final ids = [currentUserId, receiverId]..sort();
    final chatRoomId = ids.join('_');

    final cloudinary = CloudinaryPublic('dds49mcmb', 'lumo_preset', cache: false);
    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        imageFile.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    final imageUrl = response.secureUrl;

    final newMessage = <String, dynamic>{
      'senderId': currentUserId,
      'receiverId': receiverId,
      'text': imageUrl,
      'timestamp': timestamp,
      'isRead': false,
      'type': 'image',
    };

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage);

    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': '📷 Hình ảnh',
      'lastTimestamp': timestamp,
      'participants': [currentUserId, receiverId],
    }, SetOptions(merge: true));
  }

  // Cập nhật trạng thái đang gõ phím
  Future<void> updateTypingStatus(String receiverId, bool isTyping) async {
    final currentUserId = _auth.currentUser!.uid;
    final ids = [currentUserId, receiverId]..sort();
    final chatRoomId = ids.join('_');

    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'typing': {
        currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  // Lấy stream trạng thái đang gõ của đối phương
  Stream<DocumentSnapshot> getChatRoomStream(String receiverId) {
    final ids = [_auth.currentUser!.uid, receiverId]..sort();
    final chatRoomId = ids.join('_');
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots();
  }

  // Thả cảm xúc vào tin nhắn
  Future<void> toggleReaction(String receiverId, String messageId, String emoji) async {
    final currentUserId = _auth.currentUser!.uid;
    final ids = [currentUserId, receiverId]..sort();
    final chatRoomId = ids.join('_');

    final docRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final reactions = Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
    final users = List<dynamic>.from(reactions[emoji] ?? []);

    if (users.contains(currentUserId)) {
      users.remove(currentUserId);
    } else {
      users.add(currentUserId);
    }

    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }

    await docRef.update({'reactions': reactions});
  }

  // Xóa tin nhắn
  Future<void> deleteMessage(String receiverId, String messageId) async {
    final currentUserId = _auth.currentUser!.uid;
    final ids = [currentUserId, receiverId]..sort();
    final chatRoomId = ids.join('_');

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }
}
