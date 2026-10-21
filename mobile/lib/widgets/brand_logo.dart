import 'package:flutter/material.dart';

/// Official Sanchat Brand Logo:
/// Combines a sleek obsidian chat bubble glyph with a vibrant emerald ₹ savings vault center.
class SanchatBrandLogo extends StatelessWidget {
  final double size;
  const SanchatBrandLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Sleek Obsidian Chat Bubble Glyph Silhouette
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size * 0.36),
                topRight: Radius.circular(size * 0.36),
                bottomRight: Radius.circular(size * 0.36),
                bottomLeft: Radius.circular(size * 0.10), // Asymmetric chat bubble speech tail
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.28),
                  blurRadius: size * 0.28,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),

          // 2. Emerald ₹ Savings Vault Medallion Center
          Container(
            width: size * 0.58,
            height: size * 0.58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.45),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '₹',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: size * 0.33,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward compatibility alias
typedef SanchayBrandLogo = SanchatBrandLogo;
