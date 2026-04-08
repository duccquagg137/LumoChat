import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentUserId => _auth.currentUser!.uid;

  String get _currentUserName {
    final displayName = _auth.currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final phone = _auth.currentUser?.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return 'Người dùng';
  }

  List<String> _readIdList(dynamic raw) {
    if (raw is! Iterable) return <String>[];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet().toList();
  }

  bool canDeleteGroupFromData(Map<String, dynamic> groupData) {
    final admins = _readIdList(groupData['admins']);
    final createdBy = (groupData['createdBy'] ?? '').toString();
    return createdBy == _currentUserId || admins.contains(_currentUserId);
  }

  Future<String> createGroup(String name, String description, List<String> memberIds, String creatorName) async {
    final members = <String>{...memberIds, _currentUserId}.toList();

    final timestamp = Timestamp.now();
    final docRef = await _firestore.collection('groups').add({
      'name': name,
      'description': description,
      'avatar': '',
      'members': members,
      'admins': [_currentUserId],
      'createdBy': _currentUserId,
      'createdAt': timestamp,
      'lastMessage': 'Nhóm vừa được tạo',
      'lastTimestamp': timestamp,
    });

    await docRef.collection('messages').add({
      'senderId': 'system',
      'senderName': 'Hệ thống',
      'text': '$creatorName đã tạo nhóm',
      'type': 'system',
      'timestamp': timestamp,
    });

    return docRef.id;
  }

  Stream<QuerySnapshot> getUserGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: _currentUserId)
        .snapshots();
  }

  Stream<QuerySnapshot> getGroupMembers(String groupId) {
    return _firestore.collection('users').where('groups', arrayContains: groupId).snapshots();
  }

  Stream<QuerySnapshot> getGroupMessagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .snapshots();
  }

  Future<void> updateTypingStatus(String groupId, bool isTyping) async {
    await _firestore.collection('groups').doc(groupId).set({
      'typing': {
        _currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getGroupStream(String groupId) {
    return _firestore.collection('groups').doc(groupId).snapshots();
  }

  Future<void> sendGroupMessage(String groupId, String senderName, String text, {String? replyTo}) async {
    final timestamp = Timestamp.now();

    final messageData = {
      'senderId': _currentUserId,
      'senderName': senderName,
      'text': text,
      'type': 'text',
      'timestamp': timestamp,
      'readBy': [_currentUserId],
      if (replyTo != null) 'replyTo': replyTo,
    };

    await _firestore.collection('groups').doc(groupId).collection('messages').add(messageData);
    await _firestore.collection('groups').doc(groupId).update({
      'lastMessage': '$senderName: $text',
      'lastTimestamp': timestamp,
    });
  }

  Future<void> sendImageMessage(String groupId, String senderName, File imageFile, {String? replyTo}) async {
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
      'senderId': _currentUserId,
      'senderName': senderName,
      'text': imageUrl,
      'type': 'image',
      'timestamp': timestamp,
      'readBy': [_currentUserId],
      if (replyTo != null) 'replyTo': replyTo,
    });

    await _firestore.collection('groups').doc(groupId).update({
      'lastMessage': '$senderName: 📷 [image]',
      'lastTimestamp': timestamp,
    });
  }

  Future<void> toggleReaction(String groupId, String messageId, String emoji) async {
    final docRef = _firestore.collection('groups').doc(groupId).collection('messages').doc(messageId);

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

  DocumentReference<Map<String, dynamic>> _groupMessageRef(String groupId, String messageId) {
    return _firestore.collection('groups').doc(groupId).collection('messages').doc(messageId);
  }

  Future<void> recallMessageForMe(String groupId, String messageId) async {
    final ref = _groupMessageRef(groupId, messageId);
    await ref.update({
      'deletedFor': FieldValue.arrayUnion([_currentUserId]),
    });
  }

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

  Future<void> deleteMessage(String groupId, String messageId) async {
    await recallMessageForEveryone(groupId, messageId);
  }

  Future<int> addMembers(String groupId, List<String> memberIds, {String? actorName}) async {
    final cleaned = memberIds.where((id) => id.isNotEmpty && id != _currentUserId).toSet().toList();
    if (cleaned.isEmpty) return 0;

    final groupRef = _firestore.collection('groups').doc(groupId);
    var addedCount = 0;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(groupRef);
      if (!snap.exists) {
        throw StateError('group-not-found');
      }

      final data = snap.data() as Map<String, dynamic>;
      final members = _readIdList(data['members']);
      final original = members.toSet();

      for (final id in cleaned) {
        original.add(id);
      }

      addedCount = original.length - members.length;
      if (addedCount == 0) {
        return;
      }

      final now = Timestamp.now();
      tx.update(groupRef, {
        'members': original.toList(),
        'lastTimestamp': now,
      });

      final msgRef = groupRef.collection('messages').doc();
      tx.set(msgRef, {
        'senderId': 'system',
        'senderName': 'Hệ thống',
        'text': '${actorName ?? _currentUserName} đã thêm $addedCount thành viên',
        'type': 'system',
        'timestamp': now,
      });
    });

    return addedCount;
  }

  Future<void> leaveGroup(String groupId, {String? actorName}) async {
    final groupRef = _firestore.collection('groups').doc(groupId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(groupRef);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final members = _readIdList(data['members']);
      final admins = _readIdList(data['admins']);
      final createdBy = (data['createdBy'] ?? '').toString();

      if (!members.contains(_currentUserId)) return;

      members.remove(_currentUserId);
      admins.remove(_currentUserId);

      if (members.isEmpty) {
        tx.delete(groupRef);
        return;
      }

      final now = Timestamp.now();
      final updates = <String, dynamic>{
        'members': members,
        'admins': admins,
        'lastTimestamp': now,
      };

      if (createdBy == _currentUserId) {
        updates['createdBy'] = members.first;
        if (!admins.contains(members.first)) {
          admins.add(members.first);
          updates['admins'] = admins;
        }
      }

      tx.update(groupRef, updates);

      final msgRef = groupRef.collection('messages').doc();
      tx.set(msgRef, {
        'senderId': 'system',
        'senderName': 'Hệ thống',
        'text': '${actorName ?? _currentUserName} đã rời nhóm',
        'type': 'system',
        'timestamp': now,
      });
    });
  }

  Future<void> deleteGroup(String groupId) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupSnap = await groupRef.get();

    if (!groupSnap.exists) return;

    final data = groupSnap.data() as Map<String, dynamic>;
    if (!canDeleteGroupFromData(data)) {
      throw StateError('not-allowed');
    }

    while (true) {
      final messages = await groupRef.collection('messages').limit(400).get();
      if (messages.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await groupRef.delete();
  }
}

