import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../models/call_models.dart';
import '../screens/call_session_screen.dart';
import '../screens/chat_screen.dart';
import 'app_navigator.dart';
import 'call_service.dart';
import 'incoming_call_coordinator.dart';
import 'local_notification_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService _instance = PushNotificationService._();

  factory PushNotificationService() => _instance;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _incomingCallSubscription;
  String _boundUserId = '';
  bool _messageHandlersBound = false;

  Future<void> initForCurrentUser() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    if (!_messageHandlersBound) {
      _bindMessageHandlers();
      _messageHandlersBound = true;
    }

    await LocalNotificationService().init(
      onNotificationSelected: _handleNotificationSelection,
    );

    if (_boundUserId == uid) {
      return;
    }

    _boundUserId = uid;
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(uid, token);
      }

      _listenForIncomingCalls(uid);

      await _tokenSubscription?.cancel();
      _tokenSubscription = _messaging.onTokenRefresh.listen((nextToken) {
        if (nextToken.isEmpty || _boundUserId.isEmpty) return;
        unawaited(_saveToken(_boundUserId, nextToken));
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        unawaited(
          _handleMessageOpened(initialMessage, source: 'initial-message'),
        );
      }
    } catch (e) {
      debugPrint('Push init skipped: $e');
    }
  }

  void _bindMessageHandlers() {
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleForegroundMessage(message));
    });
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        unawaited(_handleMessageOpened(message, source: 'opened-app'));
      },
    );
  }

  void _listenForIncomingCalls(String uid) {
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: uid)
        .where('status', isEqualTo: CallStatus.ringing.key)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        unawaited(
          _openIncomingCall(doc.id, source: 'firestore-listener'),
        );
        break;
      }
    }, onError: (Object e) {
      debugPrint('Incoming call listener failed: $e');
    });
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final openedCall =
        await _handleIncomingCallMessage(message, source: 'foreground');
    if (openedCall) return;
    await LocalNotificationService().showRemoteMessage(message);
  }

  Future<void> _handleMessageOpened(
    RemoteMessage message, {
    required String source,
  }) async {
    final openedCall =
        await _handleIncomingCallMessage(message, source: source);
    if (openedCall) return;
    _handleNotificationSelection(_stringData(message.data));
  }

  Future<bool> _handleIncomingCallMessage(
    RemoteMessage message, {
    required String source,
  }) async {
    final data = message.data;
    if (data.isEmpty) return false;

    final type = (data['type'] ?? '').toString();
    if (!type.startsWith('incoming_')) return false;

    final callId = (data['callId'] ?? data['entityId'] ?? '').toString().trim();
    if (callId.isEmpty) return false;

    return _openIncomingCall(callId, source: source);
  }

  Future<bool> _openIncomingCall(
    String callId, {
    required String source,
  }) async {
    if (!IncomingCallCoordinator.tryAcquire(callId)) return true;
    try {
      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isEmpty) return false;

      final call = await CallService().getCallById(callId);
      if (call == null) return false;
      if (call.calleeId != uid) return false;
      if (call.status != CallStatus.ringing &&
          call.status != CallStatus.accepted) {
        return false;
      }

      final navigator = appNavigatorKey.currentState;
      final context = appNavigatorKey.currentContext;
      if (navigator == null || context == null) {
        debugPrint('Push incoming call ignored ($source): navigator not ready');
        return false;
      }

      await navigator.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CallSessionScreen.incoming(
            callId: call.id,
            peerId: call.callerId,
            peerName: call.callerName,
            peerAvatar: call.callerAvatar,
            callType: call.type,
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Push incoming call open failed ($source): $e');
      return false;
    } finally {
      IncomingCallCoordinator.release(callId);
    }
  }

  void _handleNotificationSelection(Map<String, String> data) {
    final type = data['type'] ?? '';
    if (type.startsWith('incoming_')) {
      final callId = (data['callId'] ?? data['entityId'] ?? '').trim();
      if (callId.isNotEmpty) {
        unawaited(_openIncomingCall(callId, source: 'local-notification'));
      }
      return;
    }

    if (type == 'new_message') {
      unawaited(_openDirectChatFromNotification(data));
      return;
    }

    if (type == 'new_group_message') {
      unawaited(_openGroupChatFromNotification(data));
    }
  }

  Future<void> _openDirectChatFromNotification(
    Map<String, String> data,
  ) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final senderId = (data['senderId'] ?? '').trim();
    final receiverId = (data['receiverId'] ?? '').trim();
    final peerId = senderId == uid ? receiverId : senderId;
    if (peerId.isEmpty) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final userDoc = await _firestore.collection('users').doc(peerId).get();
    final userData = userDoc.data() ?? const <String, dynamic>{};
    final peerName = (userData['name'] ?? 'User').toString();
    final peerAvatar = (userData['avatar'] ?? '').toString();

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userName: peerName,
          receiverId: peerId,
          userAvatar: peerAvatar,
          isOnline: userData['isOnline'] == true,
        ),
      ),
    );
  }

  Future<void> _openGroupChatFromNotification(
    Map<String, String> data,
  ) async {
    final groupId = (data['groupId'] ?? '').trim();
    if (groupId.isEmpty) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final groupData = groupDoc.data() ?? const <String, dynamic>{};
    final members = groupData['members'];
    final memberCount = members is Iterable ? members.length : 0;

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userName: (groupData['name'] ?? 'Group').toString(),
          receiverId: groupId,
          userAvatar: (groupData['avatar'] ?? '').toString(),
          isGroup: true,
          memberCount: memberCount,
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    await _incomingCallSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedAppSubscription = null;
    _incomingCallSubscription = null;
    _boundUserId = '';
    _messageHandlersBound = false;
  }

  Future<void> _saveToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, String> _stringData(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, value.toString()));
  }
}
