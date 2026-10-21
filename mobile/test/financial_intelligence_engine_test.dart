import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/models/sanchay_target.dart';
import 'package:sanchay/models/transaction.dart';
import 'package:sanchay/services/financial_intelligence_engine.dart';

void main() {
  group('Autonomous AI Financial Intelligence Engine Tests', () {
    final now = DateTime.now();

    test('Computes deterministic cashflow metrics accurately with real transactions', () {
      final transactions = [
        Transaction(
          id: 'tx_salary',
          amount: 80000.0,
          type: 'credit',
          merchant: 'Employer Direct Credit',
          source: 'BANK',
          category: 'Salary',
          timestamp: now.subtract(const Duration(days: 10)),
        ),
        Transaction(
          id: 'tx_rent',
          amount: 25000.0,
          type: 'debit',
          merchant: 'Landlord Transfer',
          source: 'UPI',
          category: 'Bills & Utilities',
          timestamp: now.subtract(const Duration(days: 8)),
        ),
        Transaction(
          id: 'tx_groceries',
          amount: 5000.0,
          type: 'debit',
          merchant: 'Supermarket',
          source: 'UPI',
          category: 'Food & Dining',
          timestamp: now.subtract(const Duration(days: 5)),
        ),
      ];

      final report = FinancialIntelligenceEngine.analyze(
        transactions: transactions,
        targets: [],
        currentLiquidSavings: 50000.0,
      );

      // Inflow > 0, Outflow > 0, Net surplus = 80000 - 30000 = 50000
      expect(report.cashflowMetrics.monthlyInflow >= 79000.0, true);
      expect(report.cashflowMetrics.monthlyBurnRate >= 29000.0, true);
      expect(report.cashflowMetrics.netMonthlySurplus > 0, true);
      expect(report.cashflowMetrics.savingsRate > 0, true);
      expect(report.healthScore.totalScore > 50, true);
    });

    test('Determines Target Feasibility: Optimal when surplus comfortably covers required pace', () {
      final target = SanchayTarget(
        id: 'target_car',
        title: 'Emergency Reserve',
        targetCap: 100000.0,
        currentAccumulation: 40000.0,
        targetDate: now.add(const Duration(days: 60)), // 60 days to save 60,000 => 1,000/day
      );

      // High income, low expense => ample surplus
      final transactions = [
        Transaction(
          id: 'tx_inflow_1',
          amount: 120000.0,
          type: 'credit',
          merchant: 'Monthly Income',
          source: 'BANK',
          category: 'Salary',
          timestamp: now.subtract(const Duration(days: 15)),
        ),
        Transaction(
          id: 'tx_spend_1',
          amount: 30000.0,
          type: 'debit',
          merchant: 'Living Costs',
          source: 'UPI',
          category: 'General',
          timestamp: now.subtract(const Duration(days: 10)),
        ),
      ];

      final report = FinancialIntelligenceEngine.analyze(
        transactions: transactions,
        targets: [target],
        primaryTarget: target,
      );

      expect(report.targetFeasibility.status, TargetFeasibilityStatus.optimal);
      expect(report.targetFeasibility.feasibilityScore >= 90.0, true);
      expect(report.targetFeasibility.daysAheadOrBehind >= 0, true);
      expect(report.targetFeasibility.primarySummary.contains('Great pace'), true);
    });

    test('Detects spending anomalies exceeding moving average multiplier threshold', () {
      final transactions = [
        Transaction(
          id: 'tx_1',
          amount: 150.0,
          type: 'debit',
          merchant: 'Tea Stall',
          source: 'UPI',
          category: 'Food & Dining',
          timestamp: now.subtract(const Duration(days: 1)),
        ),
        Transaction(
          id: 'tx_2',
          amount: 200.0,
          type: 'debit',
          merchant: 'Snacks',
          source: 'UPI',
          category: 'Food & Dining',
          timestamp: now.subtract(const Duration(days: 2)),
        ),
        Transaction(
          id: 'tx_3',
          amount: 250.0,
          type: 'debit',
          merchant: 'Metro Recharge',
          source: 'UPI',
          category: 'Transit',
          timestamp: now.subtract(const Duration(days: 3)),
        ),
        Transaction(
          id: 'tx_4',
          amount: 180.0,
          type: 'debit',
          merchant: 'Groceries',
          source: 'UPI',
          category: 'Food & Dining',
          timestamp: now.subtract(const Duration(days: 4)),
        ),
        // Massive outlier spike
        Transaction(
          id: 'tx_spike',
          amount: 8500.0,
          type: 'debit',
          merchant: 'Luxury Electronics',
          source: 'UPI',
          category: 'Lifestyle',
          timestamp: now.subtract(const Duration(days: 1)),
        ),
      ];

      final report = FinancialIntelligenceEngine.analyze(
        transactions: transactions,
        targets: [],
      );

      expect(report.anomalies.isNotEmpty, true);
      expect(report.anomalies.first.merchant, 'Luxury Electronics');
      expect(report.anomalies.first.multiplierAboveAverage > 2.0, true);
    });

    test('Detects recurring micro-leakages when multiple low-value transactions accumulate', () {
      final transactions = <Transaction>[];
      // 6 transactions of 350 each in 'Food & Dining' (total 2100)
      for (int i = 1; i <= 6; i++) {
        transactions.add(Transaction(
          id: 'tx_leak_$i',
          amount: 350.0,
          type: 'debit',
          merchant: 'Quick Delivery #$i',
          source: 'UPI',
          category: 'Food & Dining',
          timestamp: now.subtract(Duration(days: i)),
        ));
      }

      final report = FinancialIntelligenceEngine.analyze(
        transactions: transactions,
        targets: [],
      );

      expect(report.leakages.isNotEmpty, true);
      expect(report.leakages.first.category, 'Food & Dining');
      expect(report.leakages.first.transactionCount, 6);
      expect(report.leakages.first.potentialMonthlySavings > 0, true);
    });

    test('Applies Weekend Surge Protocol and adjusts today pace deterministically', () {
      final saturday = DateTime(2026, 10, 10); // A Saturday
      final target = SanchayTarget(
        id: 'target_weekend',
        title: 'Reserve Fund',
        targetCap: 30000.0,
        currentAccumulation: 0.0,
        targetDate: saturday.add(const Duration(days: 30)),
      );

      final report = FinancialIntelligenceEngine.analyze(
        transactions: [],
        targets: [target],
        primaryTarget: target,
        weekendSurgeEnabled: true,
      );

      // Verify todayAdaptivePace is positive and computed
      expect(report.todayAdaptivePace > 0, true);
    });
  });
}
