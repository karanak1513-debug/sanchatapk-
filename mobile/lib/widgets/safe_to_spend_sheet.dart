import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../theme/app_theme.dart';

class SafeToSpendSheet extends StatefulWidget {
  const SafeToSpendSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SafeToSpendSheet(),
    );
  }

  @override
  State<SafeToSpendSheet> createState() => _SafeToSpendSheetState();
}

class _SafeToSpendSheetState extends State<SafeToSpendSheet> {
  double _simulatedExtraSpend = 500.0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final metrics = provider.safeToSpend;

    // What-If Simulation
    final currentRemainDiscretionary = metrics.remainingDiscretionaryPool;
    final daysRemaining = metrics.remainingDaysInMonth;
    final simulatedNewPool = (currentRemainDiscretionary - _simulatedExtraSpend).clamp(0.0, double.infinity);
    final simulatedNewDaily = daysRemaining > 1 ? (simulatedNewPool / (daysRemaining - 1)) : simulatedNewPool;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.obsidian.withOpacity(0.12),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppColors.emerald, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SAFE-TO-SPEND ENGINE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: AppColors.emerald,
                              ),
                            ),
                            Text(
                              'Daily Free Cashflow Quota',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.obsidian,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(backgroundColor: AppColors.surfaceContainerLow),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Today's Hero Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: metrics.isOverspent
                        ? AppColors.crimsonFixedDim.withOpacity(0.35)
                        : AppColors.emeraldFixed.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: metrics.isOverspent
                          ? AppColors.crimson.withOpacity(0.3)
                          : AppColors.emerald.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metrics.isOverspent ? 'DEFICIT OVERSPENT TODAY' : 'TODAY\'S SAFE ALLOWANCE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: metrics.isOverspent ? AppColors.crimson : AppColors.onEmeraldFixedVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                provider.formatCurrency(
                                  metrics.isOverspent ? metrics.todayOverspend : metrics.todaySafeToSpend,
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: metrics.isOverspent ? AppColors.crimson : AppColors.obsidian,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  metrics.isOverspent ? Icons.error_outline : Icons.check_circle_outline,
                                  size: 14,
                                  color: metrics.isOverspent ? AppColors.crimson : AppColors.emerald,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  metrics.statusHeadline,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.obsidian,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        metrics.statusAdvice,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.obsidian,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Mathematical Derivation Breakdown Table
                Text(
                  'MATHEMATICAL CASHFLOW DERIVATION',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.surfaceContainerHigh),
                  ),
                  child: Column(
                    children: [
                      _buildMathRow('1. Total Monthly Inflow', '+${provider.formatCurrency(metrics.monthlyInflow)}', isCredit: true),
                      _buildMathRow('2. Multi-Vault Goals Locked', '-${provider.formatCurrency(metrics.totalMonthlySavingsGoal)}', isDebit: true),
                      if (metrics.fixedRecurringCommitments > 0)
                        _buildMathRow('3. Fixed Commitments (Bills/Rent)', '-${provider.formatCurrency(metrics.fixedRecurringCommitments)}', isDebit: true),
                      _buildMathRow('4. Spent Month-to-Date', '-${provider.formatCurrency(metrics.monthToDateDebits)}', isDebit: true),
                      const Divider(height: 16),
                      _buildMathRow('Remaining Discretionary Pool', provider.formatCurrency(metrics.remainingDiscretionaryPool), isBold: true),
                      _buildMathRow('Remaining Days in Month', '${metrics.remainingDaysInMonth} days'),
                      _buildMathRow('Base Daily Allowance', provider.formatCurrency(metrics.baseDailyAllowance)),
                      if (metrics.weekendSurgeMultiplier != 1.0)
                        _buildMathRow('Weekend Surge Factor', '${(metrics.weekendSurgeMultiplier * 100).round()}% (${metrics.isWeekend ? "Weekend" : "Weekday"})'),
                      const Divider(height: 16),
                      _buildMathRow('Today\'s Allowance Cap', provider.formatCurrency(metrics.todayDailyAllowanceLimit), isBold: true),
                      _buildMathRow('Debits Incurred Today', '-${provider.formatCurrency(metrics.todayDebits)}', isDebit: true),
                      const Divider(height: 16),
                      _buildMathRow(
                        metrics.isOverspent ? 'Net Daily Deficit' : 'Net Safe-to-Spend Left',
                        provider.formatCurrency(metrics.isOverspent ? metrics.todayOverspend : metrics.todaySafeToSpend),
                        isBold: true,
                        highlightColor: metrics.isOverspent ? AppColors.crimson : AppColors.emerald,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Interactive "What-If" Spending Simulator
                Text(
                  'WHAT-IF SPENDING SIMULATOR',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Simulate an impromptu expense tonight to see the exact impact on tomorrow\'s safe daily allowance.',
                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.surfaceContainerHigh),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hypothetical Expense Tonight:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.obsidian),
                          ),
                          Text(
                            provider.formatCurrency(_simulatedExtraSpend),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.crimson,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _simulatedExtraSpend,
                        min: 0.0,
                        max: 5000.0,
                        divisions: 50,
                        activeColor: AppColors.crimson,
                        onChanged: (val) => setState(() => _simulatedExtraSpend = val),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPresetChip('₹250 (Coffee)'),
                          _buildPresetChip('₹800 (Dinner)'),
                          _buildPresetChip('₹2,000 (Shopping)'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tomorrow\'s Adjusted Safe Limit:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.obsidian),
                          ),
                          Text(
                            provider.formatCurrency(simulatedNewDaily),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label) {
    final amt = double.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
    return InkWell(
      onTap: () => setState(() => _simulatedExtraSpend = amt),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.obsidian),
        ),
      ),
    );
  }

  Widget _buildMathRow(
    String label,
    String value, {
    bool isCredit = false,
    bool isDebit = false,
    bool isBold = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? AppColors.obsidian : AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: highlightColor ??
                  (isCredit
                      ? AppColors.emerald
                      : (isDebit ? AppColors.crimson : AppColors.obsidian)),
            ),
          ),
        ],
      ),
    );
  }
}
