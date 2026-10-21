import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;

  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _keyBiometricEnabled = 'biometric_app_lock_enabled';

  final ValueNotifier<bool> isLockedNotifier = ValueNotifier<bool>(false);

  bool get isLocked => isLockedNotifier.value;
  set isLocked(bool val) => isLockedNotifier.value = val;

  /// Background timestamp tracking to avoid biometric loops
  DateTime? _backgroundTimestamp;
  bool _isAuthenticating = false;

  bool get isAuthenticating => _isAuthenticating;

  /// Records when the application enters the background
  void recordBackgroundTimestamp() {
    _backgroundTimestamp = DateTime.now();
  }

  /// Clears background timestamp
  void clearBackgroundTimestamp() {
    _backgroundTimestamp = null;
  }

  /// Checks if background duration exceeded the required threshold (> 60 seconds)
  bool shouldLockOnResume({int thresholdSeconds = 60}) {
    if (_backgroundTimestamp == null) return false;
    final elapsed = DateTime.now().difference(_backgroundTimestamp!).inSeconds;
    _backgroundTimestamp = null;
    return elapsed >= thresholdSeconds;
  }

  /// Verifies if device has biometric hardware (Fingerprint, Face, Iris)
  Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('Biometric hardware capability check error: $e');
      return false;
    }
  }

  /// Lists available biometric hardware types enrolled on this device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error retrieving enrolled biometrics: $e');
      return [];
    }
  }

  /// Reads persistent biometric preference - defaults strictly to FALSE
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Persists biometric lock preference locally and syncs with Firestore
  Future<void> setBiometricEnabled(bool enabled, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);

    try {
      final uid = userId ?? AuthService().currentUserId;
      if (uid.isNotEmpty) {
        await AuthService.firestoreInstance
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('settings')
            .set({
          'biometricEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving biometric preferences: $e');
    }
  }

  /// Absolute early-return gate: Never prompts when biometric lock is disabled
  Future<bool> authenticateIfEnabled() async {
    final enabled = await isBiometricEnabled();
    if (!enabled) {
      debugPrint('Biometric lock is disabled by user. Bypassing check.');
      isLocked = false;
      return true; // Bypass authentication immediately
    }

    // Only execute LocalAuthentication if enabled is explicitly true
    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      if (!canCheck) {
        isLocked = false;
        return true;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to access Sanchay',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        isLocked = false;
      }
      return authenticated;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  /// Prompts native OS Biometric Dialog (Fingerprint / Face ID)
  /// Guaranteed to bypass immediately if biometric lock is disabled unless force=true
  Future<bool> authenticate({
    String localizedReason = 'Scan fingerprint to access Sanchay Vault',
    bool stickyAuth = true,
    bool force = false,
  }) async {
    if (kIsWeb) {
      isLocked = false;
      return true; // Web simulation bypass
    }

    if (!force) {
      final enabled = await isBiometricEnabled();
      if (!enabled) {
        debugPrint('Biometric lock is disabled by user. Bypassing check.');
        isLocked = false;
        return true;
      }
    }

    if (_isAuthenticating) {
      debugPrint('Biometric auth already in progress. Ignoring duplicate trigger.');
      return false;
    }

    _isAuthenticating = true;
    try {
      final canAuth = await canCheckBiometrics();
      if (!canAuth) {
        debugPrint('Device does not support biometrics or has no biometrics enrolled');
        isLocked = false;
        return true;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (authenticated) {
        isLocked = false;
      }
      return authenticated;
    } catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }
}
