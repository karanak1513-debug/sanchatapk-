import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Off-White Architectural Canvas
        Container(
          color: AppColors.background,
        ),

        // Ambient Chromatic Glows
        // 1. Top-Right Soft Rose Glow
        Positioned(
          top: -60,
          right: -60,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.roseGlow.withOpacity(0.55),
                    AppColors.roseGlow.withOpacity(0.0),
                  ],
                  stops: const [0.1, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 2. Bottom-Left Cool Glacier Slate / Primary Tint Glow
        Positioned(
          bottom: -80,
          left: -60,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryFixedGlow.withOpacity(0.35),
                    AppColors.icySlateGlow.withOpacity(0.0),
                  ],
                  stops: const [0.1, 1.0],
                ),
              ),
            ),
          ),
        ),

        // Content
        SafeArea(
          bottom: false,
          child: child,
        ),
      ],
    );
  }
}
