import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new group
  Future<String> createGroup(String name, String description, List<String> memberIds, String creatorName) async {
    final currentUserId = _auth.currentUser!.uid;
    
    // Add current user to members and admins
    final members = [...memberIds, currentUserId];
    
    final docRef = await _firestore.collection('groups').add({
      'name': name,
      'description': description,
      'avatar': '',
      'members': members,
      'admins': [currentUserId],
      'createdBy': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Nhóm vừa được tạo',
      'lastTimestamp': FieldValue.serverTimestamp(),
    });

    // Create a system message logging the creation
    await docRef.collection('messages').add({
      'senderId': 'system',
      'senderName': 'Hệ thống',
      'text': '$creatorName đã tạo nhóm',
      'type': 'system',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // Get stream of groups the user is a part of
  Stream<QuerySnapshot> getUserGroups() {
    final currentUserId = _auth.currentUser!.uid;
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .orderBy('lastTimestamp', descending: true)
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
        .orderBy('timestamp', descending: false)
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

    final messageData = {
      'senderId': currentUserId,
      'senderName': senderName,
      'text': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [currentUserId],
      if (replyTo != null) 'replyTo': replyTo,
    };

    await _firestore.collection('groups').doc(groupId).collection('messages').add(messageData);
    await _firestore.collection('groups').doc(groupId).update({
      'lastMessage': '$senderName: $text',
      'lastTimestamp': FieldValue.serverTimestamp(),
    });
  }

  // Send an image message
  Future<void> sendImageMessage(String groupId, String senderName, dynamic imageFile) async {
    // Note: To fully implement, need Cloudinary upload logic here as well.
    // Copying the quick logic from ChatService
    throw Exception('Sẽ cập nhật sau'); 
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

  // Delete message
  Future<void> deleteMessage(String groupId, String messageId) async {
    await _firestore.collection('groups').doc(groupId).collection('messages').doc(messageId).delete();
  }
}
