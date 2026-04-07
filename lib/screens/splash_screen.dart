import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'landing_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool isFirebaseInitialized;

  const SplashScreen({super.key, this.isFirebaseInitialized = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Future<Widget> _nextScreenFuture;

  @override
  void initState() {
    super.initState();
    _nextScreenFuture = _resolveNextScreen();
  }

  Future<Widget> _resolveNextScreen() async {
    // Keep splash visible briefly to avoid abrupt flash.
    await Future.delayed(const Duration(milliseconds: 900));

    final firebaseReady = widget.isFirebaseInitialized || Firebase.apps.isNotEmpty;
    if (!firebaseReady) {
      debugPrint('Splash -> Landing (firebase not ready)');
      return const LandingScreen();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Splash -> Landing (no signed-in user)');
      return const LandingScreen();
    }

    // Presence update should never block startup navigation.
    unawaited(AuthService().updateUserPresence(true));

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 2));

      final screenData = userDoc.data()?['lastActiveScreen'];
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
            memberCount: (screenData['memberCount'] is int) ? screenData['memberCount'] as int : 0,
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

  Widget _buildSplashUi() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
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
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 44,
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
                    AppColors.primaryLight.withOpacity(0.85),
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
    return FutureBuilder<Widget>(
      future: _nextScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildSplashUi();
        }

        return snapshot.data ?? const LandingScreen();
      },
    );
  }
}
