import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Base Canvas & Atmosphere
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFF7F9FB);
  static const Color surfaceDim = Color(0xFFD8DADC);
  static const Color surfaceBright = Color(0xFFF7F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFECEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color surfaceContainerHighest = Color(0xFFE0E3E5);
  static const Color surfaceVariant = Color(0xFFE2E8F0);

  // Inks & Typography
  static const Color onSurface = Color(0xFF0F172A); // Obsidian Ink
  static const Color onSurfaceVariant = Color(0xFF64748B); // Slate Muted
  static const Color slateWhisper = Color(0xFF94A3B8); // Sub-tier ink

  // Precision Accents
  static const Color crimson = Color(0xFFDC2626); // Precision Crimson (debits, alerts)
  static const Color crimsonContainer = Color(0xFFE02928);
  static const Color crimsonFixed = Color(0xFFFFDAD6);
  static const Color crimsonFixedDim = Color(0xFFFFB4AB);

  static const Color emerald = Color(0xFF059669); // Emerald Green (credits, yields)
  static const Color emeraldDark = Color(0xFF047857);
  static const Color emeraldContainer = Color(0xFF002114);
  static const Color emeraldFixed = Color(0xFF85F8C4);
  static const Color onEmeraldFixedVariant = Color(0xFF005137);

  static const Color obsidian = Color(0xFF0F172A);
  static const Color obsidianSlate = Color(0xFF1E293B);
  static const Color amberPace = Color(0xFFD97706); // Warm Amber for pacing/paused alerts

  static const Color outline = Color(0xFF76777D);
  static const Color outlineVariant = Color(0xFFC6C6CD);

  // Ambient Glows
  static const Color roseGlow = Color(0xFFFFE4E6);
  static const Color icySlateGlow = Color(0xFFF1F5F9);
  static const Color primaryFixedGlow = Color(0xFFDAE2FD);

  // Glass Physical Boundaries
  static const Color hairlineBorderTop = Color(0xF2FFFFFF);
  static const Color hairlineBorderBottom = Color(0x66CBD5E1);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.obsidian,
        onPrimary: Colors.white,
        secondary: AppColors.crimson,
        onSecondary: Colors.white,
        error: AppColors.crimson,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        outline: AppColors.outlineVariant,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: AppColors.onSurface,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: AppColors.onSurface,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: AppColors.onSurface,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppColors.onSurface,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: AppColors.onSurface,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.15,
          color: AppColors.onSurface,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurface,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurface,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: AppColors.onSurface,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: AppColors.onSurfaceVariant,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }

  // Inter font for Tabular figures
  static TextStyle monoNumeric({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.onSurface,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
