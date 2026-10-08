import 'dart:math';
import '../models/sanchay_target.dart';
import '../models/transaction.dart';

/// Pacing status for today's Safe-to-Spend daily allowance
enum SafeToSpendStatus {
  comfortable, // Spent < 60% of today's allowance (Emerald Green)
  approaching, // Spent 60% - 90% of today's allowance (Amber Warning)
  atLimit, // Spent 90% - 100% of today's allowance (Orange Alert)
  exceeded, // Spent > 100% of today's allowance (Crimson Alert)
}

/// Comprehensive metrics container for Safe-to-Spend Daily Allowance
class SafeToSpendMetrics {
  final double monthlyInflow;
  final double monthToDateDebits;
  final double totalMonthlySavingsGoal;
  final double fixedRecurringCommitments;
  final double remainingDiscretionaryPool;
  final int remainingDaysInMonth;
  final double baseDailyAllowance;
  final double todayDailyAllowanceLimit;
  final double todayDebits;
  final double todaySafeToSpend;
  final double todayOverspend;
  final double todayBurnRateRatio;
  final SafeToSpendStatus status;
  final bool isWeekend;
  final double weekendSurgeMultiplier;
  final String statusHeadline;
  final String statusAdvice;
  final double projectedGoalImpactDays;

  const SafeToSpendMetrics({
    required this.monthlyInflow,
    required this.monthToDateDebits,
    required this.totalMonthlySavingsGoal,
    required this.fixedRecurringCommitments,
    required this.remainingDiscretionaryPool,
    required this.remainingDaysInMonth,
    required this.baseDailyAllowance,
    required this.todayDailyAllowanceLimit,
    required this.todayDebits,
    required this.todaySafeToSpend,
    required this.todayOverspend,
    required this.todayBurnRateRatio,
    required this.status,
    required this.isWeekend,
    required this.weekendSurgeMultiplier,
    required this.statusHeadline,
    required this.statusAdvice,
    required this.projectedGoalImpactDays,
  });

  bool get isOverspent => todayOverspend > 0;
  int get progressPercent => (todayBurnRateRatio.clamp(0.0, 1.0) * 100).round();
}

/// Dynamic Safe-to-Spend Daily Allowance Engine
class SafeToSpendEngine {
  /// Computes the exact daily burn allowance protecting all active vaults
  static SafeToSpendMetrics calculate({
    required List<Transaction> transactions,
    required List<SanchayTarget> targets,
    required double currentLiquidSavings,
    bool weekendSurgeEnabled = true,
  }) {
    final now = DateTime.now();

    // 1. Current month calendar calculations
    final daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDayOfMonth = now.day;
    final remainingDaysInMonth = max(1, daysInCurrentMonth - currentDayOfMonth + 1);

    // 2. Identify transactions in the current calendar month
    final currentMonthTxs = transactions.where((t) =>
        t.timestamp.year == now.year && t.timestamp.month == now.month).toList();

    // Inflows (Credits) this month (strictly exclude vault deposits)
    double currentMonthCredits = currentMonthTxs
        .where((t) => t.isCredit && !t.isVaultDeposit && t.type.toLowerCase() != 'vault_deposit')
        .fold(0.0, (acc, t) => acc + t.amount);

    // Debits this month (strictly genuine expenses, exclude vault_deposit)
    final currentMonthDebits = currentMonthTxs
        .where((t) =>
            t.isDebit &&
            !t.isVaultDeposit &&
            t.type.toLowerCase() != 'vault_deposit' &&
            t.type.toLowerCase() != 'vault_transfer' &&
            (t.type.toLowerCase() == 'debit' || t.type.toLowerCase() == 'expense'))
        .fold(0.0, (acc, t) => acc + t.amount);

    // Baseline minimum monthly inflow heuristic: if user has no credits yet (e.g. start of month),
    // derive a sensible baseline from liquid savings or historical volume
    if (currentMonthCredits < 15000) {
      if (currentLiquidSavings > 20000) {
        currentMonthCredits = max(currentMonthCredits, currentLiquidSavings * 0.7);
      } else {
        currentMonthCredits = max(currentMonthCredits, 50000.0);
      }
    }

    // 3. Goal Protection Lock: Sum of daily savings pace across all active multi-vault targets
    final activeTargets = targets.where((t) => !t.isPaused && !t.isAchieved).toList();
    double totalMonthlySavingsGoal = 0.0;
    for (final t in activeTargets) {
      totalMonthlySavingsGoal += t.dailyPace * remainingDaysInMonth;
    }

    // If no explicit targets exist, assume standard 20% savings rule
    if (totalMonthlySavingsGoal <= 0) {
      totalMonthlySavingsGoal = currentMonthCredits * 0.20;
    }

    // 4. Fixed Commitments (Bills, Utilities, Rent)
    final fixedRecurringCommitments = currentMonthTxs
        .where((t) =>
            t.isDebit &&
            !t.isVaultDeposit &&
            t.type.toLowerCase() != 'vault_deposit' &&
            (t.category == 'Bills & Utilities' ||
                t.category == 'Healthcare' ||
                t.category == 'Digital Services'))
        .fold(0.0, (acc, t) => acc + t.amount);

    // 5. Remaining Discretionary Pool for the rest of the month
    // Transferring savings into a vault must NEVER crash the daily runway to ₹0.
    // Net liquid cashflow available this month:
    final netLiquidThisMonth = max(0.0, currentMonthCredits - currentMonthDebits);
    // Cap target savings deduction at 65% of net liquidity so user maintains at least 35% runway buffer
    final cappedSavingsGoal = min(totalMonthlySavingsGoal, netLiquidThisMonth * 0.65);
    final remainingDiscretionaryPool = max(
      netLiquidThisMonth * 0.35,
      netLiquidThisMonth - cappedSavingsGoal,
    );

    // 6. Base Daily Allowance: guaranteed resilient floor of at least ₹500/day
    final baseDailyAllowance = max(
      500.0,
      remainingDiscretionaryPool / remainingDaysInMonth,
    );

    // 7. Weekend Surge Weighting
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    double weekendSurgeMultiplier = 1.0;

    if (weekendSurgeEnabled) {
      // 1.25x for Saturday/Sunday, 0.90x for Monday-Friday
      weekendSurgeMultiplier = isWeekend ? 1.25 : 0.90;
    }

    final todayDailyAllowanceLimit = (baseDailyAllowance * weekendSurgeMultiplier).clamp(500.0, double.infinity);

    // 8. Today's actual debits spent (strictly excluding vault deposits)
    final todayTxs = transactions.where((t) =>
        t.isDebit &&
        !t.isVaultDeposit &&
        t.type.toLowerCase() != 'vault_deposit' &&
        t.type.toLowerCase() != 'vault_transfer' &&
        (t.type.toLowerCase() == 'debit' || t.type.toLowerCase() == 'expense') &&
        t.timestamp.year == now.year &&
        t.timestamp.month == now.month &&
        t.timestamp.day == now.day);

    final todayDebits = todayTxs.fold(0.0, (acc, t) => acc + t.amount);

    // 9. Today's Safe-to-Spend Balance
    final todaySafeToSpend = max(0.0, todayDailyAllowanceLimit - todayDebits);
    final todayOverspend = max(0.0, todayDebits - todayDailyAllowanceLimit);
    final todayBurnRateRatio = todayDailyAllowanceLimit > 0
        ? (todayDebits / todayDailyAllowanceLimit)
        : 1.0;

    // 10. Status & Human Feedback
    final SafeToSpendStatus status;
    final String headline;
    final String advice;
    double projectedImpactDays = 0.0;

    if (todayOverspend > 0) {
      status = SafeToSpendStatus.exceeded;
      headline = 'Daily Allowance Exceeded';
      projectedImpactDays = (todayOverspend / max(100.0, baseDailyAllowance)).clamp(0.5, 14.0);
      final impactStr = projectedImpactDays.toStringAsFixed(1);
      advice =
          'You spent ₹${todayOverspend.toStringAsFixed(0)} over today\'s limit. Tomorrow\'s allowance will adjust to keep your goals on track (+$impactStr days if repeated).';
    } else if (todayBurnRateRatio >= 0.90) {
      status = SafeToSpendStatus.atLimit;
      headline = 'Approaching Daily Ceiling';
      advice =
          '₹${todaySafeToSpend.toStringAsFixed(0)} left for today. Keep evening discretionary spending minimal to protect your daily quota.';
    } else if (todayBurnRateRatio >= 0.60) {
      status = SafeToSpendStatus.approaching;
      headline = 'Moderate Burn Rate';
      advice =
          'You\'ve utilized ${(todayBurnRateRatio * 100).round()}% of today\'s allowance. Plenty of buffer remaining for dinner and transit.';
    } else {
      status = SafeToSpendStatus.comfortable;
      headline = 'Safe to Spend Today';
      advice =
          'Your savings goals are fully protected. You have ₹${todaySafeToSpend.toStringAsFixed(0)} free cashflow available today.';
    }

    return SafeToSpendMetrics(
      monthlyInflow: currentMonthCredits,
      monthToDateDebits: currentMonthDebits,
      totalMonthlySavingsGoal: totalMonthlySavingsGoal,
      fixedRecurringCommitments: fixedRecurringCommitments,
      remainingDiscretionaryPool: remainingDiscretionaryPool,
      remainingDaysInMonth: remainingDaysInMonth,
      baseDailyAllowance: baseDailyAllowance,
      todayDailyAllowanceLimit: todayDailyAllowanceLimit,
      todayDebits: todayDebits,
      todaySafeToSpend: todaySafeToSpend,
      todayOverspend: todayOverspend,
      todayBurnRateRatio: todayBurnRateRatio,
      status: status,
      isWeekend: isWeekend,
      weekendSurgeMultiplier: weekendSurgeMultiplier,
      statusHeadline: headline,
      statusAdvice: advice,
      projectedGoalImpactDays: projectedImpactDays,
    );
  }

  /// Simulates the impact of a prospective expenditure on remaining daily and monthly allowance
  static ({
    double simulatedSafeToday,
    double simulatedRemainingPool,
    double simulatedNextDailyPace,
  }) simulateExpenseImpact(SafeToSpendMetrics metrics, double prospectiveAmount) {
    final simulatedSafeToday = max(0.0, metrics.todaySafeToSpend - prospectiveAmount);
    final simulatedRemainingPool = max(0.0, metrics.remainingDiscretionaryPool - prospectiveAmount);
    final remainingDays = metrics.remainingDaysInMonth;
    final simulatedNextDailyPace = remainingDays > 1
        ? (simulatedRemainingPool / (remainingDays - 1))
        : simulatedRemainingPool;

    return (
      simulatedSafeToday: simulatedSafeToday,
      simulatedRemainingPool: simulatedRemainingPool,
      simulatedNextDailyPace: simulatedNextDailyPace,
    );
  }
}

