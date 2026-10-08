import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../services/safe_to_spend_engine.dart';
import '../theme/app_theme.dart';
import 'frosted_glass_card.dart';
import 'safe_to_spend_sheet.dart';

class SafeToSpendCard extends StatelessWidget {
  const SafeToSpendCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final metrics = provider.safeToSpend;
    final isOverspent = metrics.isOverspent;
    final burnPercent = metrics.progressPercent;
    final activeVaultCount = provider.targets.where((t) => !t.isPaused && !t.isAchieved).length;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (metrics.status) {
      case SafeToSpendStatus.comfortable:
        statusColor = AppColors.emerald;
        statusLabel = 'Protected';
        statusIcon = Icons.shield_outlined;
        break;
      case SafeToSpendStatus.approaching:
        statusColor = AppColors.amberPace;
        statusLabel = 'Pacing';
        statusIcon = Icons.timelapse;
        break;
      case SafeToSpendStatus.atLimit:
        statusColor = const Color(0xFFEA580C);
        statusLabel = 'Ceiling';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case SafeToSpendStatus.exceeded:
        statusColor = AppColors.crimson;
        statusLabel = 'Exceeded';
        statusIcon = Icons.error_outline_rounded;
        break;
    }

    return FrostedGlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: () => SafeToSpendSheet.show(context),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Meta Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'SAFE-TO-SPEND TODAY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.obsidian,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Hero Number and Limit
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.formatCurrency(
                        isOverspent ? metrics.todayOverspend : metrics.todaySafeToSpend,
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: isOverspent ? AppColors.crimson : AppColors.obsidian,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOverspent ? 'Over today\'s daily allowance' : 'Free cashflow remaining today',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'DAILY CAP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.formatCurrency(metrics.todayDailyAllowanceLimit),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.obsidian,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Pacing Progress Bar
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (burnPercent / 100).clamp(0.04, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Micro Metadata Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${provider.formatCurrency(metrics.todayDebits)} spent ($burnPercent%)',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 11, color: AppColors.onSurfaceVariant.withOpacity(0.8)),
                    const SizedBox(width: 3),
                    Text(
                      '${provider.formatCurrency(metrics.totalMonthlySavingsGoal)} locked for $activeVaultCount ${activeVaultCount == 1 ? "Goal" : "Goals"}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 12, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
