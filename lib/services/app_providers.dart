import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_locale_controller.dart';
import 'auth_service.dart';
import 'call_service.dart';
import 'chat_service.dart';
import 'friend_service.dart';
import 'group_service.dart';
import 'notification_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService();
});

final callServiceProvider = Provider<CallService>((ref) {
  return CallService();
});

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final currentUserIdProvider = Provider<String>((ref) {
  return ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final appLocaleProvider = StateProvider<Locale>((ref) {
  return AppLocaleController.defaultLocale;
});

final appLanguageCodeProvider = Provider<String>((ref) {
  return ref.watch(appLocaleProvider).languageCode;
});

class AppLocaleActions {
  AppLocaleActions(this._ref);

  final Ref _ref;

  Future<void> setLocale(String languageCode) async {
    final locale = await AppLocaleController.setLocale(languageCode);
    _ref.read(appLocaleProvider.notifier).state = locale;
  }
}

final appLocaleActionsProvider = Provider<AppLocaleActions>((ref) {
  return AppLocaleActions(ref);
});

final homeTabIndexProvider = StateProvider<int>((ref) => 0);
