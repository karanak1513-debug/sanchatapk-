import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'ambient_background.dart';
import 'sanchay_logo.dart';

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _shimmerAngle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _glowAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _shimmerAngle = Tween<double>(begin: 0, end: 6.28318).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AmbientBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minimalist ambient glow that softly expands
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radial expanding glow mesh
                      Container(
                        width: 160 * _scaleAnimation.value,
                        height: 160 * _scaleAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.crimson.withOpacity(0.18 * _glowAnimation.value),
                              AppColors.emerald.withOpacity(0.12 * _glowAnimation.value),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                      // Gentle circular frosted glass shimmer container
                      ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                transform: GradientRotation(_shimmerAngle.value),
                                colors: [
                                  Colors.white.withOpacity(0.92),
                                  AppColors.roseGlow.withOpacity(0.45),
                                  Colors.white.withOpacity(0.92),
                                  AppColors.primaryFixedGlow.withOpacity(0.4),
                                  Colors.white.withOpacity(0.92),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.9),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.obsidian.withOpacity(0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Transform.scale(
                                scale: _scaleAnimation.value,
                                child: const SanchayLogo(size: 48),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Brand Wordmark & Minimalist Subtitle
                  Text(
                    'SANCHAT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                      color: AppColors.obsidian,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Minimalist Wealth Cockpit',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subtle micro-pulse indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withOpacity(_glowAnimation.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Initializing Private Vault',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
