import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new group
  Future<String> createGroup(String name, String description, List<String> memberIds, String creatorName) async {
    final currentUserId = _auth.currentUser!.uid;

    // Add current user to members and admins
    final members = [...memberIds, currentUserId];

    final timestamp = Timestamp.now();
    final docRef = await _firestore.collection('groups').add({
      'name': name,
      'description': description,
      'avatar': '',
      'members': members,
      'admins': [currentUserId],
      'createdBy': currentUserId,
      'createdAt': timestamp,
      'lastMessage': 'Nhóm vừa được tạo',
      'lastTimestamp': timestamp,
    });

    // Create a system message logging the creation
    await docRef.collection('messages').add({
      'senderId': 'system',
      'senderName': 'Hệ thống',
      'text': '$creatorName đã tạo nhóm',
      'type': 'system',
      'timestamp': timestamp,
    });

    return docRef.id;
  }

  // Get stream of groups the user is a part of
  Stream<QuerySnapshot> getUserGroups() {
    final currentUserId = _auth.currentUser!.uid;
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .snapshots();
  }

  // Get stream of group members
  Stream<QuerySnapshot> getGroupMembers(String groupId) {
    return _firestore.collection('users').where('groups', arrayContains: groupId).snapshots();
  }

  // Get stream of group messages
  Stream<QuerySnapshot> getGroupMessagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .snapshots();
  }

  // Update typing status for group
  Future<void> updateTypingStatus(String groupId, bool isTyping) async {
    final currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('groups').doc(groupId).set({
      'typing': {
        currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  // Get group stream for typing status and group details
  Stream<DocumentSnapshot> getGroupStream(String groupId) {
    return _firestore.collection('groups').doc(groupId).snapshots();
  }

  // Send a message to a group
  Future<void> sendGroupMessage(String groupId, String senderName, String text, {String? replyTo}) async {
    final currentUserId = _auth.currentUser!.uid;
    final timestamp = Timestamp.now();

    final messageData = {
      'senderId': currentUserId,
      'senderName': senderName,
      'text': text,
      'type': 'text',
      'timestamp': timestamp,
      'readBy': [currentUserId],
      if (replyTo != null) 'replyTo': replyTo,
    };

    await _firestore.collection('groups').doc(groupId).collection('messages').add(messageData);
    await _firestore.collection('groups').doc(groupId).update({
      'lastMessage': '$senderName: $text',
      'lastTimestamp': timestamp,
    });
  }

  // Send an image message
  Future<void> sendImageMessage(String groupId, String senderName, File imageFile) async {
    final currentUserId = _auth.currentUser!.uid;
    final timestamp = Timestamp.now();

    final cloudinary = CloudinaryPublic('dds49mcmb', 'lumo_preset', cache: false);
    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        imageFile.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    final imageUrl = response.secureUrl;

    await _firestore.collection('groups').doc(groupId).collection('messages').add({
      'senderId': currentUserId,
      'senderName': senderName,
      'text': imageUrl,
      'type': 'image',
      'timestamp': timestamp,
      'readBy': [currentUserId],
    });

    await _firestore.collection('groups').doc(groupId).update({
      'lastMessage': '$senderName: 📷 Hình ảnh',
      'lastTimestamp': timestamp,
    });
  }

  // Toggle reaction
  Future<void> toggleReaction(String groupId, String messageId, String emoji) async {
    final currentUserId = _auth.currentUser!.uid;
    final docRef = _firestore.collection('groups').doc(groupId).collection('messages').doc(messageId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final reactions = Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
    List<dynamic> users = List<dynamic>.from(reactions[emoji] ?? []);

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

  DocumentReference<Map<String, dynamic>> _groupMessageRef(String groupId, String messageId) {
    return _firestore.collection('groups').doc(groupId).collection('messages').doc(messageId);
  }

  // Thu hồi chỉ cho bản thân
  Future<void> recallMessageForMe(String groupId, String messageId) async {
    final currentUserId = _auth.currentUser!.uid;
    final ref = _groupMessageRef(groupId, messageId);
    await ref.update({
      'deletedFor': FieldValue.arrayUnion([currentUserId]),
    });
  }

  // Thu hồi cho mọi người
  Future<void> recallMessageForEveryone(String groupId, String messageId) async {
    final ref = _groupMessageRef(groupId, messageId);
    await ref.update({
      'type': 'deleted',
      'text': 'Tin nhắn đã thu hồi',
      'recalledForEveryone': true,
      'recalledAt': Timestamp.now(),
      'reactions': FieldValue.delete(),
    });
  }

  // Giữ tương thích với code cũ
  Future<void> deleteMessage(String groupId, String messageId) async {
    await recallMessageForEveryone(groupId, messageId);
  }
}
