import 'dart:math';
import 'package:intl/intl.dart';
import '../models/sanchay_target.dart';
import '../models/transaction.dart';

/// Severity of an AI Financial Recommendation
enum AIRecommendationType {
  critical,
  warning,
  opportunity,
  achievement,
}

/// Target Feasibility Classification
enum TargetFeasibilityStatus {
  achieved,
  optimal,
  feasible,
  strained,
  atRisk,
  frozen,
}

/// A structured, actionable financial recommendation
class AIRecommendation {
  final String id;
  final String title;
  final String description;
  final AIRecommendationType type;
  final double impactAmount; // Quantified Rupee impact (e.g. +₹450/day or ₹1,800/mo)
  final String actionLabel; // E.g. "Deposit Now", "Adjust Target", "Review Leakage"
  final String category; // "Target Run-Rate", "Spending Leakage", "Runway & Buffer", "Cashflow"
  final int priority; // 1 (Highest) to 5

  const AIRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.impactAmount = 0.0,
    required this.actionLabel,
    required this.category,
    required this.priority,
  });
}

/// Detected spending anomaly / velocity spike
class SpendingAnomaly {
  final String merchant;
  final double amount;
  final DateTime date;
  final double multiplierAboveAverage;
  final String category;

  const SpendingAnomaly({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.multiplierAboveAverage,
    required this.category,
  });
}

/// Detected recurring micro-leakage pattern
class SpendingLeakage {
  final String category;
  final int transactionCount;
  final double totalAmount;
  final double potentialMonthlySavings;
  final String diagnosticReason;

  const SpendingLeakage({
    required this.category,
    required this.transactionCount,
    required this.totalAmount,
    required this.potentialMonthlySavings,
    required this.diagnosticReason,
  });
}

/// Target feasibility & run-rate diagnostic
class TargetFeasibility {
  final TargetFeasibilityStatus status;
  final double feasibilityScore; // 0.0 to 100.0%
  final double requiredDailyPace;
  final double effectiveDailySurplus;
  final double dailyShortfallOrSurplus; // Positive = surplus, Negative = shortfall
  final DateTime projectedCompletionDate;
  final int daysAheadOrBehind; // Positive = ahead, Negative = behind
  final String primarySummary;
  final String tacticalPrescription;

  const TargetFeasibility({
    required this.status,
    required this.feasibilityScore,
    required this.requiredDailyPace,
    required this.effectiveDailySurplus,
    required this.dailyShortfallOrSurplus,
    required this.projectedCompletionDate,
    required this.daysAheadOrBehind,
    required this.primarySummary,
    required this.tacticalPrescription,
  });
}

/// Cashflow & liquidity velocity metrics
class CashflowMetrics {
  final double monthlyInflow;
  final double monthlyBurnRate;
  final double netMonthlySurplus;
  final double dailyAverageBurn;
  final double savingsRate; // Percentage 0 - 100%
  final double runwayDays;
  final double totalCreditsCount;
  final double totalDebitsCount;

  const CashflowMetrics({
    required this.monthlyInflow,
    required this.monthlyBurnRate,
    required this.netMonthlySurplus,
    required this.dailyAverageBurn,
    required this.savingsRate,
    required this.runwayDays,
    required this.totalCreditsCount,
    required this.totalDebitsCount,
  });
}

/// Multi-pillar Financial Health Score (0 - 100)
class FinancialHealthScore {
  final int totalScore; // 0 - 100
  final int savingsDisciplineScore; // max 30
  final int targetVelocityScore; // max 30
  final int burnControlScore; // max 20
  final int runwaySufficiencyScore; // max 20
  final String ratingTier; // "Fortress Reserve", "Strong Momentum", "Moderate Velocity", "Strained Runway"

  const FinancialHealthScore({
    required this.totalScore,
    required this.savingsDisciplineScore,
    required this.targetVelocityScore,
    required this.burnControlScore,
    required this.runwaySufficiencyScore,
    required this.ratingTier,
  });
}

/// Complete Financial Intelligence Report
class FinancialIntelligenceReport {
  final FinancialHealthScore healthScore;
  final TargetFeasibility targetFeasibility;
  final CashflowMetrics cashflowMetrics;
  final List<AIRecommendation> recommendations;
  final List<SpendingLeakage> leakages;
  final List<SpendingAnomaly> anomalies;
  final double todayAdaptivePace;
  final bool isWeekendSurgeActive;

  const FinancialIntelligenceReport({
    required this.healthScore,
    required this.targetFeasibility,
    required this.cashflowMetrics,
    required this.recommendations,
    required this.leakages,
    required this.anomalies,
    required this.todayAdaptivePace,
    required this.isWeekendSurgeActive,
  });
}

/// Autonomous on-device deterministic financial intelligence engine
class FinancialIntelligenceEngine {
  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String formatCurrency(double amount) {
    return _currencyFmt.format(amount.round());
  }

  /// Run comprehensive deterministic analysis on transactions and targets
  static FinancialIntelligenceReport analyze({
    required List<Transaction> transactions,
    required List<SanchayTarget> targets,
    SanchayTarget? primaryTarget,
    double currentLiquidSavings = 0.0,
    bool adaptiveDailyPaceEnabled = true,
    bool weekendSurgeEnabled = true,
  }) {
    final now = DateTime.now();
    final effectiveTarget = primaryTarget ?? (targets.isNotEmpty ? targets.first : null);

    // 1. Compute Cashflow & Velocity Metrics
    final cashflow = _calculateCashflowMetrics(
      transactions: transactions,
      currentLiquidSavings: currentLiquidSavings,
      now: now,
    );

    // 2. Compute Target Feasibility & Projected Milestones
    final feasibility = _calculateTargetFeasibility(
      target: effectiveTarget,
      cashflow: cashflow,
      currentLiquidSavings: currentLiquidSavings,
      transactions: transactions,
      now: now,
    );

    // 3. Compute Adaptive Pacing & Weekend Surge Adjustments
    final pacingResult = _calculateAdaptivePacing(
      target: effectiveTarget,
      transactions: transactions,
      adaptiveEnabled: adaptiveDailyPaceEnabled,
      weekendSurgeEnabled: weekendSurgeEnabled,
      now: now,
    );

    // 4. Detect Anomalies & Micro-Leakages
    final anomalies = _detectSpendingAnomalies(transactions: transactions, now: now);
    final leakages = _detectMicroLeakages(transactions: transactions, now: now);

    // 5. Calculate Multi-Pillar Health Score
    final healthScore = _calculateHealthScore(
      cashflow: cashflow,
      feasibility: feasibility,
      anomalies: anomalies,
      leakages: leakages,
    );

    // 6. Generate Contextual Prioritized Actionable Recommendations
    final recommendations = _generateRecommendations(
      target: effectiveTarget,
      feasibility: feasibility,
      cashflow: cashflow,
      anomalies: anomalies,
      leakages: leakages,
      todayPace: pacingResult.todayPace,
      isWeekend: pacingResult.isWeekend,
    );

    return FinancialIntelligenceReport(
      healthScore: healthScore,
      targetFeasibility: feasibility,
      cashflowMetrics: cashflow,
      recommendations: recommendations,
      leakages: leakages,
      anomalies: anomalies,
      todayAdaptivePace: pacingResult.todayPace,
      isWeekendSurgeActive: pacingResult.isWeekend && weekendSurgeEnabled,
    );
  }

  // =========================================================================
  // Deterministic Algorithms
  // =========================================================================

  static CashflowMetrics _calculateCashflowMetrics({
    required List<Transaction> transactions,
    required double currentLiquidSavings,
    required DateTime now,
  }) {
    if (transactions.isEmpty) {
      return const CashflowMetrics(
        monthlyInflow: 0.0,
        monthlyBurnRate: 0.0,
        netMonthlySurplus: 0.0,
        dailyAverageBurn: 0.0,
        savingsRate: 0.0,
        runwayDays: 999.0,
        totalCreditsCount: 0,
        totalDebitsCount: 0,
      );
    }

    // Window transactions into 30 days or available historical scope
    DateTime oldestDate = now;
    double creditsSum = 0.0;
    double debitsSum = 0.0;
    int creditsCount = 0;
    int debitsCount = 0;

    for (final tx in transactions) {
      if (tx.timestamp.isBefore(oldestDate)) {
        oldestDate = tx.timestamp;
      }
      if (tx.isVaultDeposit || tx.type.toLowerCase() == 'vault_deposit') {
        continue; // Exclude internal vault deposits from cashflow burn rate
      }
      if (tx.isCredit) {
        creditsSum += tx.amount;
        creditsCount++;
      } else if (tx.isDebit) {
        debitsSum += tx.amount;
        debitsCount++;
      }
    }

    final daysSpan = max(1, now.difference(oldestDate).inDays + 1);
    final normalizer = 30.0 / min(30.0, daysSpan.toDouble());

    // Normalize to 30-day velocity
    final monthlyInflow = creditsSum * (daysSpan < 30 ? normalizer : 1.0);
    final monthlyBurnRate = debitsSum * (daysSpan < 30 ? normalizer : 1.0);
    final netMonthlySurplus = monthlyInflow - monthlyBurnRate;
    final dailyAverageBurn = monthlyBurnRate / 30.0;

    double savingsRate = 0.0;
    if (monthlyInflow > 0) {
      savingsRate = ((monthlyInflow - monthlyBurnRate) / monthlyInflow * 100.0).clamp(-100.0, 100.0);
    }

    final totalLiquidity = currentLiquidSavings > 0 ? currentLiquidSavings : max(0.0, netMonthlySurplus);
    final runwayDays = dailyAverageBurn > 0 ? (totalLiquidity / dailyAverageBurn) : 999.0;

    return CashflowMetrics(
      monthlyInflow: monthlyInflow,
      monthlyBurnRate: monthlyBurnRate,
      netMonthlySurplus: netMonthlySurplus,
      dailyAverageBurn: dailyAverageBurn,
      savingsRate: savingsRate,
      runwayDays: runwayDays,
      totalCreditsCount: creditsCount.toDouble(),
      totalDebitsCount: debitsCount.toDouble(),
    );
  }

  static TargetFeasibility _calculateTargetFeasibility({
    required SanchayTarget? target,
    required CashflowMetrics cashflow,
    required double currentLiquidSavings,
    required List<Transaction> transactions,
    required DateTime now,
  }) {
    if (target == null) {
      return TargetFeasibility(
        status: TargetFeasibilityStatus.optimal,
        feasibilityScore: 100.0,
        requiredDailyPace: 0.0,
        effectiveDailySurplus: cashflow.netMonthlySurplus > 0 ? cashflow.netMonthlySurplus / 30.0 : 0.0,
        dailyShortfallOrSurplus: 0.0,
        projectedCompletionDate: now,
        daysAheadOrBehind: 0,
        primarySummary: 'No active target configured. Configure a Reserve Vault to activate real-time pacing.',
        tacticalPrescription: 'Define a target cap and target deadline to unlock run-rate tracking.',
      );
    }

    if (target.isPaused) {
      return TargetFeasibility(
        status: TargetFeasibilityStatus.frozen,
        feasibilityScore: 50.0,
        requiredDailyPace: 0.0,
        effectiveDailySurplus: cashflow.netMonthlySurplus > 0 ? cashflow.netMonthlySurplus / 30.0 : 0.0,
        dailyShortfallOrSurplus: 0.0,
        projectedCompletionDate: target.targetDate,
        daysAheadOrBehind: 0,
        primarySummary: 'Target Paused: Pacing calculations and run-rate projections are frozen.',
        tacticalPrescription: 'Resume the target in Target Operations to restart pacing monitoring.',
      );
    }

    final accumulation = max(target.currentAccumulation, currentLiquidSavings);
    final remainingAmount = (target.targetCap - accumulation).clamp(0.0, target.targetCap);

    if (remainingAmount <= 0) {
      return TargetFeasibility(
        status: TargetFeasibilityStatus.achieved,
        feasibilityScore: 100.0,
        requiredDailyPace: 0.0,
        effectiveDailySurplus: cashflow.netMonthlySurplus > 0 ? cashflow.netMonthlySurplus / 30.0 : 0.0,
        dailyShortfallOrSurplus: 0.0,
        projectedCompletionDate: now,
        daysAheadOrBehind: 0,
        primarySummary: 'Goal Achieved! You have successfully reached the 100% accumulation threshold.',
        tacticalPrescription: 'Archive this target or roll accumulated funds into a new high-yield reserve.',
      );
    }

    final remainingDays = target.remainingDays;
    final requiredDailyPace = remainingAmount / remainingDays;
    final dailySurplusCapacity = cashflow.netMonthlySurplus > 0 ? cashflow.netMonthlySurplus / 30.0 : 0.0;
    final dailyDelta = dailySurplusCapacity - requiredDailyPace;

    // Estimate realistic daily accumulation velocity from recent 14-day history
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));
    final recentDeposits = transactions
        .where((t) => t.isCredit && t.timestamp.isAfter(fourteenDaysAgo))
        .fold(0.0, (acc, t) => acc + t.amount);
    final recentVelocity = recentDeposits / 14.0;
    final effectiveVelocity = recentVelocity > 0 ? recentVelocity : dailySurplusCapacity;

    int projectedDays = 0;
    if (effectiveVelocity > 0) {
      projectedDays = (remainingAmount / effectiveVelocity).round();
    } else {
      projectedDays = remainingDays + 60; // Lagging default
    }

    final projectedCompletionDate = now.add(Duration(days: max(1, projectedDays)));
    final daysAheadOrBehind = remainingDays - projectedDays;

    TargetFeasibilityStatus status;
    double feasibilityScore;

    if (dailySurplusCapacity <= 0 && cashflow.monthlyInflow > 0) {
      status = TargetFeasibilityStatus.atRisk;
      feasibilityScore = 25.0;
    } else if (dailyDelta >= requiredDailyPace * 0.25) {
      status = TargetFeasibilityStatus.optimal;
      feasibilityScore = 95.0;
    } else if (dailyDelta >= -requiredDailyPace * 0.1) {
      status = TargetFeasibilityStatus.feasible;
      feasibilityScore = 80.0;
    } else if (dailyDelta >= -requiredDailyPace * 0.4) {
      status = TargetFeasibilityStatus.strained;
      feasibilityScore = 55.0;
    } else {
      status = TargetFeasibilityStatus.atRisk;
      feasibilityScore = 30.0;
    }

    final formattedPace = formatCurrency(requiredDailyPace);
    final formattedDate = DateFormat('MMM d, yyyy').format(target.targetDate);
    final formattedProjected = DateFormat('MMM d, yyyy').format(projectedCompletionDate);

    String summary;
    String prescription;

    switch (status) {
      case TargetFeasibilityStatus.optimal:
        summary = "Great pace! You'll hit your goal early ($formattedProjected).";
        prescription = 'Surplus capacity comfortably covers the $formattedPace/day quota. Consider compounding excess liquidity.';
        break;
      case TargetFeasibilityStatus.feasible:
        summary = 'On Track — Net disposable surplus aligns precisely with $formattedPace/day quota.';
        prescription = 'Maintain spending discipline to hit $formattedDate on schedule.';
        break;
      case TargetFeasibilityStatus.strained:
        final shortfall = formatCurrency(dailyDelta.abs());
        summary = 'Pacing Strained — Daily quota is lagging by $shortfall/day behind disposable cashflow.';
        prescription = 'Trim discretionary outflows or extend target deadline by ${(dailyDelta.abs() / max(1.0, requiredDailyPace) * remainingDays).round()} days.';
        break;
      case TargetFeasibilityStatus.atRisk:
        summary = 'Target At Risk — Outflows currently eclipse available daily allocation ($formattedPace/day needed).';
        prescription = 'Immediate intervention needed: Curb non-essential categories or adjust target cap.';
        break;
      case TargetFeasibilityStatus.frozen:
      case TargetFeasibilityStatus.achieved:
        summary = 'Target Inactive';
        prescription = 'No active adjustments needed.';
        break;
    }

    return TargetFeasibility(
      status: status,
      feasibilityScore: feasibilityScore,
      requiredDailyPace: requiredDailyPace,
      effectiveDailySurplus: dailySurplusCapacity,
      dailyShortfallOrSurplus: dailyDelta,
      projectedCompletionDate: projectedCompletionDate,
      daysAheadOrBehind: daysAheadOrBehind,
      primarySummary: summary,
      tacticalPrescription: prescription,
    );
  }

  static ({double todayPace, bool isWeekend}) _calculateAdaptivePacing({
    required SanchayTarget? target,
    required List<Transaction> transactions,
    required bool adaptiveEnabled,
    required bool weekendSurgeEnabled,
    required DateTime now,
  }) {
    if (target == null || target.isPaused) {
      return (todayPace: 0.0, isWeekend: false);
    }

    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final baseDailyPace = target.dailyPace;

    if (!adaptiveEnabled && !weekendSurgeEnabled) {
      return (todayPace: baseDailyPace, isWeekend: isWeekend);
    }

    double pace = baseDailyPace;

    // Weekend surge allowance (relax weekend quota by 25%, rebalance on weekdays)
    if (weekendSurgeEnabled) {
      if (isWeekend) {
        // Weekend budget gets relaxed by 25%
        pace = baseDailyPace * 1.18;
      } else {
        // Weekdays compensate slightly
        pace = baseDailyPace * 0.93;
      }
    }

    // Adaptive smoothing based on rolling 7-day spending trends
    if (adaptiveEnabled) {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final recentDebits = transactions
          .where((t) => t.isDebit && t.timestamp.isAfter(sevenDaysAgo))
          .fold(0.0, (acc, t) => acc + t.amount);
      final avg7DayDaily = recentDebits / 7.0;

      // If average daily spend in last 7 days was higher than baseline, scale pace smoothly
      if (avg7DayDaily > 0) {
        final ratio = (recentDebits / max(1.0, target.monthlyPace / 4.0)).clamp(0.85, 1.15);
        pace = pace * ratio;
      }
    }

    return (todayPace: max(0.0, pace), isWeekend: isWeekend);
  }

  static List<SpendingAnomaly> _detectSpendingAnomalies({
    required List<Transaction> transactions,
    required DateTime now,
  }) {
    final debits = transactions.where((t) => t.isDebit).toList();
    if (debits.length < 4) return [];

    // Compute mean and standard deviation
    final amounts = debits.map((t) => t.amount).toList();
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final variance = amounts.map((a) => pow(a - mean, 2)).reduce((a, b) => a + b) / amounts.length;
    final stdDev = sqrt(variance);

    final threshold = mean + max(stdDev * 1.6, mean * 1.5);
    final anomalies = <SpendingAnomaly>[];

    // Scan past 14 days
    final cutoff = now.subtract(const Duration(days: 14));
    for (final tx in debits) {
      if (tx.timestamp.isAfter(cutoff) && tx.amount >= threshold && tx.amount >= 1500.0) {
        final multiplier = (tx.amount / max(1.0, mean));
        anomalies.add(SpendingAnomaly(
          merchant: tx.merchant,
          amount: tx.amount,
          date: tx.timestamp,
          multiplierAboveAverage: double.parse(multiplier.toStringAsFixed(1)),
          category: tx.category,
        ));
      }
    }

    // Sort by largest anomaly amount first
    anomalies.sort((a, b) => b.amount.compareTo(a.amount));
    return anomalies.take(3).toList();
  }

  static List<SpendingLeakage> _detectMicroLeakages({
    required List<Transaction> transactions,
    required DateTime now,
  }) {
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentDebits = transactions.where((t) => t.isDebit && t.timestamp.isAfter(thirtyDaysAgo)).toList();
    if (recentDebits.isEmpty) return [];

    // Group small transactions (< ₹1,000) by category
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};

    for (final tx in recentDebits) {
      if (tx.amount <= 1000.0) {
        final cat = tx.category.isNotEmpty ? tx.category : 'General';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + tx.amount;
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
    }

    final leakages = <SpendingLeakage>[];
    for (final cat in categoryTotals.keys) {
      final count = categoryCounts[cat]!;
      final total = categoryTotals[cat]!;
      // Leakage pattern: at least 4 transactions and totaling over ₹1,200/month
      if (count >= 4 && total >= 1200.0) {
        final potentialSavings = total * 0.45; // 45% recoverable via consolidation
        leakages.add(SpendingLeakage(
          category: cat,
          transactionCount: count,
          totalAmount: total,
          potentialMonthlySavings: potentialSavings,
          diagnosticReason: '$count low-value transactions totaled ${formatCurrency(total)}. Consolidating could recover ${formatCurrency(potentialSavings)}/mo.',
        ));
      }
    }

    leakages.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return leakages.take(3).toList();
  }

  static FinancialHealthScore _calculateHealthScore({
    required CashflowMetrics cashflow,
    required TargetFeasibility feasibility,
    required List<SpendingAnomaly> anomalies,
    required List<SpendingLeakage> leakages,
  }) {
    // Pillar 1: Savings Discipline (30 points)
    int savingsScore;
    if (cashflow.savingsRate >= 35.0) {
      savingsScore = 30;
    } else if (cashflow.savingsRate >= 20.0) {
      savingsScore = 24;
    } else if (cashflow.savingsRate >= 10.0) {
      savingsScore = 18;
    } else if (cashflow.savingsRate > 0) {
      savingsScore = 12;
    } else {
      savingsScore = 5;
    }

    // Pillar 2: Target Run-Rate Velocity (30 points)
    int targetScore;
    switch (feasibility.status) {
      case TargetFeasibilityStatus.optimal:
      case TargetFeasibilityStatus.achieved:
        targetScore = 30;
        break;
      case TargetFeasibilityStatus.feasible:
        targetScore = 24;
        break;
      case TargetFeasibilityStatus.frozen:
        targetScore = 16;
        break;
      case TargetFeasibilityStatus.strained:
        targetScore = 12;
        break;
      case TargetFeasibilityStatus.atRisk:
        targetScore = 6;
        break;
    }

    // Pillar 3: Burn Rate & Anomaly Control (20 points)
    int burnScore = 20;
    burnScore -= (anomalies.length * 4);
    burnScore -= (leakages.length * 2);
    burnScore = burnScore.clamp(4, 20);

    // Pillar 4: Emergency Runway Sufficiency (20 points)
    int runwayScore;
    if (cashflow.runwayDays >= 90.0) {
      runwayScore = 20;
    } else if (cashflow.runwayDays >= 60.0) {
      runwayScore = 16;
    } else if (cashflow.runwayDays >= 30.0) {
      runwayScore = 12;
    } else if (cashflow.runwayDays >= 14.0) {
      runwayScore = 8;
    } else {
      runwayScore = 4;
    }

    final total = (savingsScore + targetScore + burnScore + runwayScore).clamp(10, 100);

    String ratingTier;
    if (total >= 85) {
      ratingTier = 'Fortress Reserve';
    } else if (total >= 70) {
      ratingTier = 'Strong Momentum';
    } else if (total >= 50) {
      ratingTier = 'Moderate Velocity';
    } else {
      ratingTier = 'Strained Runway';
    }

    return FinancialHealthScore(
      totalScore: total,
      savingsDisciplineScore: savingsScore,
      targetVelocityScore: targetScore,
      burnControlScore: burnScore,
      runwaySufficiencyScore: runwayScore,
      ratingTier: ratingTier,
    );
  }

  static List<AIRecommendation> _generateRecommendations({
    required SanchayTarget? target,
    required TargetFeasibility feasibility,
    required CashflowMetrics cashflow,
    required List<SpendingAnomaly> anomalies,
    required List<SpendingLeakage> leakages,
    required double todayPace,
    required bool isWeekend,
  }) {
    final list = <AIRecommendation>[];

    // 1. Target Run-Rate Recommendation
    if (target != null && !target.isPaused && feasibility.status != TargetFeasibilityStatus.achieved) {
      if (feasibility.status == TargetFeasibilityStatus.strained || feasibility.status == TargetFeasibilityStatus.atRisk) {
        final shortfall = formatCurrency(feasibility.dailyShortfallOrSurplus.abs());
        list.add(AIRecommendation(
          id: 'rec_pacing_shortfall',
          title: 'Calibrate Reserve Run-Rate',
          description: 'Daily quota is short by $shortfall/day against net disposable cashflow. Deposit funds or adjust target timeline.',
          type: AIRecommendationType.critical,
          impactAmount: feasibility.dailyShortfallOrSurplus.abs(),
          actionLabel: '+ Contribute Funds',
          category: 'Target Run-Rate',
          priority: 1,
        ));
      } else if (feasibility.status == TargetFeasibilityStatus.optimal) {
        final extraCapacity = formatCurrency(feasibility.dailyShortfallOrSurplus);
        list.add(AIRecommendation(
          id: 'rec_surplus_acceleration',
          title: 'Accelerate Target Completion',
          description: 'You hold $extraCapacity/day in unallocated cashflow surplus. You can achieve "${target.title}" ${feasibility.daysAheadOrBehind} days early.',
          type: AIRecommendationType.opportunity,
          impactAmount: feasibility.dailyShortfallOrSurplus,
          actionLabel: 'Boost Daily Quota',
          category: 'Target Run-Rate',
          priority: 3,
        ));
      }
    }

    // 2. Spending Leakage Intervention
    if (leakages.isNotEmpty) {
      final topLeakage = leakages.first;
      list.add(AIRecommendation(
        id: 'rec_leakage_${topLeakage.category.toLowerCase()}',
        title: 'Plug Discretionary Drain (${topLeakage.category})',
        description: '${topLeakage.transactionCount} micro-transactions drained ${formatCurrency(topLeakage.totalAmount)} this month. Reining this in recovers ${formatCurrency(topLeakage.potentialMonthlySavings)}/mo.',
        type: AIRecommendationType.warning,
        impactAmount: topLeakage.potentialMonthlySavings,
        actionLabel: 'Review Transactions',
        category: 'Spending Leakage',
        priority: 2,
      ));
    }

    // 3. High-Velocity Anomaly Intervention
    if (anomalies.isNotEmpty) {
      final topAnomaly = anomalies.first;
      list.add(AIRecommendation(
        id: 'rec_anomaly_${topAnomaly.merchant}',
        title: 'Spending Spike at ${topAnomaly.merchant}',
        description: '${formatCurrency(topAnomaly.amount)} on ${DateFormat('MMM d').format(topAnomaly.date)} was ${topAnomaly.multiplierAboveAverage}x higher than your average debit. Smooth this over the next 3 days.',
        type: AIRecommendationType.warning,
        impactAmount: topAnomaly.amount,
        actionLabel: 'Inspect Ledger',
        category: 'Cashflow',
        priority: 3,
      ));
    }

    // 4. Runway & Liquidity Buffer
    if (cashflow.runwayDays < 30.0 && cashflow.monthlyBurnRate > 0) {
      list.add(AIRecommendation(
        id: 'rec_runway_warning',
        title: 'Build Emergency Buffer',
        description: 'Current liquid runway stands at ${cashflow.runwayDays.round()} days of baseline burn. Aim for a 60-day cushion to withstand unexpected expenses.',
        type: AIRecommendationType.critical,
        impactAmount: cashflow.dailyAverageBurn * 30.0,
        actionLabel: 'Top Up Emergency',
        category: 'Runway & Buffer',
        priority: 1,
      ));
    } else if (cashflow.runwayDays >= 90.0) {
      list.add(AIRecommendation(
        id: 'rec_runway_strength',
        title: 'Safety Balance Strong',
        description: 'You maintain over ${cashflow.runwayDays.round()} days of burn rate liquidity. Your reserve resilience is top-tier.',
        type: AIRecommendationType.achievement,
        impactAmount: 0.0,
        actionLabel: 'View Vault Split',
        category: 'Runway & Buffer',
        priority: 4,
      ));
    }

    // 5. Weekend Surge Notice
    if (isWeekend) {
      list.add(AIRecommendation(
        id: 'rec_weekend_surge',
        title: 'Weekend Surge Protocol Active',
        description: 'Today’s target is adjusted to ${formatCurrency(todayPace)} to accommodate weekend lifestyle while preserving weekday velocity.',
        type: AIRecommendationType.opportunity,
        impactAmount: todayPace,
        actionLabel: 'Log Weekend Savings',
        category: 'Target Run-Rate',
        priority: 4,
      ));
    }

    // Sort by priority (1 is highest)
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }
}
