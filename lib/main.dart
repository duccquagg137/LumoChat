import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/app_locale_controller.dart';
import 'services/app_navigator.dart';
import 'services/app_providers.dart';
import 'services/app_theme_controller.dart';
import 'services/local_notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/gen_l10n/app_localizations.dart';

@pragma('vm:entry-point')
Future<void> lumoFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final type = (message.data['type'] ?? '').toString();
  if (!type.startsWith('incoming_')) return;

  await LocalNotificationService().showRemoteMessage(
    message,
    requestPermissions: false,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isFirebaseInitialized = false;
  try {
    debugPrint('Starting Firebase initialization...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    FirebaseMessaging.onBackgroundMessage(
      lumoFirebaseMessagingBackgroundHandler,
    );
    isFirebaseInitialized = true;
    debugPrint('Firebase initialized.');
  } on TimeoutException {
    debugPrint('Firebase initialization timed out.');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  final initialLocale = await AppLocaleController.loadSavedLocale();
  final initialThemeMode = await AppThemeController.loadSavedThemeMode();
  AppColors.useLightMode(initialThemeMode == ThemeMode.light);

  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.systemOverlayStyleFor(initialThemeMode),
  );

  runApp(
    ProviderScope(
      overrides: [
        appLocaleProvider.overrideWith((ref) => initialLocale),
        appThemeModeProvider.overrideWith((ref) => initialThemeMode),
      ],
      child: LumoChatApp(isFirebaseInitialized: isFirebaseInitialized),
    ),
  );
}

class LumoChatApp extends ConsumerWidget {
  final bool isFirebaseInitialized;

  const LumoChatApp({super.key, required this.isFirebaseInitialized});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    AppColors.useLightMode(themeMode == ThemeMode.light);
    SystemChrome.setSystemUIOverlayStyle(
      AppTheme.systemOverlayStyleFor(themeMode),
    );

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      locale: locale,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SplashScreen(isFirebaseInitialized: isFirebaseInitialized),
    );
  }
}
