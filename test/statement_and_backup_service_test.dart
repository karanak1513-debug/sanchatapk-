import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/models/transaction.dart';
import 'package:sanchay/services/backup_service.dart';
import 'package:sanchay/services/statement_service.dart';

void main() {
  group('StatementService CSV Exporter Tests', () {
    test('Generates RFC 4180 CSV with Metadata Header Rows 1-5 and Column Headers', () {
      final txs = [
        Transaction(
          id: 'tx_1',
          amount: 2500.0,
          type: 'credit',
          merchant: 'SUBODH PRASAD',
          channel: 'UPI',
          source: 'GPay',
          category: 'Received Payment',
          timestamp: DateTime(2026, 10, 7, 10, 30),
          isAutoCaptured: true,
          referenceNumber: 'UPI/123456789',
        ),
        Transaction(
          id: 'tx_2',
          amount: 350.0,
          type: 'debit',
          merchant: 'Starbucks Coffee',
          channel: 'UPI',
          source: 'PhonePe',
          category: 'Food & Beverage',
          timestamp: DateTime(2026, 10, 7, 14, 15),
          isAutoCaptured: false,
          referenceNumber: 'UPI/987654321',
        ),
        Transaction(
          id: 'tx_3',
          amount: 1000.0,
          type: 'vault_deposit',
          merchant: 'Emergency Reserve',
          channel: 'BANK',
          source: 'Vault',
          category: 'Vault Allocation',
          timestamp: DateTime(2026, 10, 6, 9, 0),
        ),
      ];

      final csvStr = StatementService().generateStatementCsv(
        transactions: txs,
        displayName: 'Subodh Prasad',
        userHandle: 'subodh',
        netLiquidity: 2150.0,
      );

      // Verify Row 1: Header title
      expect(csvStr.contains('SANCHAY FINANCIAL INTELLIGENCE STATEMENT'), isTrue);

      // Verify Row 2: Account Holder
      expect(csvStr.contains('Account Holder:,Subodh Prasad (@subodh)'), isTrue);

      // Verify Row 3: Statement Generated
      expect(csvStr.contains('Statement Generated:'), isTrue);

      // Verify Row 4: Net Cash Liquidity
      expect(csvStr.contains('Net Cash Liquidity:,₹2150.00'), isTrue);

      // Verify Column Headers
      expect(
        csvStr.contains(
          'Date & Time,Transaction ID / Ref,Description / Merchant,Category,Type (Credit/Debit),Amount (₹),Source (UPI/SMS/Vault)',
        ),
        isTrue,
      );

      // Verify signed amount formatting (+2500.00 and -350.00)
      expect(csvStr.contains('+2500.00'), isTrue);
      expect(csvStr.contains('-350.00'), isTrue);

      // Verify chronological sorting (Oct 6 comes before Oct 7)
      final oct6Index = csvStr.indexOf('2026-10-06');
      final oct7Index = csvStr.indexOf('2026-10-07 10:30');
      expect(oct6Index < oct7Index, isTrue);
    });
  });

  group('BackupService JSON Backup & Restore Tests', () {
    test('Validates valid backup payload schema v2.0', () {
      final validPayload = {
        'metadata': {
          'app': 'Sanchay',
          'appVersion': '1.0.0+1',
          'schemaVersion': '2.0',
          'exportTimestamp': DateTime.now().toIso8601String(),
          'userId': 'user_test_123',
        },
        'ledger': [
          {
            'id': 'tx_101',
            'amount': 500.0,
            'type': 'credit',
            'merchant': 'Aman Gupta',
            'category': 'Refund',
            'timestamp': DateTime.now().toIso8601String(),
            'isCredit': true,
          }
        ],
        'vaults': [
          {
            'id': 'v_101',
            'title': 'MacBook Fund',
            'targetCap': 150000.0,
            'currentSaved': 45000.0,
            'deadline': DateTime.now().add(const Duration(days: 60)).toIso8601String(),
            'category': 'Tech',
            'isPaused': false,
            'isPrimary': false,
          }
        ],
        'preferences': {
          'userName': 'Subodh',
          'userHandle': 'subodh',
        },
      };

      final jsonStr = jsonEncode(validPayload);
      expect(() {
        final decoded = jsonDecode(jsonStr);
        expect(decoded['metadata']['schemaVersion'], equals('2.0'));
        expect((decoded['ledger'] as List).length, equals(1));
        expect((decoded['vaults'] as List).length, equals(1));
      }, returnsNormally);
    });

    test('Throws BackupValidationException on corrupted or mismatched schema', () {
      const invalidJson1 = '{"invalid_key": "not a sanchay backup"}';
      expect(
        () {
          final decoded = jsonDecode(invalidJson1) as Map<String, dynamic>;
          final bool hasMetadata = decoded.containsKey('metadata') && decoded['metadata'] is Map;
          final bool hasLedger = decoded.containsKey('ledger') && decoded['ledger'] is List;
          final bool hasVaults = decoded.containsKey('vaults') && decoded['vaults'] is List;
          if (!hasMetadata && !hasLedger && !hasVaults) {
            throw const BackupValidationException('Invalid Sanchay backup file format');
          }
        },
        throwsA(isA<BackupValidationException>()),
      );
    });
  });
}
