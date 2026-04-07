import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  List<String> _readStringList(Map<String, dynamic>? data, String key) {
    final values = List<dynamic>.from(data?[key] ?? const []);
    return values.map((value) => value.toString()).toSet().toList();
  }

  Future<void> sendFriendRequest(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty || targetUserId.isEmpty || currentUserId == targetUserId) {
      return;
    }

    final myRef = _firestore.collection('users').doc(currentUserId);
    final targetRef = _firestore.collection('users').doc(targetUserId);

    await _firestore.runTransaction((tx) async {
      final mySnap = await tx.get(myRef);
      final targetSnap = await tx.get(targetRef);
      if (!mySnap.exists || !targetSnap.exists) return;

      final myData = mySnap.data();
      final targetData = targetSnap.data();

      final myFriends = _readStringList(myData, 'friends');
      final mySent = _readStringList(myData, 'friendRequestsSent');
      final myReceived = _readStringList(myData, 'friendRequestsReceived');

      final targetFriends = _readStringList(targetData, 'friends');
      final targetSent = _readStringList(targetData, 'friendRequestsSent');
      final targetReceived = _readStringList(targetData, 'friendRequestsReceived');

      if (myFriends.contains(targetUserId)) return;

      // If target already sent me a request, auto accept.
      if (myReceived.contains(targetUserId)) {
        myReceived.remove(targetUserId);
        targetSent.remove(currentUserId);
        myFriends.add(targetUserId);
        targetFriends.add(currentUserId);

        tx.update(myRef, {
          'friends': myFriends.toSet().toList(),
          'friendRequestsReceived': myReceived,
        });
        tx.update(targetRef, {
          'friends': targetFriends.toSet().toList(),
          'friendRequestsSent': targetSent,
        });
        return;
      }

      if (mySent.contains(targetUserId)) return;

      mySent.add(targetUserId);
      targetReceived.add(currentUserId);

      tx.update(myRef, {'friendRequestsSent': mySent.toSet().toList()});
      tx.update(targetRef, {'friendRequestsReceived': targetReceived.toSet().toList()});
    });
  }

  Future<void> cancelFriendRequest(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty || targetUserId.isEmpty || currentUserId == targetUserId) {
      return;
    }

    final myRef = _firestore.collection('users').doc(currentUserId);
    final targetRef = _firestore.collection('users').doc(targetUserId);

    await _firestore.runTransaction((tx) async {
      final mySnap = await tx.get(myRef);
      final targetSnap = await tx.get(targetRef);
      if (!mySnap.exists || !targetSnap.exists) return;

      final mySent = _readStringList(mySnap.data(), 'friendRequestsSent')..remove(targetUserId);
      final targetReceived = _readStringList(targetSnap.data(), 'friendRequestsReceived')..remove(currentUserId);

      tx.update(myRef, {'friendRequestsSent': mySent});
      tx.update(targetRef, {'friendRequestsReceived': targetReceived});
    });
  }

  Future<void> acceptFriendRequest(String requesterId) async {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty || requesterId.isEmpty || currentUserId == requesterId) {
      return;
    }

    final myRef = _firestore.collection('users').doc(currentUserId);
    final requesterRef = _firestore.collection('users').doc(requesterId);

    await _firestore.runTransaction((tx) async {
      final mySnap = await tx.get(myRef);
      final requesterSnap = await tx.get(requesterRef);
      if (!mySnap.exists || !requesterSnap.exists) return;

      final myData = mySnap.data();
      final requesterData = requesterSnap.data();

      final myReceived = _readStringList(myData, 'friendRequestsReceived')..remove(requesterId);
      final myFriends = _readStringList(myData, 'friends')..add(requesterId);

      final requesterSent = _readStringList(requesterData, 'friendRequestsSent')..remove(currentUserId);
      final requesterFriends = _readStringList(requesterData, 'friends')..add(currentUserId);

      tx.update(myRef, {
        'friendRequestsReceived': myReceived,
        'friends': myFriends.toSet().toList(),
      });
      tx.update(requesterRef, {
        'friendRequestsSent': requesterSent,
        'friends': requesterFriends.toSet().toList(),
      });
    });
  }

  Future<void> rejectFriendRequest(String requesterId) async {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty || requesterId.isEmpty || currentUserId == requesterId) {
      return;
    }

    final myRef = _firestore.collection('users').doc(currentUserId);
    final requesterRef = _firestore.collection('users').doc(requesterId);

    await _firestore.runTransaction((tx) async {
      final mySnap = await tx.get(myRef);
      final requesterSnap = await tx.get(requesterRef);
      if (!mySnap.exists || !requesterSnap.exists) return;

      final myReceived = _readStringList(mySnap.data(), 'friendRequestsReceived')..remove(requesterId);
      final requesterSent = _readStringList(requesterSnap.data(), 'friendRequestsSent')..remove(currentUserId);

      tx.update(myRef, {'friendRequestsReceived': myReceived});
      tx.update(requesterRef, {'friendRequestsSent': requesterSent});
    });
  }

  Future<void> unfriend(String friendId) async {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty || friendId.isEmpty || currentUserId == friendId) {
      return;
    }

    final myRef = _firestore.collection('users').doc(currentUserId);
    final friendRef = _firestore.collection('users').doc(friendId);

    await _firestore.runTransaction((tx) async {
      final mySnap = await tx.get(myRef);
      final friendSnap = await tx.get(friendRef);
      if (!mySnap.exists || !friendSnap.exists) return;

      final myFriends = _readStringList(mySnap.data(), 'friends')..remove(friendId);
      final friendFriends = _readStringList(friendSnap.data(), 'friends')..remove(currentUserId);

      tx.update(myRef, {'friends': myFriends});
      tx.update(friendRef, {'friends': friendFriends});
    });
  }
}
