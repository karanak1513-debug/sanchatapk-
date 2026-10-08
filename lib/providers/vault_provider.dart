import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_item.dart';
import '../models/vault_target.dart';

class VaultProvider extends ChangeNotifier {
  // 1. Privacy Masking
  bool _isPrivacyMasked = false;
  bool get isPrivacyMasked => _isPrivacyMasked;

  void togglePrivacyMask() {
    _isPrivacyMasked = !_isPrivacyMasked;
    notifyListeners();
  }

  // Helper method to format money honoring privacy mask
  String formatCurrency(num amount, {bool isSigned = false, bool isDebit = false}) {
    if (_isPrivacyMasked) {
      return '••••••';
    }
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final formatted = formatter.format(amount.abs());
    if (isSigned) {
      return isDebit ? '-$formatted' : '+$formatted';
    }
    return formatted;
  }

  // 2. Active Tab & Filter
  String _activeFilter = 'all'; // 'all', 'debit', 'credit'
  String get activeFilter => _activeFilter;

  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  // 3. Transactions Stream
  List<TransactionItem> _transactions = [];

  List<TransactionItem> get allTransactions => List.unmodifiable(_transactions);

  List<TransactionItem> get filteredTransactions {
    if (_activeFilter == 'debit') {
      return _transactions.where((t) => t.isDebit).toList();
    } else if (_activeFilter == 'credit') {
      return _transactions.where((t) => t.isCredit).toList();
    } else if (_activeFilter == 'auto_upi') {
      return _transactions
          .where((t) => t.channel.toUpperCase() == 'UPI' || t.tag.toLowerCase().contains('auto'))
          .toList();
    } else if (_activeFilter == 'manual') {
      return _transactions
          .where((t) =>
              t.channel.toUpperCase() == 'VAULT_MANUAL' ||
              t.channel.toUpperCase() == 'MANUAL' ||
              !t.tag.toLowerCase().contains('auto'))
          .toList();
    }
    return List.unmodifiable(_transactions);
  }

  double get totalDebits =>
      _transactions.where((t) => t.isDebit && !t.isVaultDeposit && t.type.toLowerCase() != 'vault_deposit').fold(0.0, (acc, t) => acc + t.amount);

  double get totalCredits =>
      _transactions.where((t) => t.isCredit).fold(0.0, (acc, t) => acc + t.amount);

  void addTransaction(TransactionItem item) {
    _transactions.insert(0, item);
    notifyListeners();
  }

  TransactionItem? deleteTransaction(String id) {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      final removed = _transactions.removeAt(index);
      notifyListeners();
      return removed;
    }
    return null;
  }

  void restoreTransaction(TransactionItem item, [int? index]) {
    if (index != null && index >= 0 && index <= _transactions.length) {
      _transactions.insert(index, item);
    } else {
      _transactions.insert(0, item);
    }
    notifyListeners();
  }

  void purgeTransactions() {
    _transactions.clear();
    notifyListeners();
  }

  // 4. Primary Vault Target & Cockpit
  double _currentVault = 0.0;
  double _goalCap = 100000.0;

  double get currentVault => _currentVault;
  double get goalCap => _goalCap;
  double get vaultProgress => _goalCap <= 0 ? 0.0 : (_currentVault / _goalCap).clamp(0.0, 1.0);
  int get vaultPercentage => (vaultProgress * 100).round();
  double get amountToTarget => (_goalCap - _currentVault).clamp(0.0, _goalCap);

  // Daily, Weekly, Monthly Pacing
  double get dailyPace => 1851.0;
  double get weeklyPace => 12962.0;
  double get monthlyPace => 55555.0;

  void updateGoalCap(double newCap) {
    _goalCap = newCap;
    notifyListeners();
  }

  void updateCurrentVault(double newAmount) {
    _currentVault = newAmount;
    notifyListeners();
  }

  // 5. Tactical Liquidity Balances
  double upiBalance = 0.0;
  double liquidVaultBalance = 0.0;
  double emergencyBalance = 0.0;

  // 6. Sub Targets
  List<VaultTarget> targets = [];

  void addTarget(VaultTarget target) {
    targets.add(target);
    notifyListeners();
  }

  void updateTarget(VaultTarget updated) {
    final idx = targets.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      targets[idx] = updated;
      notifyListeners();
    }
  }

  // 7. System Preferences & Settings
  String userName = '';
  String userEmail = '';
  bool isProVault = true;
  bool isCloudConnected = true;

  bool biometricLock = false;
  bool upiInterceptor = true;
  bool notificationAccess = true;
  bool clipboardAutoParse = false;
  bool dailyReminder = true;
  TimeOfDay reminderTime = const TimeOfDay(hour: 21, minute: 0);
  bool monthlySummary = true;
  bool adaptiveDailyPace = true;
  bool weekendSurge = true;
  String categorizerMode = 'Contextual AI'; // 'Strict Rules' or 'Contextual AI'
  DateTime lastSyncedTime = DateTime.now().subtract(const Duration(minutes: 2));

  void toggleBiometricLock() {
    biometricLock = !biometricLock;
    notifyListeners();
  }

  void toggleUpiInterceptor() {
    upiInterceptor = !upiInterceptor;
    notifyListeners();
  }

  void toggleClipboardAutoParse() {
    clipboardAutoParse = !clipboardAutoParse;
    notifyListeners();
  }

  void toggleDailyReminder() {
    dailyReminder = !dailyReminder;
    notifyListeners();
  }

  void setReminderTime(TimeOfDay newTime) {
    reminderTime = newTime;
    notifyListeners();
  }

  void toggleMonthlySummary() {
    monthlySummary = !monthlySummary;
    notifyListeners();
  }

  void toggleAdaptiveDailyPace() {
    adaptiveDailyPace = !adaptiveDailyPace;
    notifyListeners();
  }

  void toggleWeekendSurge() {
    weekendSurge = !weekendSurge;
    notifyListeners();
  }

  void setCategorizerMode(String mode) {
    categorizerMode = mode;
    notifyListeners();
  }

  bool isSyncing = false;
  Future<void> forceCloudSync() async {
    isSyncing = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));
    lastSyncedTime = DateTime.now();
    isSyncing = false;
    notifyListeners();
  }

  // Export JSON string
  String exportJson() {
    final data = {
      'exported_at': DateTime.now().toIso8601String(),
      'version': '1.0.0',
      'user': {
        'name': userName,
        'email': userEmail,
      },
      'vault': {
        'current_vault': _currentVault,
        'goal_cap': _goalCap,
        'upi_balance': upiBalance,
        'liquid_vault': liquidVaultBalance,
        'emergency_balance': emergencyBalance,
      },
      'transactions': _transactions.map((t) => t.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // Import JSON string
  bool importJson(String jsonStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data.containsKey('transactions')) {
        final List txList = data['transactions'] as List;
        _transactions = txList.map((x) => TransactionItem.fromJson(x as Map<String, dynamic>)).toList();
      }
      if (data.containsKey('vault')) {
        final vaultMap = data['vault'] as Map<String, dynamic>;
        if (vaultMap['current_vault'] != null) {
          _currentVault = (vaultMap['current_vault'] as num).toDouble();
        }
        if (vaultMap['goal_cap'] != null) {
          _goalCap = (vaultMap['goal_cap'] as num).toDouble();
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
