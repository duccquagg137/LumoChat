import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService _instance =
      LocalNotificationService._();

  factory LocalNotificationService() => _instance;

  static const String messagesChannelId = 'lumo_chat_messages';
  static const String callsChannelId = 'lumo_chat_calls';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(Map<String, String> payload)? _onNotificationSelected;

  Future<void> init({
    void Function(Map<String, String> payload)? onNotificationSelected,
  }) async {
    if (onNotificationSelected != null) {
      _onNotificationSelected = onNotificationSelected;
    }
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    await _createAndroidChannels();
    await _requestAndroidPermission();
    _initialized = true;
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    await init();

    final data = _stringData(message.data);
    final title = message.notification?.title ?? data['title'] ?? 'LumoChat';
    final body = message.notification?.body ?? data['body'] ?? '';
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    final type = data['type'] ?? '';
    final isCall = type.startsWith('incoming_');
    final notificationId = data['notificationId'] ??
        message.messageId ??
        '${DateTime.now().millisecondsSinceEpoch}';

    await _plugin.show(
      _stableNotificationId(notificationId),
      title,
      body,
      NotificationDetails(
        android: _androidDetails(isCall: isCall),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        messagesChannelId,
        'Tin nhắn',
        description: 'Thông báo tin nhắn LumoChat',
        importance: Importance.high,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        callsChannelId,
        'Cuộc gọi',
        description: 'Thông báo cuộc gọi LumoChat',
        importance: Importance.max,
      ),
    );
  }

  Future<void> _requestAndroidPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  AndroidNotificationDetails _androidDetails({required bool isCall}) {
    if (isCall) {
      return const AndroidNotificationDetails(
        callsChannelId,
        'Cuộc gọi',
        channelDescription: 'Thông báo cuộc gọi LumoChat',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.call,
        playSound: true,
        enableVibration: true,
      );
    }

    return const AndroidNotificationDetails(
      messagesChannelId,
      'Tin nhắn',
      channelDescription: 'Thông báo tin nhắn LumoChat',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      playSound: true,
      enableVibration: true,
    );
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      _onNotificationSelected?.call(
        decoded.map((key, value) => MapEntry(key.toString(), value.toString())),
      );
    } catch (e) {
      debugPrint('Local notification payload ignored: $e');
    }
  }

  Map<String, String> _stringData(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, value.toString()));
  }

  int _stableNotificationId(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
