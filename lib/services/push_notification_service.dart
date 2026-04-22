import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../models/call_models.dart';
import '../screens/call_session_screen.dart';
import 'app_navigator.dart';
import 'call_service.dart';
import 'incoming_call_coordinator.dart';

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
  String _boundUserId = '';
  bool _messageHandlersBound = false;

  Future<void> initForCurrentUser() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    if (!_messageHandlersBound) {
      _bindMessageHandlers();
      _messageHandlersBound = true;
    }

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
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(uid, token);
      }

      await _tokenSubscription?.cancel();
      _tokenSubscription = _messaging.onTokenRefresh.listen((nextToken) {
        if (nextToken.isEmpty || _boundUserId.isEmpty) return;
        unawaited(_saveToken(_boundUserId, nextToken));
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        unawaited(
          _handleIncomingCallMessage(initialMessage, source: 'initial-message'),
        );
      }
    } catch (e) {
      debugPrint('Push init skipped: $e');
    }
  }

  void _bindMessageHandlers() {
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleIncomingCallMessage(message, source: 'foreground'));
    });
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        unawaited(_handleIncomingCallMessage(message, source: 'opened-app'));
      },
    );
  }

  Future<void> _handleIncomingCallMessage(
    RemoteMessage message, {
    required String source,
  }) async {
    final data = message.data;
    if (data.isEmpty) return;

    final type = (data['type'] ?? '').toString();
    if (!type.startsWith('incoming_')) return;

    final callId = (data['callId'] ?? data['entityId'] ?? '').toString().trim();
    if (callId.isEmpty) return;

    await _openIncomingCall(callId, source: source);
  }

  Future<void> _openIncomingCall(
    String callId, {
    required String source,
  }) async {
    if (!IncomingCallCoordinator.tryAcquire(callId)) return;
    try {
      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isEmpty) return;

      final call = await CallService().getCallById(callId);
      if (call == null) return;
      if (call.calleeId != uid) return;
      if (call.status != CallStatus.ringing &&
          call.status != CallStatus.accepted) {
        return;
      }

      final navigator = appNavigatorKey.currentState;
      final context = appNavigatorKey.currentContext;
      if (navigator == null || context == null) {
        debugPrint('Push incoming call ignored ($source): navigator not ready');
        return;
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
    } catch (e) {
      debugPrint('Push incoming call open failed ($source): $e');
    } finally {
      IncomingCallCoordinator.release(callId);
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedAppSubscription = null;
    _boundUserId = '';
    _messageHandlersBound = false;
  }

  Future<void> _saveToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
