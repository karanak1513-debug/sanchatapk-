import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/center_hud_alert.dart';
import '../widgets/frosted_glass_card.dart';
import '../widgets/sanchay_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUpMode = false;
  bool _isSigningIn = false;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _proceedToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
  }

  void _showError(String message) {
    if (!mounted) return;
    showCenterAlert(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.crimson,
    );
  }

  void _handleGoogleSignIn() async {
    setState(() => _isSigningIn = true);
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Use Firebase's dedicated Web Auth Provider to avoid cross-window drop
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        authProvider.addScope('email');
        authProvider.addScope('profile');
        userCredential = await FirebaseAuth.instance.signInWithPopup(authProvider);
      } else {
        // Native Android/iOS implementation
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _isSigningIn = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // Force Immediate Navigation to Dashboard upon credential receipt
      if (userCredential.user != null && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      } else {
        if (mounted) setState(() => _isSigningIn = false);
      }
    } on PlatformException catch (e) {
      debugPrint('Google Sign-In PlatformException: $e');
      if (mounted) {
        setState(() => _isSigningIn = false);
        String msg = "Google Sign-In is unavailable. Please log in with Email and Password.";
        if ((e.code == 'sign_in_failed' && e.message?.contains('10') == true) ||
            e.code == '10' ||
            e.toString().contains('ApiException: 10')) {
          msg = "Google Auth configuration error (Code 10). Please use Email login.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        setState(() => _isSigningIn = false);
        final errorStr = e.toString();
        if (errorStr.contains('10') || errorStr.contains('ApiException: 10')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Google Auth configuration error (Code 10). Please use Email login."),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Login failed: $e"),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSigningIn = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isSignUpMode) {
        final name = _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : email.split('@').first;
        final cred = await AuthService().signUpWithEmail(
          email,
          password,
          displayName: name,
          context: context,
        );
        if (!mounted) return;
        if (cred.user != null) {
          _proceedToDashboard();
        }
      } else {
        final cred = await AuthService().signInWithEmail(
          email,
          password,
          context,
        );
        if (!mounted) return;
        if (cred.user != null) {
          _proceedToDashboard();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigningIn = false);

      String errorMsg = 'Authentication failed';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMsg = 'No account found with this email. Please sign up.';
            break;
          case 'wrong-password':
          case 'invalid-credential':
            errorMsg = 'Invalid passkey or email credentials.';
            break;
          case 'email-already-in-use':
            errorMsg = 'This email is already registered. Please sign in.';
            break;
          case 'weak-password':
            errorMsg = 'Passkey is too weak. Please use at least 6 characters.';
            break;
          case 'invalid-email':
            errorMsg = 'Invalid email address format.';
            break;
          default:
            errorMsg = e.message ?? e.code;
        }
      } else {
        errorMsg = e.toString().replaceAll('Exception:', '').trim();
      }
      _showError(errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Glowing circular insignia
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.crimson.withOpacity(0.18),
                                  AppColors.emerald.withOpacity(0.10),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 68,
                            height: 68,
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
                              child: SanchayLogo(size: 38),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // App Wordmark
                    Center(
                      child: Text(
                        'SANCHAT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                          color: AppColors.obsidian,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle
                    Center(
                      child: Text(
                        'Minimalist Wealth Cockpit',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Frosted Glass Authentication Form
                    FrostedGlassCard(
                      borderRadius: 28,
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Primary OAuth: Continue with Google
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.obsidian,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSigningIn
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _buildGoogleLogo(),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Continue with Google',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Separator
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.outlineVariant.withOpacity(0.5),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    _isSignUpMode ? 'or register with email' : 'or sign in with email',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.outlineVariant.withOpacity(0.5),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Full Name (Only in Sign Up Mode)
                            if (_isSignUpMode) ...[
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'Full Name',
                                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                                  filled: true,
                                  fillColor: AppColors.surfaceContainerLow,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (val) {
                                  if (_isSignUpMode && (val == null || val.trim().isEmpty)) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Email Address Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLow,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || !val.contains('@') || !val.contains('.')) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Password / Passkey Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLow,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Email Sign In / Sign Up Submit Button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isSigningIn ? null : _handleEmailAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.obsidian,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  _isSignUpMode ? 'Create Master Vault' : 'Unlock Vault',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Switch between Sign In and Sign Up
                            Center(
                              child: TextButton(
                                onPressed: _isSigningIn
                                    ? null
                                    : () {
                                        setState(() {
                                          _isSignUpMode = !_isSignUpMode;
                                          _formKey.currentState?.reset();
                                        });
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.onSurface,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  _isSignUpMode
                                      ? 'Already registered? Unlock existing vault'
                                      : 'New to Sanchay? Create Master Vault',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.obsidian,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Security Assurance Footer
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: AppColors.onSurfaceVariant.withOpacity(0.7),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'End-to-End Firebase Encrypted & Authenticated',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurfaceVariant.withOpacity(0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontWeight: FontWeight.w900,
            fontSize: 13,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
