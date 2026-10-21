import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/models/transaction_item.dart';
import 'package:sanchay/providers/vault_provider.dart';

void main() {
  group('VaultProvider Unit Tests', () {
    late VaultProvider provider;

    setUp(() {
      provider = VaultProvider();
    });

    test('Initial state matches design specification', () {
      expect(provider.goalCap, 100000.0);
      expect(provider.isPrivacyMasked, false);
      expect(provider.activeFilter, 'all');
      expect(provider.upiInterceptor, true);
      expect(provider.biometricLock, false);
      expect(provider.reminderTime, const TimeOfDay(hour: 21, minute: 0));
    });

    test('Privacy mask blurs monetary values to bullet points', () {
      expect(provider.formatCurrency(42850), '₹42,850');
      provider.togglePrivacyMask();
      expect(provider.isPrivacyMasked, true);
      expect(provider.formatCurrency(42850), '••••••');
      provider.togglePrivacyMask();
      expect(provider.isPrivacyMasked, false);
      expect(provider.formatCurrency(42850), '₹42,850');
    });

    test('Adding and deleting transactions updates list reactively', () {
      final newTx = TransactionItem(
        id: 'tx_test_99',
        title: 'Starbucks Coffee',
        amount: 350.0,
        type: 'debit',
        channel: 'PhonePe',
        category: 'Food & Dining',
        tag: 'Auto-Intercepted',
        timestamp: DateTime.now(),
      );

      provider.addTransaction(newTx);
      expect(provider.allTransactions.first.title, 'Starbucks Coffee');
      expect(provider.allTransactions.length, 1);

      final removed = provider.deleteTransaction('tx_test_99');
      expect(removed?.title, 'Starbucks Coffee');
      expect(provider.allTransactions.isEmpty, true);

      provider.restoreTransaction(removed!, 0);
      expect(provider.allTransactions.first.title, 'Starbucks Coffee');
      expect(provider.allTransactions.length, 1);
    });

    test('Filtering transactions dynamically filters by debit and credit', () {
      provider.addTransaction(TransactionItem(
        id: 'tx_1',
        title: 'Debit Tx',
        amount: 200.0,
        type: 'debit',
        channel: 'UPI',
        category: 'Food',
        tag: 'Manual',
        timestamp: DateTime.now(),
      ));
      provider.addTransaction(TransactionItem(
        id: 'tx_2',
        title: 'Credit Tx',
        amount: 5000.0,
        type: 'credit',
        channel: 'UPI',
        category: 'Salary',
        tag: 'Manual',
        timestamp: DateTime.now(),
      ));

      provider.setFilter('debit');
      expect(provider.filteredTransactions.every((t) => t.isDebit), true);
      expect(provider.filteredTransactions.length, 1);

      provider.setFilter('credit');
      expect(provider.filteredTransactions.every((t) => t.isCredit), true);
      expect(provider.filteredTransactions.length, 1);

      provider.setFilter('all');
      expect(provider.filteredTransactions.length, 2);
    });

    test('Purge clears transaction stream', () {
      provider.purgeTransactions();
      expect(provider.allTransactions.isEmpty, true);
      expect(provider.totalDebits, 0.0);
      expect(provider.totalCredits, 0.0);
    });

    test('Pacing and goal cap calculations', () {
      provider.updateGoalCap(200000.0);
      expect(provider.goalCap, 200000.0);
      expect(provider.amountToTarget, 200000.0);

      provider.updateCurrentVault(50000.0);
      expect(provider.vaultPercentage, 25);
      expect(provider.amountToTarget, 150000.0);
    });
  });
}
