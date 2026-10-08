import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import 'sanchay_logo.dart';

class BiometricLockOverlay extends StatefulWidget {
  final Widget child;

  const BiometricLockOverlay({super.key, required this.child});

  @override
  State<BiometricLockOverlay> createState() => _BiometricLockOverlayState();
}

class _BiometricLockOverlayState extends State<BiometricLockOverlay>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final bioService = BiometricService();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Record background timestamp when app goes out of view
      bioService.recordBackgroundTimestamp();
    } else if (state == AppLifecycleState.resumed) {
      final bioEnabled = await bioService.isBiometricEnabled();
      if (!bioEnabled) {
        bioService.clearBackgroundTimestamp();
        if (mounted && _isLocked) {
          setState(() {
            _isLocked = false;
            _isAuthenticating = false;
            _authError = null;
          });
        }
        return;
      }

      if (!mounted) return;
      final provider = context.read<SanchayProvider>();
      final user = AuthService().currentUser;
      // Only lock if biometric preference is explicitly enabled, user is logged in, AND backgrounded for > 60 seconds
      if (provider.biometricLock && user != null) {
        if (bioService.shouldLockOnResume(thresholdSeconds: 60)) {
          setState(() {
            _isLocked = true;
            _authError = null;
          });
          _triggerBiometricAuth();
        }
      } else {
        bioService.clearBackgroundTimestamp();
      }
    }
  }

  void _checkInitialLock() async {
    final bioEnabled = await BiometricService().isBiometricEnabled();
    if (!bioEnabled) {
      if (mounted && _isLocked) {
        setState(() {
          _isLocked = false;
          _isAuthenticating = false;
          _authError = null;
        });
      }
      return;
    }

    if (!mounted) return;
    final provider = context.read<SanchayProvider>();
    final user = AuthService().currentUser;
    if (provider.biometricLock && user != null) {
      setState(() {
        _isLocked = true;
      });
      _triggerBiometricAuth();
    }
  }

  Future<void> _triggerBiometricAuth() async {
    final enabled = await BiometricService().isBiometricEnabled();
    if (!enabled) {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _isAuthenticating = false;
          _authError = null;
        });
      }
      return;
    }

    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });

    try {
      final success = await BiometricService().authenticateIfEnabled();

      if (!mounted) return;
      if (success) {
        setState(() {
          _isLocked = false;
          _isAuthenticating = false;
          _authError = null;
        });
      } else {
        setState(() {
          _isAuthenticating = false;
          _authError = 'Biometric scan failed or cancelled. Tap to retry.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _authError = 'Authentication error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    if (!provider.biometricLock && _isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isLocked) {
          setState(() {
            _isLocked = false;
            _isAuthenticating = false;
            _authError = null;
          });
        }
      });
    }
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  color: AppColors.background.withOpacity(0.88),
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Pulsing Biometric Icon Shield
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 104,
                                    height: 104,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          AppColors.emerald.withOpacity(0.20),
                                          AppColors.crimson.withOpacity(0.10),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.obsidian.withOpacity(0.08),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: SanchayLogo(size: 40),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              Text(
                                'Sanchay Vault Locked',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.obsidian,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Text(
                                'Biometric authentication required to access private ledger and wealth targets',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 32),

                              if (_authError != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.crimson.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.crimson.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                        color: AppColors.crimson,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _authError!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.crimson,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Unlock Action Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: _isAuthenticating
                                      ? null
                                      : _triggerBiometricAuth,
                                  icon: _isAuthenticating
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.fingerprint_rounded,
                                          size: 22,
                                          color: Colors.white,
                                        ),
                                  label: Text(
                                    _isAuthenticating
                                        ? 'Verifying...'
                                        : 'Scan Biometrics to Unlock',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.obsidian,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
