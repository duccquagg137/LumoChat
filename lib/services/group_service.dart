import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';
import '../utils/retry_policy.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  static const int _batchSize = 400;

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
    return raw
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  DocumentReference<Map<String, dynamic>> _currentUserRef() {
    return _firestore.collection('users').doc(_currentUserId);
  }

  Future<void> _updateGroupMeta(
      String groupId, Map<String, dynamic> fields) async {
    final userRef = _currentUserRef();
    await userRef.set({}, SetOptions(merge: true));

    final updates = <String, dynamic>{};
    for (final entry in fields.entries) {
      updates['groupMeta.$groupId.${entry.key}'] = entry.value;
    }
    await userRef.update(updates);
  }

  Map<String, dynamic> _unreadStateUpdatesForMembers({
    required List<String> memberIds,
    required Timestamp timestamp,
  }) {
    final uniqueMemberIds =
        memberIds.where((id) => id.isNotEmpty).toSet().toList();
    final updates = <String, dynamic>{
      'lastReadAtByUser.$_currentUserId': timestamp,
    };
    for (final memberId in uniqueMemberIds) {
      if (memberId == _currentUserId) {
        updates['unreadCountByUser.$memberId'] = 0;
      } else {
        updates['unreadCountByUser.$memberId'] = FieldValue.increment(1);
      }
    }
    return updates;
  }

  bool canDeleteGroupFromData(Map<String, dynamic> groupData) {
    final admins = _readIdList(groupData['admins']);
    final createdBy = (groupData['createdBy'] ?? '').toString();
    return createdBy == _currentUserId || admins.contains(_currentUserId);
  }

  Future<String> createGroup(
    String name,
    String description,
    List<String> memberIds,
    String creatorName, {
    File? avatarFile,
  }) async {
    final members = <String>{...memberIds, _currentUserId}.toList();
    final timestamp = Timestamp.now();
    final groupRef = _firestore.collection('groups').doc();
    final systemMessageRef = groupRef.collection('messages').doc();
    final unreadCountByUser = <String, int>{
      for (final memberId in members) memberId: 0,
    };
    final lastReadAtByUser = <String, Timestamp>{
      _currentUserId: timestamp,
    };
    var avatarUrl = '';

    if (avatarFile != null) {
      final cloudinary =
          CloudinaryPublic('dds49mcmb', 'lumo_preset', cache: false);
      avatarUrl = await RetryPolicy.run<String>(
        operation: 'groups.upload_avatar',
        task: () async {
          final response = await cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              avatarFile.path,
              resourceType: CloudinaryResourceType.Image,
            ),
          );
          return response.secureUrl;
        },
      );
    }

    await RetryPolicy.run(
      operation: 'groups.create_group',
      task: () async {
        await groupRef.set({
          'name': name,
          'description': description,
          'avatar': avatarUrl,
          'members': members,
          'admins': [_currentUserId],
          'createdBy': _currentUserId,
          'createdAt': timestamp,
          'lastMessage': 'Nhóm vừa được tạo',
          'lastTimestamp': timestamp,
          'unreadCountByUser': unreadCountByUser,
          'lastReadAtByUser': lastReadAtByUser,
        }, SetOptions(merge: true));

        await systemMessageRef.set({
          'senderId': 'system',
          'senderName': 'Hệ thống',
          'text': '$creatorName đã tạo nhóm',
          'type': 'system',
          'timestamp': timestamp,
        }, SetOptions(merge: true));
      },
    );

    return groupRef.id;
  }

  Stream<QuerySnapshot> getUserGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: _currentUserId)
        .snapshots();
  }

  Stream<QuerySnapshot> getGroupMembers(String groupId) {
    return _firestore
        .collection('users')
        .where('groups', arrayContains: groupId)
        .snapshots();
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

  Future<void> sendGroupMessage(String groupId, String senderName, String text,
      {String? replyTo}) async {
    final timestamp = Timestamp.now();
    final groupRef = _firestore.collection('groups').doc(groupId);
    final messageRef = groupRef.collection('messages').doc();

    final messageData = {
      'id': messageRef.id,
      'senderId': _currentUserId,
      'senderName': senderName,
      'text': text,
      'type': 'text',
      'timestamp': timestamp,
      'readBy': [_currentUserId],
      if (replyTo != null) 'replyTo': replyTo,
    };

    await RetryPolicy.run(
      operation: 'groups.send_message',
      task: () async {
        final groupSnapshot = await groupRef.get();
        final groupData = groupSnapshot.data() ?? const <String, dynamic>{};
        final memberIds = _readIdList(groupData['members']);

        await messageRef.set(messageData, SetOptions(merge: true));
        await groupRef.update({
          'lastMessage': '$senderName: $text',
          'lastTimestamp': timestamp,
          ..._unreadStateUpdatesForMembers(
            memberIds: memberIds.isEmpty ? <String>[_currentUserId] : memberIds,
            timestamp: timestamp,
          ),
        });

        await _notifyGroupMembers(
          groupId: groupId,
          groupName: (groupData['name'] ?? '').toString(),
          senderName: senderName,
          memberIds: memberIds,
          messageId: messageRef.id,
          bodyText: text.trim(),
        );
      },
    );
  }

  Future<void> sendImageMessage(
    String groupId,
    String senderName,
    File imageFile, {
    String? replyTo,
    int? imageWidth,
    int? imageHeight,
  }) async {
    final timestamp = Timestamp.now();
    final groupRef = _firestore.collection('groups').doc(groupId);
    final messageRef = groupRef.collection('messages').doc();

    final cloudinary =
        CloudinaryPublic('dds49mcmb', 'lumo_preset', cache: false);
    final imageUrl = await RetryPolicy.run<String>(
      operation: 'groups.upload_image',
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

    await RetryPolicy.run(
      operation: 'groups.send_image_message',
      task: () async {
        final groupSnapshot = await groupRef.get();
        final groupData = groupSnapshot.data() ?? const <String, dynamic>{};
        final memberIds = _readIdList(groupData['members']);

        await messageRef.set({
          'id': messageRef.id,
          'senderId': _currentUserId,
          'senderName': senderName,
          'text': imageUrl,
          'type': 'image',
          'timestamp': timestamp,
          'readBy': [_currentUserId],
          if (replyTo != null) 'replyTo': replyTo,
          if (imageWidth != null && imageHeight != null) ...{
            'imageWidth': imageWidth,
            'imageHeight': imageHeight,
          },
        }, SetOptions(merge: true));

        await groupRef.update({
          'lastMessage': '$senderName: 📷 [image]',
          'lastTimestamp': timestamp,
          ..._unreadStateUpdatesForMembers(
            memberIds: memberIds.isEmpty ? <String>[_currentUserId] : memberIds,
            timestamp: timestamp,
          ),
        });

        await _notifyGroupMembers(
          groupId: groupId,
          groupName: (groupData['name'] ?? '').toString(),
          senderName: senderName,
          memberIds: memberIds,
          messageId: messageRef.id,
          bodyText: '📷 Image',
        );
      },
    );
  }

  Future<void> _notifyGroupMembers({
    required String groupId,
    required String groupName,
    required String senderName,
    required List<String> memberIds,
    required String messageId,
    required String bodyText,
  }) async {
    final targets = memberIds
        .where((id) => id.isNotEmpty && id != _currentUserId)
        .toSet()
        .toList();
    if (targets.isEmpty) return;

    final safeGroup = groupName.trim().isEmpty ? 'Group' : groupName.trim();
    final resolvedSender = await _resolveCurrentUserName();
    final trimmedSender = senderName.trim();
    final safeSender =
        trimmedSender.isNotEmpty && !_looksLikeEmail(trimmedSender)
            ? trimmedSender
            : resolvedSender;
    final messageBody = bodyText.isEmpty ? 'New message' : bodyText;

    await Future.wait(
      targets.map((recipientId) {
        final dedupeId = 'gm_${groupId}_${recipientId}_$messageId';
        return _notificationService.createNotification(
          recipientId: recipientId,
          senderId: _currentUserId,
          type: 'new_group_message',
          title: safeGroup,
          body: '$safeSender: $messageBody',
          entityId: messageId,
          dedupeId: dedupeId,
          data: {
            'chatType': 'group',
            'groupId': groupId,
            'senderId': _currentUserId,
            'recipientId': recipientId,
          },
        );
      }),
    );
  }

  Future<String> _resolveCurrentUserName() async {
    try {
      final doc = await _currentUserRef().get();
      final data = doc.data() ?? const <String, dynamic>{};
      final name = data['name']?.toString().trim() ?? '';
      if (name.isNotEmpty && !_looksLikeEmail(name)) return name;
      final username = data['username']?.toString().trim() ?? '';
      if (username.isNotEmpty && !_looksLikeEmail(username)) return username;
    } catch (_) {}

    final fallback = _currentUserName.trim();
    if (fallback.isNotEmpty && !_looksLikeEmail(fallback)) return fallback;

    final email = _auth.currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first.trim();
    }
    return 'User';
  }

  bool _looksLikeEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }

  Future<void> toggleReaction(
      String groupId, String messageId, String emoji) async {
    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);

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

  DocumentReference<Map<String, dynamic>> _groupMessageRef(
      String groupId, String messageId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);
  }

  Future<void> recallMessageForMe(String groupId, String messageId) async {
    final ref = _groupMessageRef(groupId, messageId);
    await ref.update({
      'deletedFor': FieldValue.arrayUnion([_currentUserId]),
    });
  }

  Future<void> recallMessageForEveryone(
      String groupId, String messageId) async {
    final ref = _groupMessageRef(groupId, messageId);
    await ref.update({
      'type': 'deleted',
      'text': 'Tin nhắn đã thu hồi',
      'recalledForEveryone': true,
      'recalledAt': Timestamp.now(),
      'reactions': FieldValue.delete(),
    });

    final groupSnapshot =
        await _firestore.collection('groups').doc(groupId).get();
    final groupData = groupSnapshot.data();
    final pinned = groupData?['pinnedMessage'];
    if (pinned is Map && pinned['messageId']?.toString() == messageId) {
      await clearPinnedMessage(groupId);
    }
  }

  Future<void> deleteMessage(String groupId, String messageId) async {
    await recallMessageForEveryone(groupId, messageId);
  }

  Future<void> setGroupPinned(String groupId, bool pinned) async {
    await _updateGroupMeta(groupId, {
      'pinned': pinned,
    });
  }

  Future<void> setPinnedMessage(
    String groupId, {
    required String messageId,
    required String previewText,
    required String messageType,
    String? senderId,
    String? senderName,
  }) async {
    await _firestore.collection('groups').doc(groupId).set({
      'pinnedMessage': {
        'messageId': messageId,
        'previewText': previewText,
        'messageType': messageType,
        'senderId': senderId ?? '',
        'senderName': senderName ?? '',
        'pinnedBy': _currentUserId,
        'pinnedByName': _currentUserName,
        'pinnedAt': Timestamp.now(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> clearPinnedMessage(String groupId) async {
    await _firestore.collection('groups').doc(groupId).set({
      'pinnedMessage': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<int> markGroupMessagesRead(String groupId) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupSnapshot = await groupRef.get();
    final groupData = groupSnapshot.data() ?? const <String, dynamic>{};
    final lastReadAtByUser = groupData['lastReadAtByUser'];
    Timestamp? lastReadAt;
    if (lastReadAtByUser is Map) {
      final rawLastRead = lastReadAtByUser[_currentUserId];
      if (rawLastRead is Timestamp) {
        lastReadAt = rawLastRead;
      }
    }

    Query<Map<String, dynamic>> baseQuery =
        groupRef.collection('messages').orderBy('timestamp').limit(_batchSize);
    if (lastReadAt != null) {
      baseQuery = baseQuery.where('timestamp', isGreaterThan: lastReadAt);
    }

    var updated = 0;
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      var pageQuery = baseQuery;
      if (cursor != null) {
        pageQuery = pageQuery.startAfterDocument(cursor);
      }

      final snapshot = await pageQuery.get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _firestore.batch();
      var batchUpdated = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId']?.toString();
        if (senderId == _currentUserId || senderId == 'system') {
          continue;
        }

        final readBy = _readIdList(data['readBy']);
        if (readBy.contains(_currentUserId)) {
          continue;
        }

        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([_currentUserId]),
        });
        batchUpdated++;
      }

      if (batchUpdated > 0) {
        await batch.commit();
        updated += batchUpdated;
      }

      cursor = snapshot.docs.last;
      if (snapshot.docs.length < _batchSize) {
        break;
      }
    }

    await groupRef.update({
      'unreadCountByUser.$_currentUserId': 0,
      'lastReadAtByUser.$_currentUserId': Timestamp.now(),
    });
    return updated;
  }

  Future<int> addMembers(String groupId, List<String> memberIds,
      {String? actorName}) async {
    final cleaned = memberIds
        .where((id) => id.isNotEmpty && id != _currentUserId)
        .toSet()
        .toList();
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
      final before = Set<String>.from(original);

      for (final id in cleaned) {
        original.add(id);
      }

      addedCount = original.length - members.length;
      if (addedCount == 0) {
        return;
      }

      final now = Timestamp.now();
      final updates = <String, dynamic>{
        'members': original.toList(),
        'lastTimestamp': now,
      };
      for (final id in original.difference(before)) {
        updates['unreadCountByUser.$id'] = 0;
      }
      tx.update(groupRef, updates);

      final msgRef = groupRef.collection('messages').doc();
      tx.set(msgRef, {
        'senderId': 'system',
        'senderName': 'Hệ thống',
        'text':
            '${actorName ?? _currentUserName} đã thêm $addedCount thành viên',
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
        'unreadCountByUser.$_currentUserId': FieldValue.delete(),
        'lastReadAtByUser.$_currentUserId': FieldValue.delete(),
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
