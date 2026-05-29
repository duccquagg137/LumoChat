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
  static const String callsChannelId = 'lumo_chat_calls_v2';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(Map<String, String> payload)? _onNotificationSelected;
  String? _handledLaunchPayload;

  Future<void> init({
    void Function(Map<String, String> payload)? onNotificationSelected,
    bool requestPermissions = true,
  }) async {
    if (onNotificationSelected != null) {
      _onNotificationSelected = onNotificationSelected;
    }
    if (_initialized) return;

    const android = AndroidInitializationSettings('@drawable/ic_stat_lumochat');
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
    if (requestPermissions) {
      await _requestAndroidPermission();
    }
    _initialized = true;
    await _handleLaunchDetails();
  }

  Future<void> showRemoteMessage(
    RemoteMessage message, {
    bool requestPermissions = true,
  }) async {
    final data = _stringData(message.data);
    final title = message.notification?.title ?? data['title'] ?? 'LumoChat';
    final body = message.notification?.body ?? data['body'] ?? '';
    final notificationId = data['notificationId'] ??
        message.messageId ??
        '${DateTime.now().millisecondsSinceEpoch}';

    await showPayload(
      title: title,
      body: body,
      data: data,
      notificationId: notificationId,
      requestPermissions: requestPermissions,
    );
  }

  Future<void> showPayload({
    required String title,
    required String body,
    required Map<String, String> data,
    required String notificationId,
    bool requestPermissions = true,
  }) async {
    await init(requestPermissions: requestPermissions);
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    final type = data['type'] ?? '';
    final isCall = type.startsWith('incoming_');

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
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      ),
    );
  }

  Future<void> _requestAndroidPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  AndroidNotificationDetails _androidDetails({required bool isCall}) {
    if (isCall) {
      return const AndroidNotificationDetails(
        callsChannelId,
        'Cuộc gọi',
        channelDescription: 'Thông báo cuộc gọi LumoChat',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        largeIcon: DrawableResourceAndroidBitmap('ic_lumochat_large'),
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        timeoutAfter: 45000,
        ticker: 'LumoChat incoming call',
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      );
    }

    return const AndroidNotificationDetails(
      messagesChannelId,
      'Tin nhắn',
      channelDescription: 'Thông báo tin nhắn LumoChat',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      largeIcon: DrawableResourceAndroidBitmap('ic_lumochat_large'),
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

  Future<void> _handleLaunchDetails() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final payload = details?.notificationResponse?.payload;
    if (payload == null || payload == _handledLaunchPayload) return;
    _handledLaunchPayload = payload;
    _handlePayload(payload);
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
