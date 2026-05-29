import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/app_permission_service.dart';
import '../services/onboarding_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'landing_screen.dart';
import 'onboarding_screen.dart';
import 'profile_completion_screen.dart';

final _splashNextScreenProvider =
    FutureProvider.autoDispose.family<Widget, bool>((ref, isInitialized) {
  return _resolveSplashNextScreen(isInitialized);
});

Future<Widget> _resolveSplashNextScreen(bool isFirebaseInitialized) async {
  // Keep splash visible briefly to avoid abrupt flash.
  await Future.delayed(const Duration(milliseconds: 900));

  final firebaseReady = isFirebaseInitialized || Firebase.apps.isNotEmpty;
  if (!firebaseReady) {
    debugPrint('Splash -> Landing (firebase not ready)');
    return const LandingScreen();
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    final onboardingCompleted = await OnboardingService().isCompleted();
    if (!onboardingCompleted) {
      debugPrint('Splash -> Onboarding (first run)');
      return const OnboardingScreen();
    }
    debugPrint('Splash -> Landing (no signed-in user)');
    return const LandingScreen();
  }

  // Presence update should never block startup navigation.
  unawaited(AuthService().updateUserPresence(true));
  unawaited(PushNotificationService().initForCurrentUser());

  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 2));

    final userData = userDoc.data();
    if (userData?['profileCompleted'] == false) {
      debugPrint('Splash -> ProfileCompletion');
      return const ProfileCompletionScreen();
    }

    final screenData = userData?['lastActiveScreen'];
    if (screenData is Map<String, dynamic> && screenData['name'] == 'chat') {
      final receiverId = (screenData['receiverId'] ?? '').toString();
      if (receiverId.isNotEmpty) {
        debugPrint('Splash -> Chat');
        return ChatScreen(
          userName: (screenData['userName'] ?? 'User').toString(),
          receiverId: receiverId,
          userAvatar: (screenData['userAvatar'] ?? '').toString(),
          isOnline: screenData['isOnline'] == true,
          isGroup: screenData['isGroup'] == true,
          memberCount: (screenData['memberCount'] is int)
              ? screenData['memberCount'] as int
              : 0,
        );
      }
    }
  } on TimeoutException {
    debugPrint('Splash restore timeout -> Home');
  } catch (e) {
    debugPrint('Splash restore failed -> Home: $e');
  }

  debugPrint('Splash -> Home');
  return const HomeScreen();
}

class SplashScreen extends ConsumerStatefulWidget {
  final bool isFirebaseInitialized;

  const SplashScreen({super.key, this.isFirebaseInitialized = false});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(AppPermissionService.requestStartupPermissionsOnce());
  }

  Widget _buildSplashUi() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.hero),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlphaFraction(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'LumoChat',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(
                    AppColors.primaryLight.withAlphaFraction(0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextScreen =
        ref.watch(_splashNextScreenProvider(widget.isFirebaseInitialized));
    return nextScreen.when(
      loading: _buildSplashUi,
      error: (_, __) => const LandingScreen(),
      data: (screen) => screen,
    );
  }
}
