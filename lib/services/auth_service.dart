import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/center_hud_alert.dart';
import 'profile_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(syncPublicProfile());
      }
    });
    if (_auth.currentUser != null) {
      unawaited(syncPublicProfile());
    }
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String databaseId =
      'ai-studio-android-sanchay-c9654c5d-c4ca-4c5c-8b5e-20b5665d1fcb';

  static FirebaseFirestore get firestoreInstance {
    try {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: databaseId,
      );
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  FirebaseFirestore get _firestore => firestoreInstance;

  static const String webClientId =
      '41954701104-1eqfhs3s6p6naknnui85ab2hubaki4dc.apps.googleusercontent.com';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<UserCredential?> handleGoogleSignIn(BuildContext context) async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Use Firebase's dedicated Web Auth Provider to avoid cross-window drop
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        authProvider.addScope('email');
        authProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(authProvider);
      } else {
        // Native Android/iOS implementation
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      // Background profile cache (non-blocking)
      if (userCredential.user != null) {
        unawaited(_ensureUserProfile(userCredential.user));

        // Force Immediate Navigation to Dashboard upon credential receipt
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
        }
      }

      return userCredential;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (context.mounted) {
        final errorStr = e.toString();
        final isCode10 = errorStr.contains('10') ||
            errorStr.contains('ApiException: 10') ||
            (e is PlatformException && (e.code == '10' || e.message?.contains('10') == true));

        final message = isCode10
            ? 'Google Sign-In configuration updated. Ensure latest SHA-1 is registered in Firebase, or sign in using Email/Password.'
            : 'Sign-in error: $errorStr';

        showCenterAlert(
          context,
          message: message,
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
        );
      }
      return null;
    }
  }

  Future<UserCredential?> signInWithGoogle([BuildContext? context]) async {
    if (context != null) {
      return handleGoogleSignIn(context);
    }
    try {
      if (kIsWeb) {
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        authProvider.addScope('email');
        authProvider.addScope('profile');
        final userCredential = await _auth.signInWithPopup(authProvider);
        if (userCredential.user != null) {
          unawaited(_ensureUserProfile(userCredential.user));
        }
        return userCredential;
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          unawaited(_ensureUserProfile(userCredential.user));
        }
        return userCredential;
      }
    } catch (e) {
      debugPrint('Google Sign-In Exception: $e');
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmail(
    String email,
    String password, [
    BuildContext? context,
  ]) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    unawaited(_ensureUserProfile(userCredential.user));
    if (userCredential.user != null && context != null && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    }
    return userCredential;
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
    BuildContext? context,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    if (displayName != null && displayName.isNotEmpty) {
      try {
        await userCredential.user?.updateDisplayName(displayName);
      } catch (_) {}
    }
    unawaited(_ensureUserProfile(
      userCredential.user,
      overrideName: displayName,
      overrideEmail: email,
    ));
    if (userCredential.user != null && context != null && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    }
    return userCredential;
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
  }

  Future<void> _ensureUserProfile(
    User? user, {
    String? overrideName,
    String? overrideEmail,
  }) async {
    final uid = user?.uid ?? currentUserId;
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('settings');
      final snapshot = await docRef.get();
      final effectiveName = overrideName ??
          (user?.displayName?.isNotEmpty == true
              ? user!.displayName!
              : (user?.email?.split('@').first ?? 'User'));
      final effectiveEmail = overrideEmail ?? user?.email ?? 'No email associated';
      final effectiveAvatar = user?.photoURL ?? '';

      if (!snapshot.exists) {
        await docRef.set({
          'name': effectiveName,
          'email': effectiveEmail,
          'avatarUrl': effectiveAvatar,
          'isPrivacyMode': false,
          'biometricEnabled': false,
          'reminderTime': '21:00',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await docRef.update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Also ensure meta doc for backward compatibility
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('meta')
          .set({
        'name': effectiveName,
        'email': effectiveEmail,
        'avatarUrl': effectiveAvatar,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Derive normalized username (lowercase, alphanumeric)
      String username = '';
      if (effectiveEmail.contains('@')) {
        username = effectiveEmail.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      } else if (effectiveName.isNotEmpty) {
        username = effectiveName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      }
      if (username.isEmpty) {
        username = 'user_${uid.length > 6 ? uid.substring(0, 6).toLowerCase() : uid.toLowerCase()}';
      }

      // Mirror to root users/{uid} for user discovery & 1-on-1 chat search
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'userId': uid,
        'displayName': effectiveName,
        'name': effectiveName,
        'username': username,
        'email': effectiveEmail,
        'avatarUrl': effectiveAvatar,
        'photoUrl': effectiveAvatar,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // B. Auto-Index Profile in public_profiles for Instant User Discovery
      final handle = effectiveEmail.contains('@')
          ? effectiveEmail.split('@').first.toLowerCase()
          : (effectiveName.isNotEmpty
              ? effectiveName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '')
              : (uid.length > 6 ? uid.substring(0, 6) : uid));

      final publicProfileData = {
        'uid': uid,
        'handle': handle,
        'handle_lowercase': handle.trim().toLowerCase(),
        'email': effectiveEmail,
        'displayName': effectiveName,
        'displayName_lowercase': effectiveName.trim().toLowerCase(),
        'avatarUrl': effectiveAvatar,
        'isVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        await _firestore
            .collection('public_profiles')
            .doc(uid)
            .set(publicProfileData, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Public profiles index error (_firestore): $e');
      }
    } catch (e) {
      debugPrint('Error writing user profile: $e');
    }
  }

  Future<void> syncPublicProfile() async {
    final user = FirebaseAuth.instance.currentUser ?? _auth.currentUser;
    if (user == null) return;

    final handle = user.email != null && user.email!.contains('@')
        ? user.email!.split('@').first.toLowerCase()
        : (user.uid.length >= 8 ? user.uid.substring(0, 8) : user.uid);
    final displayName = user.displayName ?? handle;

    final publicProfileData = {
      'uid': user.uid,
      'handle': handle,
      'handle_lowercase': handle.trim().toLowerCase(),
      'displayName': displayName,
      'displayName_lowercase': displayName.trim().toLowerCase(),
      'email': user.email ?? '',
      'avatarUrl': user.photoURL ?? '',
      'isVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('public_profiles')
          .doc(user.uid)
          .set(publicProfileData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error writing to _firestore public_profiles: $e');
    }

    await _ensureUserProfile(user);
    await ProfileService.bootstrapAndPurgeCorruptedProfiles(user.uid);
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('meta')
          .get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateGoalCap(String userId, double newCap) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('meta')
          .set({
        'goalCap': newCap,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating goal cap in profile: $e');
    }
  }

  /// Permanently deletes the current user account and all associated personal financial data,
  /// satisfying Google Play Account Deletion requirements.
  Future<void> deleteUserAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user session found.');
    }
    final uid = user.uid;

    try {
      // 1. Delete all user targets / vaults
      final targetsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('targets')
          .get();
      for (final doc in targetsSnap.docs) {
        await doc.reference.delete();
      }

      // 2. Delete all user transactions / ledger
      final txSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .get();
      for (final doc in txSnap.docs) {
        await doc.reference.delete();
      }

      // 3. Delete user profile sub-collection documents
      final profileSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .get();
      for (final doc in profileSnap.docs) {
        await doc.reference.delete();
      }

      // 4. Delete user root document
      await _firestore.collection('users').doc(uid).delete();

      // 5. Delete public profile document
      try {
        await _firestore.collection('public_profiles').doc(uid).delete();
      } catch (e) {
        debugPrint('Error deleting public_profiles for $uid: $e');
      }

      // 6. Delete sent/received friend requests
      try {
        final sentRequests = await _firestore
            .collection('friend_requests')
            .where('senderId', isEqualTo: uid)
            .get();
        for (final req in sentRequests.docs) {
          await req.reference.delete();
        }
        final receivedRequests = await _firestore
            .collection('friend_requests')
            .where('receiverId', isEqualTo: uid)
            .get();
        for (final req in receivedRequests.docs) {
          await req.reference.delete();
        }
      } catch (e) {
        debugPrint('Error purging friend_requests for $uid: $e');
      }

      // 7. Delete Firebase Auth User account
      await user.delete();

      // 8. Sign out local session
      await signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'For security, account deletion requires a recent sign-in. Please log out, sign back in, and try deleting your account again.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('Error during account deletion: $e');
      rethrow;
    }
  }
}
