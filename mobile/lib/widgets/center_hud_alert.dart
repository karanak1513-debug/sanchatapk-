import 'dart:ui';
import 'package:flutter/material.dart';

/// Screen-Center Frosted Glass HUD Alert
/// Appears dead-center with a spring-scale transition (CurvedAnimation easeOutBack)
/// and auto-dismisses smoothly after 1.8 seconds.
void showCenterAlert(
  BuildContext context, {
  required String message,
  String? subtitle,
  IconData icon = Icons.check_circle_outline,
  Color iconColor = const Color(0xFF10B981),
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Alert',
    barrierColor: Colors.black.withOpacity(0.2),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
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
    transitionBuilder: (context, anim, secondaryAnim, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: child,
    ),
  );

  Future.delayed(const Duration(milliseconds: 1800), () {
    if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  });
}

/// Compatibility wrapper for CenterAlert.show
class CenterAlert {
  static void show(
    BuildContext context, {
    required String message,
    String? subtitle,
    IconData icon = Icons.check_circle_outline,
    Color? iconColor,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    showCenterAlert(
      context,
      message: message,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor ?? const Color(0xFF10B981),
    );
  }

  static void dismiss() {}
}
