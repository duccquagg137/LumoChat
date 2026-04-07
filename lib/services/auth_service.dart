import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
        verificationFailed("${e.code}: ${e.message}");
      },
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // Sign In with OTP
  Future<UserCredential?> signInWithOTP(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _checkAndCreateUserDoc(userCredential.user);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // Cancelled
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _checkAndCreateUserDoc(userCredential.user);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }



  // Check and create user doc if not exists (for social & phone login)
  Future<void> _checkAndCreateUserDoc(User? user) async {
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? user.phoneNumber ?? 'Người dùng',
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
          },
          'friends': [],
          'friendRequestsSent': [],
          'friendRequestsReceived': [],
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data() ?? <String, dynamic>{};
        await updateUserPresence(true);
        await _firestore.collection('users').doc(user.uid).set({
          'friends': FieldValue.arrayUnion([]),
          'friendRequestsSent': FieldValue.arrayUnion([]),
          'friendRequestsReceived': FieldValue.arrayUnion([]),
          'bio': (data['bio'] ?? '').toString(),
          'phoneNumber': (data['phoneNumber'] ?? user.phoneNumber ?? '').toString(),
          'address': (data['address'] ?? '').toString(),
          'city': (data['city'] ?? '').toString(),
          'gender': (data['gender'] ?? '').toString(),
          'dateOfBirth': (data['dateOfBirth'] ?? '').toString(),
          'website': (data['website'] ?? '').toString(),
          'occupation': (data['occupation'] ?? '').toString(),
          'settings': {
            'darkMode': ((data['settings'] as Map<String, dynamic>?)?['darkMode'] != false),
            'notifications': ((data['settings'] as Map<String, dynamic>?)?['notifications'] != false),
          },
        }, SetOptions(merge: true));
      }
    }
  }

  // Default Email/Password Sign in
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await updateUserPresence(true);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<UserCredential?> signUpWithEmailPassword(String email, String password, String name) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'name': name,
          'avatar': '',
          'bio': '',
          'phoneNumber': '',
          'address': '',
          'city': '',
          'gender': '',
          'dateOfBirth': '',
          'website': '',
          'occupation': '',
          'settings': {
            'darkMode': true,
            'notifications': true,
          },
          'friends': [],
          'friendRequestsSent': [],
          'friendRequestsReceived': [],
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> updateUserPresence(bool isOnline) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': isOnline,
          'lastActive': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        await _firestore.collection('users').doc(user.uid).set({
          'isOnline': isOnline,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
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
        debugPrint("Lỗi cập nhật lastScreen: $e");
      }
    }
  }

  Future<void> signOut() async {
    await updateLastScreen(null);
    await updateUserPresence(false);
    
    // Also sign out from Google to allow switching accounts later
    try { await GoogleSignIn().signOut(); } catch (_) {}
    
    await _auth.signOut();
  }
}
