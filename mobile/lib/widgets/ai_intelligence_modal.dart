import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../theme/app_theme.dart';
import 'configure_target_modal.dart';
import 'vault_contribution_modal.dart';

/// Redesigned Smart Money Insights modal
/// Built with 3 crystal-clear cards:
/// 1. Score Card: "Financial Health: 100/100 (Excellent)"
/// 2. Goal Progress: "You need to save ₹[X] per day to finish by [Date]"
/// 3. Spending Alert: "Safe to spend ₹[Y] today without breaking your goal"
class AIIntelligenceModal extends StatelessWidget {
  const AIIntelligenceModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AIIntelligenceModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final health = provider.intelligenceReport.healthScore;
    final targetDateStr = DateFormat('MMM d, yyyy').format(provider.targetDate);
    final safeDailySpend = (provider.dailyTargetBenchmark - provider.todaySaved)
        .clamp(0.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header with Simplified Human Language
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.emeraldFixed.withOpacity(0.4),
                              border: Border.all(
                                color: AppColors.emerald.withOpacity(0.3),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: AppColors.emerald,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SMART MONEY INSIGHTS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: AppColors.crimson,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your Daily Summary',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: AppColors.obsidian,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.onSurfaceVariant,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // -----------------------------------------------------------
                  // CARD 1: Score Card
                  // "Financial Health: 100/100 (Excellent)"
                  // -----------------------------------------------------------
                  _buildCard(
                    icon: Icons.favorite_rounded,
                    iconColor: AppColors.emerald,
                    tag: 'SCORE CARD',
                    title: 'Financial Health: ${health.totalScore}/100 (${health.ratingTier})',
                    subtitle: health.totalScore >= 80
                        ? 'Safety Balance Strong • Zero high-risk debt detected'
                        : 'Keep saving daily to build your safety net',
                    accentColor: AppColors.emerald,
                  ),
                  const SizedBox(height: 12),

                  // -----------------------------------------------------------
                  // CARD 2: Goal Progress
                  // "You need to save ₹[X] per day to finish by [Date]"
                  // -----------------------------------------------------------
                  _buildCard(
                    icon: Icons.flag_rounded,
                    iconColor: const Color(0xFF0284C7),
                    tag: 'GOAL PROGRESS',
                    title: 'You need to save ${provider.formatCurrency(provider.dailyPace)} per day to finish by $targetDateStr',
                    subtitle: '${provider.formatCurrency(provider.currentVault)} saved of ${provider.formatCurrency(provider.goalCap)} (${provider.vaultPercentage}% complete)',
                    accentColor: const Color(0xFF0284C7),
                  ),
                  const SizedBox(height: 12),

                  // -----------------------------------------------------------
                  // CARD 3: Spending Alert
                  // "Safe to spend ₹[Y] today without breaking your goal"
                  // -----------------------------------------------------------
                  _buildCard(
                    icon: Icons.shield_rounded,
                    iconColor: provider.isTodayTargetMet
                        ? AppColors.emerald
                        : const Color(0xFFF59E0B),
                    tag: 'SPENDING ALERT',
                    title: safeDailySpend > 0
                        ? 'Safe to spend ${provider.formatCurrency(safeDailySpend)} today without breaking your goal'
                        : 'Daily spending limit reached for today',
                    subtitle: provider.isTargetOnTrack
                        ? "Great pace! You'll hit your goal early"
                        : "Behind Schedule: add ${provider.formatCurrency(provider.dailyPace - provider.todaySaved)} to catch up",
                    accentColor: provider.isTodayTargetMet
                        ? AppColors.emerald
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ConfigureTargetModal.show(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.surfaceContainerHigh),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text(
                            'Edit Goal Target',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.obsidian,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            VaultContributionModal.show(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.obsidian,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Add to Savings',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String tag,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
