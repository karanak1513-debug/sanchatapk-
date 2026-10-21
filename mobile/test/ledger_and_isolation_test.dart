import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/models/sanchay_target.dart';
import 'package:sanchay/models/transaction.dart';
import 'package:sanchay/services/ledger_service.dart';
import 'package:sanchay/services/safe_to_spend_engine.dart';

void main() {
  group('LedgerService Outflow Isolation & Net Liquidity Tests', () {
    final List<Transaction> testTransactions = [
      Transaction(
        id: 'tx_income_1',
        merchant: 'Salary Deposit',
        amount: 50000.0,
        type: 'credit',
        category: 'Income',
        source: 'BANK',
        timestamp: DateTime.now(),
      ),
      Transaction(
        id: 'tx_expense_1',
        merchant: 'Grocery Store',
        amount: 3500.0,
        type: 'debit',
        category: 'Groceries',
        source: 'UPI',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Transaction(
        id: 'tx_expense_2',
        merchant: 'Electricity Bill',
        amount: 1500.0,
        type: 'debit',
        category: 'Utilities',
        source: 'UPI',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Transaction(
        id: 'tx_vault_deposit_1',
        merchant: 'Emergency Reserve Allocation',
        amount: 10000.0,
        type: 'vault_deposit',
        category: 'Vault Allocation',
        source: 'BANK',
        timestamp: DateTime.now(),
      ),
    ];

    test('calculateOutflowDebits excludes vault_deposit and strictly sums debits', () {
      final outflow = LedgerService.calculateOutflowDebits(testTransactions);
      // Only 3500 + 1500 = 5000; 10000 vault_deposit must NOT be counted as an outflow debit
      expect(outflow, equals(5000.0));
    });

    test('calculateInflowCredits returns true credits', () {
      final inflow = LedgerService.calculateInflowCredits(testTransactions);
      expect(inflow, equals(50000.0));
    });

    test('calculateNetCashLiquidity = Total Inflow Credits - Actual Expenses', () {
      final netLiquidity = LedgerService.calculateNetCashLiquidity(testTransactions);
      // 50000 - 5000 = 45000; vault deposit does not induce net deficit!
      expect(netLiquidity, equals(45000.0));
    });

    test('Daily Runway calculation never crashes to 0 when savings are transferred', () {
      final targets = [
        SanchayTarget(
          id: 'tgt_1',
          title: 'MacBook Reserve',
          targetCap: 100000.0,
          currentAccumulation: 25000.0,
          targetDate: DateTime.now().add(const Duration(days: 90)),
        ),
      ];

      final runwayMetrics = SafeToSpendEngine.calculate(
        transactions: testTransactions,
        targets: targets,
        currentLiquidSavings: 45000.0,
        weekendSurgeEnabled: true,
      );

      expect(runwayMetrics.todaySafeToSpend, greaterThan(0.0));
      expect(runwayMetrics.todayDailyAllowanceLimit, greaterThan(0.0));
    });
  });
}
