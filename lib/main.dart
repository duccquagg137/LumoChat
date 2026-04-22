import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/app_locale_controller.dart';
import 'services/app_navigator.dart';
import 'services/app_providers.dart';
import 'theme/app_theme.dart';
import 'utils/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isFirebaseInitialized = false;
  try {
    debugPrint('Starting Firebase initialization...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    isFirebaseInitialized = true;
    debugPrint('Firebase initialized.');
  } on TimeoutException {
    debugPrint('Firebase initialization timed out.');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  final initialLocale = await AppLocaleController.loadSavedLocale();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        appLocaleProvider.overrideWith((ref) => initialLocale),
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
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      locale: locale,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
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
