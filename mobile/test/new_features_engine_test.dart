import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/models/sanchay_target.dart';
import 'package:sanchay/models/transaction.dart';
import 'package:sanchay/services/file_export_service.dart';
import 'package:sanchay/services/safe_to_spend_engine.dart';
import 'package:sanchay/services/sms_upi_parser_engine.dart';

void main() {
  group('SMS / UPI Parser Engine Tests', () {
    test('Correctly disambiguates transacted amount from available balance in bank SMS', () {
      const sms =
          'Dear Customer, A/c **4128 debited for Rs. 450.00 on 12-Oct-26 by UPI to Swiggy. UPI Ref: 382910482910. Avl Bal: Rs. 24,500.50 - HDFC Bank';

      final result = SmsUpiParserEngine.parse(text: sms);

      expect(result != null, true);
      expect(result!.isValid, true);
      expect(result.amount, 450.0);
      expect(result.balanceAfter, 24500.50);
      expect(result.isDebit, true);
      expect(result.accountNumber, '4128');
      expect(result.referenceNumber, '382910482910');
      expect(result.category, 'Food & Dining');
      expect(result.source, 'HDFC Bank');
    });

    test('Correctly parses credit transaction with account and sender', () {
      const sms =
          'Your A/c *8891 has been credited by Rs. 15,000.00 on 05-Oct-26 by UPI from TechCorp Payroll. UTR 4920192837. Net Bal Rs. 85,200.00';

      final result = SmsUpiParserEngine.parse(text: sms);

      expect(result != null, true);
      expect(result!.isValid, true);
      expect(result.amount, 15000.0);
      expect(result.balanceAfter, 85200.0);
      expect(result.isDebit, false);
      expect(result.accountNumber, '8891');
      expect(result.referenceNumber, '4920192837');
      expect(result.type, anyOf('income', 'credit'));
    });

    test('Parses app notification format (e.g. Google Pay / PhonePe)', () {
      const notif = 'Paid ₹120 to Chai Point using Google Pay UPI ref 948271038102';

      final result = SmsUpiParserEngine.parse(text: notif);

      expect(result != null, true);
      expect(result!.isValid, true);
      expect(result.amount, 120.0);
      expect(result.isDebit, true);
      expect(result.channel, 'UPI');
      expect(result.category, 'Food & Dining');
    });

    test('All authentic sample presets parse into valid transactions', () {
      for (final preset in SmsUpiParserEngine.samplePresets) {
        final parsed = SmsUpiParserEngine.parse(text: preset['text']!);
        expect(parsed != null, true, reason: 'Failed parsing preset: ${preset['name']}');
        expect(parsed!.isValid, true, reason: 'Preset should be valid: ${preset['name']}');
        expect(parsed.amount, greaterThan(0), reason: 'Amount should be positive in ${preset['name']}');
        expect(parsed.merchant.isNotEmpty, true, reason: 'Merchant should be detected in ${preset['name']}');
      }
    });

    test('Correctly maps merchants to intelligent categories via parsed text', () {
      expect(
        SmsUpiParserEngine.parse(text: 'Paid Rs. 345 to Uber India via UPI Ref 1234')?.category,
        'Transit',
      );
      expect(
        SmsUpiParserEngine.parse(text: 'Debited Rs. 5000 for Zerodha Broking UPI Ref 5678')?.category,
        'Investment',
      );
      expect(
        SmsUpiParserEngine.parse(text: 'Paid Rs. 649 to Netflix Entertainment via Card')?.category,
        'Entertainment',
      );
      expect(
        SmsUpiParserEngine.parse(text: 'Paid Rs. 1450 to Tata Power Bill online')?.category,
        'Bills & Utilities',
      );
      expect(
        SmsUpiParserEngine.parse(text: 'Paid Rs. 290 to Apollo Pharmacy via PhonePe')?.category,
        'Healthcare',
      );
    });
  });

  group('Dynamic Safe-to-Spend Daily Allowance Engine Tests', () {
    test('Computes discretionary surplus after accounting for vaults and commitments', () {
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 90));

      final vaults = [
        SanchayTarget(
          id: 'v1',
          title: 'Emergency Vault',
          targetCap: 100000,
          currentAccumulation: 20000,
          targetDate: targetDate,
        ),
        SanchayTarget(
          id: 'v2',
          title: 'Japan Travel',
          targetCap: 60000,
          currentAccumulation: 10000,
          targetDate: targetDate,
        ),
      ];

      final transactions = [
        Transaction(
          id: 't_sal',
          amount: 80000.0,
          type: 'credit',
          merchant: 'Direct Salary',
          source: 'BANK',
          category: 'Salary',
          timestamp: now.subtract(const Duration(days: 5)),
        ),
        Transaction(
          id: 't_rent',
          amount: 25000.0,
          type: 'debit',
          merchant: 'Rent Transfer',
          source: 'UPI',
          category: 'Bills & Utilities',
          timestamp: now.subtract(const Duration(days: 4)),
        ),
        Transaction(
          id: 't_spend',
          amount: 450.0,
          type: 'debit',
          merchant: 'Dinner',
          source: 'UPI',
          category: 'Food & Dining',
          timestamp: now,
        ),
      ];

      final allowance = SafeToSpendEngine.calculate(
        transactions: transactions,
        targets: vaults,
        currentLiquidSavings: 50000,
        weekendSurgeEnabled: false,
      );

      expect(allowance.monthlyInflow, 80000.0);
      expect(allowance.monthToDateDebits, 25450.0);
      expect(allowance.totalMonthlySavingsGoal, greaterThan(0));
      expect(allowance.todayDailyAllowanceLimit, greaterThan(0));
      expect(allowance.todaySafeToSpend, greaterThan(0));
      expect(allowance.remainingDaysInMonth, greaterThanOrEqualTo(1));
    });

    test('Simulates expense impact on safe to spend and goal delay', () {
      final now = DateTime.now();
      final vaults = [
        SanchayTarget(
          id: 'v1',
          title: 'Emergency Fund',
          targetCap: 50000,
          currentAccumulation: 10000,
          targetDate: now.add(const Duration(days: 60)),
        ),
      ];

      final transactions = [
        Transaction(
          id: 't_sal',
          amount: 60000.0,
          type: 'credit',
          merchant: 'Salary',
          source: 'BANK',
          category: 'Salary',
          timestamp: now,
        ),
      ];

      final allowance = SafeToSpendEngine.calculate(
        transactions: transactions,
        targets: vaults,
        currentLiquidSavings: 40000,
      );

      final sim = SafeToSpendEngine.simulateExpenseImpact(allowance, 3000);
      expect(sim.simulatedSafeToday, lessThan(allowance.todaySafeToSpend));
      expect(sim.simulatedRemainingPool, allowance.remainingDiscretionaryPool - 3000);
    });
  });

  group('Genuine File Export Service Tests', () {
    test('Generates valid RFC 4180 escaped CSV for ledger transactions', () {
      final transactions = [
        Transaction(
          id: 'tx_1',
          amount: 1250.50,
          type: 'debit',
          merchant: 'Bookstore, "Main St"',
          source: 'UPI',
          category: 'Lifestyle',
          timestamp: DateTime(2026, 10, 1, 14, 30),
          accountNumber: '4128',
          referenceNumber: 'REF123456',
          balanceAfter: 45000.0,
        ),
        Transaction(
          id: 'tx_2',
          amount: 50000.0,
          type: 'credit',
          merchant: 'Direct Salary Inflow',
          source: 'BANK',
          category: 'Direct Inflow',
          timestamp: DateTime(2026, 10, 2, 9, 0),
        ),
      ];

      final csv = FileExportService.generateLedgerCsv(
        transactions: transactions,
        userEmail: 'karan@sanchay.app',
      );

      expect(csv.contains('Transaction ID,Date,Time,Merchant,Type,Direction,Amount'), true);
      expect(csv.contains('Bookstore, ""Main St""'), true); // Escaped quotes and commas
      expect(csv.contains('REF123456'), true);
      expect(csv.contains('4128'), true);
      expect(csv.contains('45000.00'), true);
      expect(csv.contains('karan@sanchay.app'), true);
    });

    test('Generates RFC 4180 CSV for multi-vault targets', () {
      final vaults = [
        SanchayTarget(
          id: 'v_car',
          title: 'EV Car Fund',
          targetCap: 1500000,
          currentAccumulation: 450000,
          targetDate: DateTime(2027, 12, 31),
          category: 'Vehicle',
          isPrimary: true,
        ),
      ];

      final csv = FileExportService.generateVaultsCsv(targets: vaults);

      expect(csv.contains('Vault ID,Vault Name,Category,Target Cap (INR)'), true);
      expect(csv.contains('EV Car Fund'), true);
      expect(csv.contains('Vehicle'), true);
      expect(csv.contains('1500000.0'), true);
      expect(csv.contains('TRUE'), true);
    });

    test('Generates complete Schema v2.0 JSON backup', () {
      final transactions = [
        Transaction(
          id: 'tx_test',
          amount: 100.0,
          type: 'debit',
          merchant: 'Coffee Shop',
          source: 'CASH',
          category: 'Food & Dining',
          timestamp: DateTime(2026, 10, 5),
        ),
      ];
      final vaults = [
        SanchayTarget(
          id: 'v_test',
          title: 'Test Vault',
          targetCap: 10000,
          currentAccumulation: 2000,
          targetDate: DateTime(2026, 12, 31),
        ),
      ];

      final jsonStr = FileExportService.generateStateBackupJson(
        transactions: transactions,
        targets: vaults,
        userName: 'Karan Sanchay',
        userEmail: 'karan@sanchay.app',
        currentSavings: 50000,
      );

      expect(jsonStr.contains('"export_version": "2.0.0"'), true);
      expect(jsonStr.contains('"app_name": "Sanchay Wealth"'), true);
      expect(jsonStr.contains('"transaction_count": 1'), true);
      expect(jsonStr.contains('Coffee Shop'), true);
      expect(jsonStr.contains('Test Vault'), true);
    });
  });
}
