import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/app_logger.dart';
import '../utils/profile_visibility.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Stream listening to auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Verify Phone Number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(String error) verificationFailed,
    required Function(PhoneAuthCredential) verificationCompleted,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: (FirebaseAuthException e) {
        verificationFailed('${e.code}: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // Sign In with OTP
  Future<UserCredential?> signInWithOTP(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return signInWithPhoneCredential(credential);
  }

  Future<UserCredential?> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    final userCredential = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(userCredential.user);
    return userCredential;
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // Cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(userCredential.user);
    return userCredential;
  }

  // Default Email/Password Sign in
  Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserDoc(userCredential.user);
    return userCredential;
  }

  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
    String name,
  ) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserDoc(userCredential.user, nameOverride: name);
    return userCredential;
  }

  Future<void> _ensureUserDoc(
    User? user, {
    String? nameOverride,
    bool isOnline = true,
  }) async {
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final defaults = _newUserData(
      user,
      nameOverride: nameOverride,
      isOnline: isOnline,
    );

    try {
      final doc = await userRef.get();
      if (!doc.exists) {
        await userRef.set(defaults);
        return;
      }

      final data = doc.data() ?? <String, dynamic>{};
      final updates = <String, dynamic>{
        'uid': user.uid,
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      };

      void putIfMissing(String key, Object? value) {
        final current = data[key];
        if (current == null || (current is String && current.trim().isEmpty)) {
          updates[key] = value;
        }
      }

      void putListIfMissing(String key) {
        if (data[key] is! Iterable) {
          updates[key] = <String>[];
        }
      }

      putIfMissing('email', defaults['email']);
      putIfMissing('name', defaults['name']);
      putIfMissing('avatar', defaults['avatar']);
      putIfMissing('bio', '');
      putIfMissing('phoneNumber', defaults['phoneNumber']);
      putIfMissing('address', '');
      putIfMissing('city', '');
      putIfMissing('gender', '');
      putIfMissing('dateOfBirth', '');
      putIfMissing('website', '');
      putIfMissing('occupation', '');
      putListIfMissing('friends');
      putListIfMissing('friendRequestsSent');
      putListIfMissing('friendRequestsReceived');
      if (data['settings'] is! Map) {
        updates['settings'] = defaults['settings'];
      }
      if (data['profileCompleted'] is! bool) {
        updates['profileCompleted'] = _hasRequiredProfileFields(data);
      }
      if (data['createdAt'] == null) {
        updates['createdAt'] = FieldValue.serverTimestamp();
      }

      await userRef.set(updates, SetOptions(merge: true));
    } on FirebaseException catch (e, stackTrace) {
      AppLogger.error(
        'User profile sync failed',
        tag: 'auth',
        error: e,
        stackTrace: stackTrace,
        context: {
          'uid': user.uid,
          'code': e.code,
        },
      );
      rethrow;
    }
  }

  Map<String, dynamic> _newUserData(
    User user, {
    String? nameOverride,
    required bool isOnline,
  }) {
    final resolvedName = _firstText([
      nameOverride,
      user.displayName,
      user.phoneNumber,
      'Người dùng',
    ]);

    return {
      'uid': user.uid,
      'email': user.email ?? '',
      'name': resolvedName,
      'avatar': user.photoURL ?? '',
      'bio': '',
      'phoneNumber': user.phoneNumber ?? '',
      'address': '',
      'city': '',
      'gender': '',
      'dateOfBirth': '',
      'website': '',
      'occupation': '',
      'settings': {
        'darkMode': true,
        'notifications': true,
        'profileVisibility': ProfileVisibility.defaultValues,
      },
      'profileCompleted': false,
      'friends': <String>[],
      'friendRequestsSent': <String>[],
      'friendRequestsReceived': <String>[],
      'isOnline': isOnline,
      'lastActive': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool _hasRequiredProfileFields(Map<String, dynamic> data) {
    final requiredFields = [
      data['name'],
      data['phoneNumber'],
      data['city'],
      data['gender'],
      data['dateOfBirth'],
    ];
    return requiredFields.every(
      (value) => value != null && value.toString().trim().isNotEmpty,
    );
  }

  String _firstText(Iterable<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  Future<void> updateUserPresence(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        await _ensureUserDoc(user, isOnline: isOnline);
        return;
      }
      rethrow;
    }
  }

  Future<void> updateLastScreen(Map<String, dynamic>? screenData) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'lastActiveScreen': screenData,
        });
      } catch (e) {
        debugPrint('Failed to update lastScreen: $e');
      }
    }
  }

  Future<void> signOut() async {
    await updateLastScreen(null);
    await updateUserPresence(false);

    // Also sign out from Google to allow switching accounts later
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    await _auth.signOut();
  }
}
