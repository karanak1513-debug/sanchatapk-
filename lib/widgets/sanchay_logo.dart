import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brand_logo.dart';

class SanchatLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const SanchatLogo({
    super.key,
    this.size = 32,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget logoMark = SanchatBrandLogo(size: size);

    if (!showText) return logoMark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoMark,
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SANCHAT WEALTH',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.emerald,
              ),
            ),
            Text(
              'Sanchat',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Backward compatibility alias
typedef SanchayLogo = SanchatLogo;
