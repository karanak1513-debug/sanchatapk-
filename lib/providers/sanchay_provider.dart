import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sanchay_target.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/clipboard_parser_service.dart';
import '../services/file_export_service.dart';
import '../services/financial_intelligence_engine.dart';
import '../services/firestore_service.dart';
import '../services/notification_bridge.dart';
import '../services/notification_service.dart';
import '../services/safe_to_spend_engine.dart';
import '../services/ledger_service.dart';
import '../services/sms_upi_parser_engine.dart';
import '../services/backup_service.dart';

class SanchayProvider extends ChangeNotifier {
  // SharedPreferences Keys (Local Cache)
  static const String _prefPrivacyKey = 'sanchay_privacy_mode';
  static const String _prefSettingsKey = 'sanchay_user_settings';
  static const String _prefGoalCapKey = 'sanchay_goal_cap';
  static const String _prefTargetNameKey = 'sanchay_target_name';
  static const String _prefTargetDateKey = 'sanchay_target_date';
  static const String _prefTargetPausedKey = 'sanchay_target_paused';
  static const String _prefUserAvatarKey = 'sanchay_user_avatar';

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final NotificationBridge _notificationBridge = NotificationBridge();

  // 1. Live State strictly bound to Firestore
  List<Transaction> _transactions = [];
  List<SanchayTarget> _targets = [];
  bool _isLoading = true;
  String _activeFilter = 'all'; // 'all', 'debit', 'credit'
  bool _isPrivacyMasked = false;
  String _currentUserId = '';

  // Stream Subscriptions
  StreamSubscription<List<Transaction>>? _transactionsSubscription;
  StreamSubscription<List<SanchayTarget>>? _targetsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _metaSubscription;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<Transaction>? _notificationSubscription;

  // Deduplication cache for incoming native notifications
  final Set<String> _recentDedupeKeys = {};

  // 2. Financial Metrics & Goal Engine State (Synchronized to users/{userId}/targets)
  double _goalCap = 100000.0;
  String _targetName = 'Master Vault Reserve';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 45));
  bool _isTargetPaused = false;
  String _userAvatarUrl = '';
  String _userHandle = '';

  // System Preferences (Synchronized to users/{userId}/profile/settings)
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
  String categorizerMode = 'Contextual AI';
  DateTime lastSyncedTime = DateTime.now();
  bool isSyncing = false;

  bool _isNotificationPermissionGranted = true;

  // =========================================================================
  // Getters
  // =========================================================================
  bool get isLoading => _isLoading;
  bool get isPrivacyMasked => _isPrivacyMasked;
  String get activeFilter => _activeFilter;
  String get currentUserId => _currentUserId;
  bool get isNotificationPermissionGranted => _isNotificationPermissionGranted;

  String get userAvatarUrl => _userAvatarUrl;

  String get userHandle {
    if (_userHandle.isNotEmpty) return _userHandle;
    final name = userName.trim().toLowerCase();
    if (name.isNotEmpty && name != 'user') {
      final clean = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (clean.isNotEmpty) return clean;
    }
    final email = userEmail.trim().toLowerCase();
    if (email.isNotEmpty && email.contains('@')) {
      final clean = email.split('@').first.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (clean.isNotEmpty) return clean;
    }
    return 'user';
  }

  void updateHandle(String newHandle) {
    final clean = newHandle.trim().toLowerCase().replaceAll('@', '');
    _userHandle = clean;
    userName = clean;
    _saveLocalPrefs();
    notifyListeners();
  }

  String get userInitials {
    final name = userName.trim();
    if (name.isNotEmpty && name.toLowerCase() != 'user') {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length > 1 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    final email = userEmail.trim();
    if (email.isNotEmpty && email != 'No email associated') {
      return email[0].toUpperCase();
    }
    return 'U';
  }

  // Multi-Vault Selection & Primary Vault Getters
  String? _selectedVaultId;
  String? get selectedVaultId => _selectedVaultId;

  void selectVault(String? vaultId) {
    _selectedVaultId = vaultId;
    notifyListeners();
  }

  SanchayTarget? get primaryTarget {
    if (_targets.isEmpty) return null;
    return _targets.firstWhere((t) => t.isPrimary, orElse: () => _targets.first);
  }

  SanchayTarget? get selectedVault {
    if (_targets.isEmpty) return null;
    if (_selectedVaultId != null) {
      return _targets.firstWhere(
        (t) => t.id == _selectedVaultId,
        orElse: () => primaryTarget ?? _targets.first,
      );
    }
    return primaryTarget ?? _targets.first;
  }

  String? get primaryTargetId => primaryTarget?.id;
  List<SanchayTarget> get targets => List.unmodifiable(_targets);
  List<SanchayTarget> get allTargets => targets;

  String get targetName => (selectedVault ?? primaryTarget)?.title ?? _targetName;
  double get goalCap => (selectedVault ?? primaryTarget)?.targetCap ?? _goalCap;
  DateTime get targetDate => (selectedVault ?? primaryTarget)?.targetDate ?? _targetDate;
  bool get isTargetPaused => (selectedVault ?? primaryTarget)?.isPaused ?? _isTargetPaused;

  // Dynamic Safe-to-Spend Daily Allowance Engine
  SafeToSpendMetrics get safeToSpend => SafeToSpendEngine.calculate(
    transactions: _transactions,
    targets: _targets,
    currentLiquidSavings: currentSavings,
    weekendSurgeEnabled: weekendSurge,
  );

  double get safeToSpendToday => safeToSpend.todaySafeToSpend;
  double get safeToSpendDailyLimit => safeToSpend.todayDailyAllowanceLimit;
  double get safeToSpendSpentToday => safeToSpend.todayDebits;
  SafeToSpendStatus get safeToSpendStatus => safeToSpend.status;
  String get safeToSpendHeadline => safeToSpend.statusHeadline;
  String get safeToSpendAdvice => safeToSpend.statusAdvice;
  int get safeToSpendProgressPercent => safeToSpend.progressPercent;
  bool get isSafeToSpendOverspent => safeToSpend.isOverspent;
  double get safeToSpendOverspentAmount => safeToSpend.todayOverspend;

  List<Transaction> get allTransactions => List.unmodifiable(_transactions);
  List<Transaction> get transactions => allTransactions;

  List<Transaction> get filteredTransactions {
    if (_activeFilter == 'debit') {
      return _transactions.where((t) => t.isDebit).toList();
    } else if (_activeFilter == 'credit') {
      return _transactions.where((t) => t.isCredit).toList();
    }
    return List.unmodifiable(_transactions);
  }

  // Dynamic Real-Time Calculations derived strictly from live Firestore snapshots
  double get totalDebits =>
      LedgerService.calculateOutflowDebits(_transactions);

  double get totalCredits =>
      LedgerService.calculateInflowCredits(_transactions);

  // savedAmount / Net Cash Liquidity = Total Inflow Credits - Actual Expenses
  double get savedAmount => LedgerService.calculateNetCashLiquidity(_transactions);
  double get netSavings => savedAmount;
  double get currentSavings => savedAmount > 0 ? savedAmount : 0.0;
  double get currentVault => currentSavings;

  double get vaultProgress =>
      goalCap <= 0 ? 0.0 : (currentSavings / goalCap).clamp(0.0, 1.0);
  int get vaultPercentage => (vaultProgress * 100).round();
  double get amountToTarget => (goalCap - currentSavings).clamp(0.0, goalCap);

  int get remainingDaysToTarget {
    if (primaryTarget != null) return primaryTarget!.remainingDays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diff = target.difference(today).inDays;
    return diff > 0 ? diff : 1;
  }

  int get remainingDaysInMonth => remainingDaysToTarget;

  // Dynamic Run-Rate Engine:
  // Remaining Amount = targetCap - currentAccumulation
  // Daily Pace = (targetCap - currentAccumulation) / remainingDays
  // Weekly Pace = Daily Pace * 7
  // Monthly Pace = Daily Pace * 30
  double get dailyPace {
    if (isTargetPaused) return 0.0;
    final effectiveSaved = (primaryTarget != null && primaryTarget!.currentAccumulation > currentSavings)
        ? primaryTarget!.currentAccumulation
        : currentSavings;
    final rem = (goalCap - effectiveSaved).clamp(0.0, goalCap);
    if (rem <= 0) return 0.0;
    return rem / remainingDaysToTarget;
  }

  double get weeklyPace => isTargetPaused ? 0.0 : dailyPace * 7.0;
  double get monthlyPace => isTargetPaused ? 0.0 : dailyPace * 30.0;

  // =========================================================================
  // Autonomous On-Device AI Financial Intelligence Engine
  // =========================================================================
  FinancialIntelligenceReport get intelligenceReport {
    return FinancialIntelligenceEngine.analyze(
      transactions: _transactions,
      targets: _targets,
      primaryTarget: primaryTarget,
      currentLiquidSavings: currentSavings,
      adaptiveDailyPaceEnabled: adaptiveDailyPace,
      weekendSurgeEnabled: weekendSurge,
    );
  }

  FinancialHealthScore get healthScore => intelligenceReport.healthScore;
  TargetFeasibility get targetFeasibility => intelligenceReport.targetFeasibility;
  CashflowMetrics get cashflowMetrics => intelligenceReport.cashflowMetrics;
  List<AIRecommendation> get aiRecommendations => intelligenceReport.recommendations;
  List<SpendingLeakage> get spendingLeakages => intelligenceReport.leakages;
  List<SpendingAnomaly> get spendingAnomalies => intelligenceReport.anomalies;

  // Real-Time Deterministic Feasibility Engine
  double get monthlyAverageInflow => cashflowMetrics.monthlyInflow;
  double get dailySurplusCapacity => cashflowMetrics.netMonthlySurplus > 0 ? cashflowMetrics.netMonthlySurplus / 30.0 : 0.0;
  bool get isTargetOnTrack => targetFeasibility.status == TargetFeasibilityStatus.optimal || targetFeasibility.status == TargetFeasibilityStatus.feasible || targetFeasibility.status == TargetFeasibilityStatus.achieved;
  double get aiTargetPaceShortfall => targetFeasibility.dailyShortfallOrSurplus < 0 ? targetFeasibility.dailyShortfallOrSurplus.abs() : 0.0;
  String get aiInsightMessage => targetFeasibility.primarySummary;

  // Today's specific performance metrics
  List<Transaction> get todayTransactions {
    final now = DateTime.now();
    return _transactions.where((t) =>
        t.timestamp.year == now.year &&
        t.timestamp.month == now.month &&
        t.timestamp.day == now.day).toList();
  }

  double get todayCredits => todayTransactions
      .where((t) => t.isCredit)
      .fold(0.0, (acc, t) => acc + t.amount);

  double get todayDebits => todayTransactions
      .where((t) => t.isDebit)
      .fold(0.0, (acc, t) => acc + t.amount);

  double get todaySaved {
    final net = todayCredits - todayDebits;
    return net > 0 ? net : 0.0;
  }

  bool get isTodayTargetMet => todaySaved >= dailyPace && dailyPace > 0;
  double get todayShortfall {
    final diff = dailyPace - todaySaved;
    return diff > 0 ? diff : 0.0;
  }

  // Dynamic Tactical Liquidity Balances
  double get upiBalance {
    double bal = 25000.0;
    for (final t in _transactions) {
      if (t.isCredit) {
        bal += t.amount;
      } else {
        bal -= t.amount;
      }
    }
    return bal < 0 ? 0.0 : bal;
  }

  double get liquidVaultBalance => currentSavings;
  double get emergencyBalance => (goalCap * 0.25);

  // Visual Analytics Engine Calculations
  Map<String, double> get categoryExpenseBreakdown {
    final debits = _transactions.where((t) => t.isDebit);
    final map = <String, double>{};
    for (final t in debits) {
      final cat = t.category.isNotEmpty ? t.category : 'General';
      map[cat] = (map[cat] ?? 0.0) + t.amount;
    }
    return map;
  }

  Map<String, double> get channelBreakdown {
    final map = <String, double>{};
    for (final t in _transactions) {
      final src = t.source.isNotEmpty ? t.source : 'Other';
      map[src] = (map[src] ?? 0.0) + t.amount;
    }
    return map;
  }

  List<Map<String, dynamic>> get rolling7DaysSpending {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <Map<String, dynamic>>[];
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    double maxVal = 0.0;
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final nextDay = d.add(const Duration(days: 1));

      final dayTxs = _transactions.where((t) =>
          t.isDebit &&
          t.timestamp.isAfter(d.subtract(const Duration(milliseconds: 1))) &&
          t.timestamp.isBefore(nextDay));

      final total = dayTxs.fold(0.0, (acc, t) => acc + t.amount);
      if (total > maxVal) maxVal = total;

      days.add({
        'date': d,
        'label': weekdayNames[d.weekday - 1],
        'amount': total,
        'isToday': i == 0,
        'isHighest': false,
      });
    }

    if (maxVal > 0) {
      for (final item in days) {
        if ((item['amount'] as double) == maxVal) {
          item['isHighest'] = true;
        }
      }
    }
    return days;
  }

  double get highestDaySpending {
    final days = rolling7DaysSpending;
    double maxVal = 0.0;
    for (final d in days) {
      final amt = d['amount'] as double;
      if (amt > maxVal) maxVal = amt;
    }
    return maxVal;
  }

  double get dailyTargetBenchmark => dailyPace > 0 ? dailyPace : 1800.0;

  // =========================================================================
  // Constructor & Lifecycle
  // =========================================================================
  SanchayProvider() {
    final initialUser = FirebaseAuth.instance.currentUser;
    if (initialUser != null) {
      _currentUserId = initialUser.uid;
      userName = initialUser.displayName?.isNotEmpty == true
          ? initialUser.displayName!
          : (initialUser.email?.split('@').first ?? 'User');
      userEmail = initialUser.email ?? 'No email associated';
      _userAvatarUrl = initialUser.photoURL ?? '';
    }
    _loadLocalPrefs();
    _setupAuthAndFirestoreSync();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    _targetsSubscription?.cancel();
    _settingsSubscription?.cancel();
    _authSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // =========================================================================
  // Real-Time Firebase Auth & Firestore Sync
  // =========================================================================
  void _setupAuthAndFirestoreSync() {
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (user != null) {
        _currentUserId = user.uid;
        userName = user.displayName?.isNotEmpty == true
            ? user.displayName!
            : (user.email?.split('@').first ?? 'User');
        userEmail = user.email ?? 'No email associated';
        _userAvatarUrl = user.photoURL ?? '';
        isCloudConnected = true;
        _connectFirestoreStreams(user.uid);
      } else {
        // Strict enforcement: Wipe active state when unauthenticated
        _currentUserId = '';
        userName = '';
        userEmail = '';
        _userAvatarUrl = '';
        isCloudConnected = false;
        _transactionsSubscription?.cancel();
        _targetsSubscription?.cancel();
        _settingsSubscription?.cancel();
        _transactions = [];
        _targets = [];
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  void _connectFirestoreStreams(String userId) {
    _transactionsSubscription?.cancel();
    _targetsSubscription?.cancel();
    _settingsSubscription?.cancel();
    _metaSubscription?.cancel();
    if (_transactions.isEmpty && _targets.isEmpty) {
      _isLoading = true;
      notifyListeners();
      // Safety timeout: Never stay in loading state longer than 2.5s on cold start
      Timer(const Duration(milliseconds: 2500), () {
        if (_isLoading) {
          _isLoading = false;
          notifyListeners();
        }
      });
    }

    // 1. Ensure user profile & settings exist in users/{userId}/profile/settings (non-blocking)
    unawaited(_firestoreService.ensureUserSettings(
      userId,
      name: userName,
      email: userEmail,
      avatarUrl: _userAvatarUrl,
      isPrivacyMode: _isPrivacyMasked,
      biometricEnabled: biometricLock,
      reminderTime: '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}',
    ).catchError((e) {
      debugPrint('ensureUserSettings background error: $e');
    }));

    // 2. Ensure at least one primary target exists in users/{userId}/targets (non-blocking)
    unawaited(_firestoreService.ensurePrimaryTarget(
      userId,
      title: _targetName,
      targetCap: _goalCap,
      targetDate: _targetDate,
    ).catchError((e) {
      debugPrint('ensurePrimaryTarget background error: $e');
      return SanchayTarget(id: 'primary_vault', title: _targetName, targetCap: _goalCap, targetDate: _targetDate);
    }));

    // 3. Listen to users/{userId}/transactions ordered by timestamp descending
    _transactionsSubscription = _firestoreService.streamTransactions(userId).listen((txs) {
      _transactions = txs;
      _isLoading = false;
      lastSyncedTime = DateTime.now();
      _rescheduleDailyReminderIfEnabled();
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore transactions stream error: $e');
      _isLoading = false;
      notifyListeners();
    });

    // 4. Listen to users/{userId}/targets
    _targetsSubscription = _firestoreService.streamTargets(userId).listen((targetsList) {
      _targets = targetsList;
      if (_targets.isNotEmpty) {
        final p = _targets.first;
        _targetName = p.title;
        _goalCap = p.targetCap;
        _targetDate = p.targetDate;
        _isTargetPaused = p.isPaused;
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore targets stream error: $e');
    });

    // 5. Listen to users/{userId}/profile/settings
    _settingsSubscription = _firestoreService.streamUserSettings(userId).listen((doc) {
      if (doc.exists) {
        final data = doc.data() ?? {};
        if (data['name'] != null && (data['name'] as String).isNotEmpty) {
          userName = data['name'] as String;
        }
        if (data['email'] != null && (data['email'] as String).isNotEmpty) {
          userEmail = data['email'] as String;
        }
        if (data['avatarUrl'] != null && (data['avatarUrl'] as String).isNotEmpty) {
          _userAvatarUrl = data['avatarUrl'] as String;
        }
        if (data['isPrivacyMode'] != null) {
          _isPrivacyMasked = data['isPrivacyMode'] as bool;
        }
        if (data['biometricEnabled'] != null) {
          biometricLock = data['biometricEnabled'] as bool;
        }
        if (data['reminderTime'] != null && (data['reminderTime'] as String).contains(':')) {
          final parts = (data['reminderTime'] as String).split(':');
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            reminderTime = TimeOfDay(hour: h, minute: m);
          }
        }
        if (data['handle'] != null && (data['handle'] as String).isNotEmpty) {
          _userHandle = data['handle'] as String;
        } else if (data['username'] != null && (data['username'] as String).isNotEmpty) {
          _userHandle = data['username'] as String;
        }
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('Firestore settings stream error: $e');
    });

    // 6. Listen to users/{userId}/profile/meta
    _metaSubscription = AuthService.firestoreInstance
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('meta')
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() ?? {};
        bool changed = false;
        if (data['avatarLocalPath'] != null && (data['avatarLocalPath'] as String).isNotEmpty) {
          final lPath = data['avatarLocalPath'] as String;
          if (File(lPath).existsSync()) {
            _userAvatarUrl = lPath;
            changed = true;
          } else if (data['avatarUrl'] != null && (data['avatarUrl'] as String).isNotEmpty) {
            _userAvatarUrl = data['avatarUrl'] as String;
            changed = true;
          }
        } else if (data['avatarUrl'] != null && (data['avatarUrl'] as String).isNotEmpty) {
          _userAvatarUrl = data['avatarUrl'] as String;
          changed = true;
        }
        if (data['handle'] != null && (data['handle'] as String).isNotEmpty) {
          _userHandle = data['handle'] as String;
          changed = true;
        } else if (data['username'] != null && (data['username'] as String).isNotEmpty) {
          _userHandle = data['username'] as String;
          changed = true;
        }
        if (changed) {
          notifyListeners();
        }
      }
    }, onError: (e) {
      debugPrint('Firestore meta stream error: $e');
    });
  }

  // =========================================================================
  // Target Operations (users/{userId}/targets)
  // =========================================================================
  Future<String> createTarget({
    required String title,
    required double targetCap,
    required DateTime targetDate,
    bool isPaused = false,
  }) async {
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    final newTarget = SanchayTarget(
      id: '',
      title: title,
      targetCap: targetCap,
      currentAccumulation: currentSavings,
      targetDate: targetDate,
      isPaused: isPaused,
    );
    final id = await _firestoreService.createTarget(userId, newTarget);
    return id;
  }

  Future<String> createVault(SanchayTarget vault) async {
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isEmpty) return vault.id;

    final docId = vault.id.isNotEmpty ? vault.id : 'vault_${DateTime.now().millisecondsSinceEpoch}';
    final docRef = AuthService.firestoreInstance
        .collection('users')
        .doc(userId)
        .collection('targets')
        .doc(docId);

    final payload = vault.toFirestore();
    payload['createdAt'] = FieldValue.serverTimestamp();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(payload);

    final createdVault = vault.copyWith(id: docId);
    final idx = _targets.indexWhere((t) => t.id == docId);
    if (idx != -1) {
      _targets[idx] = createdVault;
    } else {
      _targets.add(createdVault);
    }
    if (createdVault.isPrimary) {
      await setPrimaryVault(createdVault.id);
    }
    notifyListeners();
    return docId;
  }

  Future<void> updateVault(SanchayTarget vault) async {
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isNotEmpty && vault.id.isNotEmpty) {
      final docRef = AuthService.firestoreInstance
          .collection('users')
          .doc(userId)
          .collection('targets')
          .doc(vault.id);

      final payload = vault.toFirestore();
      payload['updatedAt'] = FieldValue.serverTimestamp();
      await docRef.set(payload, SetOptions(merge: true));
    }

    final idx = _targets.indexWhere((t) => t.id == vault.id);
    if (idx != -1) {
      _targets[idx] = vault;
    }
    if (vault.isPrimary) {
      await setPrimaryVault(vault.id);
    }
    notifyListeners();
  }

  Future<void> setPrimaryVault(String vaultId) async {
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isNotEmpty) {
      await _firestoreService.setPrimaryTarget(userId, vaultId);
    }
    for (int i = 0; i < _targets.length; i++) {
      _targets[i] = _targets[i].copyWith(isPrimary: _targets[i].id == vaultId);
    }
    notifyListeners();
  }

  void updateTargetDirectly({
    String? targetId,
    required String name,
    required double cap,
    required DateTime date,
    required bool isPaused,
  }) {
    _targetName = name;
    _goalCap = cap;
    _targetDate = date;
    _isTargetPaused = isPaused;

    final tId = targetId ?? primaryTargetId ?? 'primary_vault';
    final idx = _targets.indexWhere((t) => t.id == tId);
    if (idx != -1) {
      _targets[idx] = _targets[idx].copyWith(
        title: name,
        targetCap: cap,
        targetDate: date,
        isPaused: isPaused,
      );
    } else {
      _targets.insert(
        0,
        SanchayTarget(
          id: tId,
          title: name,
          targetCap: cap,
          targetDate: date,
          isPaused: isPaused,
          currentAccumulation: currentSavings,
        ),
      );
    }
    _saveLocalPrefs();
    _rescheduleDailyReminderIfEnabled();
    notifyListeners();
  }

  Future<void> updateTarget({
    String? targetId,
    required String name,
    required double cap,
    required DateTime date,
    required bool isPaused,
  }) async {
    updateTargetDirectly(
      targetId: targetId,
      name: name,
      cap: cap,
      date: date,
      isPaused: isPaused,
    );

    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    final tId = targetId ?? primaryTargetId ?? 'primary_vault';
    if (userId.isNotEmpty) {
      await AuthService.firestoreInstance
          .collection('users')
          .doc(userId)
          .collection('targets')
          .doc(tId)
          .set({
        'title': name,
        'targetCap': cap,
        'targetDate': Timestamp.fromDate(date),
        'isPaused': isPaused,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> toggleTargetPaused([String? targetId]) async {
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    final tId = targetId ?? primaryTargetId;
    final newPauseState = !isTargetPaused;
    if (tId != null && tId.isNotEmpty) {
      await _firestoreService.toggleTargetPause(userId, tId, newPauseState);
    }
    _isTargetPaused = newPauseState;
    _saveLocalPrefs();
    _rescheduleDailyReminderIfEnabled();
    notifyListeners();
  }

  Future<void> updateGoalCap(double newCap) async {
    _goalCap = newCap;
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (primaryTargetId != null) {
      await _firestoreService.updateTarget(userId, primaryTargetId!, {'targetCap': newCap});
    }
    _saveLocalPrefs();
    _rescheduleDailyReminderIfEnabled();
    notifyListeners();
  }

  /// Delete a target vault from Firestore and local cache
  Future<void> deleteVault(String targetId) async {
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isNotEmpty && targetId.isNotEmpty) {
      try {
        await _firestoreService.deleteTarget(userId, targetId);
      } catch (e) {
        debugPrint('SanchayProvider deleteVault error: $e');
      }
    }
    _targets.removeWhere((t) => t.id == targetId);
    if (_selectedVaultId == targetId) {
      _selectedVaultId = null;
    }
    _saveLocalPrefs();
    notifyListeners();
  }

  /// Alias for deleteVault
  Future<void> deleteTarget(String targetId) => deleteVault(targetId);

  /// Direct contribution / deposit to the primary or specified target vault
  Future<void> contributeToVault({
    required double amount,
    String? targetId,
    String contributionType = 'Custom Inflow',
    String channel = 'VAULT_MANUAL',
    String source = 'Manual Deposit',
  }) async {
    if (amount <= 0) return;

    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isEmpty) return;

    String tId = targetId ?? primaryTargetId ?? '';
    if (tId.isEmpty) {
      final target = await _firestoreService.ensurePrimaryTarget(userId);
      tId = target.id;
    }

    final now = DateTime.now();
    final tempTxId = 'tx_deposit_${now.millisecondsSinceEpoch}';

    // 1. Instant optimistic local update for zero-latency UI response
    final target = _targets.firstWhere((t) => t.id == tId, orElse: () => primaryTarget ?? SanchayTarget(id: tId, title: 'Savings Vault', targetCap: 100000, targetDate: DateTime.now().add(const Duration(days: 30))));
    final optimisticTx = Transaction(
      id: tempTxId,
      amount: amount,
      type: 'vault_deposit',
      merchant: target.title,
      channel: channel,
      source: source,
      category: 'VAULT TRANSFER',
      timestamp: now,
      isAutoCaptured: false,
      tag: 'Vault Deposit',
      userId: userId,
      targetId: tId,
    );

    _transactions.insert(0, optimisticTx);

    // Optimistically update target accumulation if present in memory
    final targetIndex = _targets.indexWhere((t) => t.id == tId);
    if (targetIndex != -1) {
      final curr = _targets[targetIndex];
      _targets[targetIndex] = curr.copyWith(
        currentAccumulation: curr.currentAccumulation + amount,
      );
    }

    notifyListeners();

    // 2. Persist to Firestore atomically
    try {
      await _firestoreService.contributeToTarget(
        userId: userId,
        targetId: tId,
        amount: amount,
        channel: channel,
        source: source,
        merchant: target.title,
        category: 'VAULT TRANSFER',
      );
      _rescheduleDailyReminderIfEnabled();
    } catch (e) {
      debugPrint('Error contributing to vault: $e');
      notifyListeners();
      rethrow;
    }
  }

  // =========================================================================
  // Transaction Operations (users/{userId}/transactions)
  // =========================================================================
  Future<void> addTransaction(Transaction tx) async {
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (!_transactions.any((t) => t.id == tx.id)) {
      _transactions.insert(0, tx);
      notifyListeners();
    }
    await _firestoreService.addTransaction(userId, tx);
  }

  Future<void> deleteTransaction(String id) async {
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    await _firestoreService.deleteTransaction(userId, id);
  }

  Future<void> restoreTransaction(Transaction tx, [int? index]) async {
    await addTransaction(tx);
  }

  Future<void> purgeTransactions() async {
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    await _firestoreService.purgeTransactions(userId);
  }

  // =========================================================================
  // Profile & Settings Operations (users/{userId}/profile/settings)
  // =========================================================================
  Future<void> updateAvatarUrl(String newUrl) async {
    if (newUrl.trim().isEmpty) return;
    _userAvatarUrl = newUrl.trim();
    _saveLocalPrefs();
    notifyListeners();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.updatePhotoURL(_userAvatarUrl);
      }
    } catch (e) {
      debugPrint('SanchayProvider: FirebaseAuth photoURL update note: $e');
    }

    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isNotEmpty) {
      await _firestoreService.updateAvatarUrl(userId, _userAvatarUrl);
    }
  }


  Future<void> togglePrivacyMode() async {
    _isPrivacyMasked = !_isPrivacyMasked;
    _saveLocalPrefs();
    notifyListeners();

    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isNotEmpty) {
      await _firestoreService.updatePrivacyMode(userId, _isPrivacyMasked);
    }
  }

  void togglePrivacyMask() => togglePrivacyMode();

  Future<void> setBiometricLock(bool enabled) async {
    biometricLock = enabled;
    _saveLocalPrefs();
    await BiometricService().setBiometricEnabled(enabled, userId: _currentUserId);
    notifyListeners();

    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isNotEmpty) {
      await _firestoreService.updateUserSettings(userId, {
        'biometricEnabled': enabled,
      });
    }
  }

  Future<void> toggleBiometricLock() async {
    await setBiometricLock(!biometricLock);
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    reminderTime = time;
    if (dailyReminder) {
      _rescheduleDailyReminderIfEnabled();
    }
    _saveLocalPrefs();
    notifyListeners();

    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isNotEmpty) {
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      await _firestoreService.updateUserSettings(userId, {
        'reminderTime': timeStr,
      });
    }
  }

  void toggleUpiInterceptor() {
    upiInterceptor = !upiInterceptor;
    _saveLocalPrefs();
    notifyListeners();
  }

  void toggleClipboardAutoParse() {
    clipboardAutoParse = !clipboardAutoParse;
    _saveLocalPrefs();
    notifyListeners();
  }

  void toggleDailyReminder() {
    dailyReminder = !dailyReminder;
    if (dailyReminder) {
      _rescheduleDailyReminderIfEnabled();
    } else {
      _notificationService.cancelDailyReminder();
    }
    _saveLocalPrefs();
    notifyListeners();
  }

  void toggleMonthlySummary() {
    monthlySummary = !monthlySummary;
    _saveLocalPrefs();
    notifyListeners();
  }

  void toggleAdaptiveDailyPace() {
    adaptiveDailyPace = !adaptiveDailyPace;
    _saveLocalPrefs();
    notifyListeners();
  }

  void toggleWeekendSurge() {
    weekendSurge = !weekendSurge;
    _saveLocalPrefs();
    notifyListeners();
  }

  void setCategorizerMode(String mode) {
    categorizerMode = mode;
    _saveLocalPrefs();
    notifyListeners();
  }

  void setFilter(String filter) {
    if (_activeFilter != filter) {
      _activeFilter = filter;
      notifyListeners();
    }
  }

  String formatCurrency(double amount, {bool isSigned = false, bool isDebit = true}) {
    if (_isPrivacyMasked) {
      return '••••••';
    }
    final prefix = isSigned ? (isDebit ? '-₹' : '+₹') : '₹';
    final isWhole = amount.truncateToDouble() == amount;
    final formattedNumber = isWhole
        ? amount.toInt().toString().replaceAllMapped(
              RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'),
              (m) => '${m[1]},',
            )
        : amount.toStringAsFixed(2);

    return '$prefix$formattedNumber';
  }

  // =========================================================================
  // Native Notification Listener Integration
  // =========================================================================
  void _setupNotificationListener() {
    checkNotificationPermission();

    // Listen to native EventChannel / MethodChannel streams
    _notificationSubscription = _notificationBridge.transactionStream.listen((tx) {
      final minuteSlot = tx.timestamp.millisecondsSinceEpoch ~/ 60000;
      final dedupeKey = '${tx.amount}_${tx.type}_$minuteSlot';

      if (_recentDedupeKeys.contains(dedupeKey)) {
        debugPrint('Duplicate financial alert dropped in Provider: $dedupeKey');
        return;
      }
      _recentDedupeKeys.add(dedupeKey);

      // Write directly to Firestore with isAutoCaptured: true
      addTransaction(tx);
    });

    // Also connect NotificationService stream as fallback
    _notificationService.transactionStream.listen((tx) {
      final minuteSlot = tx.timestamp.millisecondsSinceEpoch ~/ 60000;
      final dedupeKey = '${tx.amount}_${tx.type}_$minuteSlot';
      if (!_recentDedupeKeys.contains(dedupeKey)) {
        _recentDedupeKeys.add(dedupeKey);
        addTransaction(tx);
      }
    });

    // Check pending notifications queued while app was asleep
    _notificationBridge.getPendingNotifications().then((pending) {
      for (final tx in pending) {
        addTransaction(tx);
      }
    });
  }

  Future<void> checkNotificationPermission() async {
    final granted = await _notificationBridge.isNotificationAccessGranted();
    _isNotificationPermissionGranted = granted;
    notificationAccess = granted;
    notifyListeners();
  }

  void openNotificationListenerSettings() {
    _notificationBridge.openNotificationSettings();
  }

  Future<void> sendTestPushNotification() async {
    await _notificationService.triggerInstantTestPush(
      todaySaved: todaySaved,
      dailyPaceTarget: dailyPace,
    );
  }

  void _rescheduleDailyReminderIfEnabled() {
    if (dailyReminder) {
      _notificationService.scheduleDailyGoalReminder(
        time: reminderTime,
        todaySaved: todaySaved,
        dailyPaceTarget: dailyPace,
      );
    }
  }

  Future<void> forceCloudSync() async {
    isSyncing = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
    if (_currentUserId.isNotEmpty) {
      _connectFirestoreStreams(_currentUserId);
    }
    lastSyncedTime = DateTime.now();
    isSyncing = false;
    notifyListeners();
  }



  Future<void> toggleVaultPause(String vaultId) async {
    final idx = _targets.indexWhere((t) => t.id == vaultId);
    if (idx != -1) {
      final updated = _targets[idx].copyWith(isPaused: !_targets[idx].isPaused);
      _targets[idx] = updated;
      notifyListeners();
      final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
      if (userId.isNotEmpty) {
        await _firestoreService.toggleTargetPause(userId, vaultId, updated.isPaused);
      }
    }
  }

  Future<void> transferBetweenVaults({
    required String fromVaultId,
    required String toVaultId,
    required double amount,
  }) async {
    if (amount <= 0 || fromVaultId == toVaultId) return;
    final fromIdx = _targets.indexWhere((t) => t.id == fromVaultId);
    final toIdx = _targets.indexWhere((t) => t.id == toVaultId);
    if (fromIdx != -1 && toIdx != -1) {
      final fromTarget = _targets[fromIdx];
      final toTarget = _targets[toIdx];
      _targets[fromIdx] = fromTarget.copyWith(
        currentAccumulation: (fromTarget.currentAccumulation - amount).clamp(0.0, double.infinity),
      );
      _targets[toIdx] = toTarget.copyWith(
        currentAccumulation: toTarget.currentAccumulation + amount,
      );
      notifyListeners();
    }
    final userId = _currentUserId.isNotEmpty ? _currentUserId : _authService.currentUserId;
    if (userId.isNotEmpty) {
      await _firestoreService.transferBetweenTargets(
        userId: userId,
        fromTargetId: fromVaultId,
        toTargetId: toVaultId,
        amount: amount,
      );
    }
  }

  // =========================================================================
  // SMS / UPI Ingestion & Clipboard Parsing
  // =========================================================================
  Future<ParsedFinancialSms?> ingestRawSmsOrUpi(String rawText) async {
    final parsed = SmsUpiParserEngine.parse(text: rawText);
    if (parsed == null) return null;
    final tx = parsed.toTransaction(userId: _currentUserId);
    await addTransaction(tx);
    return parsed;
  }

  Future<ParsedFinancialSms?> checkClipboardForSms() async {
    return ClipboardParserService().checkClipboard(isEnabled: clipboardAutoParse);
  }

  // =========================================================================
  // Genuine Data Export & Backup (Native File & Share Sheet)
  // =========================================================================
  Future<FileExportResult> exportLedgerCsvFile() {
    final csv = FileExportService.generateLedgerCsv(
      transactions: _transactions,
      userEmail: userEmail,
    );
    return FileExportService.exportAndShare(
      content: csv,
      baseFilename: 'sanchay_ledger',
      extension: 'csv',
      mimeType: 'text/csv',
      recordCount: _transactions.length,
      subject: 'Sanchay Ledger CSV Export',
    );
  }

  Future<FileExportResult> exportVaultsCsvFile() {
    final csv = FileExportService.generateVaultsCsv(
      targets: _targets,
    );
    return FileExportService.exportAndShare(
      content: csv,
      baseFilename: 'sanchay_vaults',
      extension: 'csv',
      mimeType: 'text/csv',
      recordCount: _targets.length,
      subject: 'Sanchay Multi-Vault Goals CSV Export',
    );
  }

  Future<FileExportResult> exportStateBackupJsonFile() {
    final jsonStr = FileExportService.generateStateBackupJson(
      transactions: _transactions,
      targets: _targets,
      userName: userName,
      userEmail: userEmail,
      currentSavings: currentSavings,
      safeToSpend: safeToSpend,
    );
    return FileExportService.exportAndShare(
      content: jsonStr,
      baseFilename: 'sanchay_backup',
      extension: 'json',
      mimeType: 'application/json',
      recordCount: _transactions.length,
      subject: 'Sanchay State Backup JSON Export',
    );
  }

  String exportCsv() {
    return FileExportService.generateLedgerCsv(
      transactions: _transactions,
      userEmail: userEmail,
    );
  }

  String exportJson() {
    return FileExportService.generateStateBackupJson(
      transactions: _transactions,
      targets: _targets,
      userName: userName,
      userEmail: userEmail,
      currentSavings: currentSavings,
      safeToSpend: safeToSpend,
    );
  }

  Future<bool> importJson(String jsonString) async {
    try {
      final res = await BackupService().restoreFromJsonString(
        jsonString: jsonString,
        provider: this,
      );
      return res.success;
    } catch (_) {
      return false;
    }
  }

  /// Triggers full state recalculation and reactive UI updates across all screens.
  void refreshAllData() {
    notifyListeners();
  }

  // =========================================================================
  // SharedPreferences Local Cache
  // =========================================================================
  Future<void> _saveLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefGoalCapKey, _goalCap);
      await prefs.setBool(_prefPrivacyKey, _isPrivacyMasked);
      await prefs.setString(_prefTargetNameKey, _targetName);
      await prefs.setString(_prefTargetDateKey, _targetDate.toIso8601String());
      await prefs.setBool(_prefTargetPausedKey, _isTargetPaused);
      await prefs.setString(_prefUserAvatarKey, _userAvatarUrl);

      final settingsString = jsonEncode({
        'biometricLock': biometricLock,
        'upiInterceptor': upiInterceptor,
        'clipboardAutoParse': clipboardAutoParse,
        'dailyReminder': dailyReminder,
        'reminderHour': reminderTime.hour,
        'reminderMinute': reminderTime.minute,
        'monthlySummary': monthlySummary,
        'adaptiveDailyPace': adaptiveDailyPace,
        'weekendSurge': weekendSurge,
        'categorizerMode': categorizerMode,
      });
      await prefs.setString(_prefSettingsKey, settingsString);
    } catch (_) {}
  }

  Future<void> _loadLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefGoalCapKey)) {
        _goalCap = prefs.getDouble(_prefGoalCapKey) ?? 100000.0;
      }
      if (prefs.containsKey(_prefPrivacyKey)) {
        _isPrivacyMasked = prefs.getBool(_prefPrivacyKey) ?? false;
      }
      if (prefs.containsKey(_prefTargetNameKey)) {
        _targetName = prefs.getString(_prefTargetNameKey) ?? _targetName;
      }
      if (prefs.containsKey(_prefTargetDateKey)) {
        final dStr = prefs.getString(_prefTargetDateKey);
        if (dStr != null) {
          final parsed = DateTime.tryParse(dStr);
          if (parsed != null) _targetDate = parsed;
        }
      }
      if (prefs.containsKey(_prefTargetPausedKey)) {
        _isTargetPaused = prefs.getBool(_prefTargetPausedKey) ?? false;
      }
      if (prefs.containsKey(_prefUserAvatarKey)) {
        final aStr = prefs.getString(_prefUserAvatarKey);
        if (aStr != null && aStr.isNotEmpty) _userAvatarUrl = aStr;
      }
      if (prefs.containsKey(_prefSettingsKey)) {
        final settingsString = prefs.getString(_prefSettingsKey);
        if (settingsString != null && settingsString.isNotEmpty) {
          final s = jsonDecode(settingsString) as Map<String, dynamic>;
          biometricLock = s['biometricLock'] as bool? ?? false;
          upiInterceptor = s['upiInterceptor'] as bool? ?? upiInterceptor;
          clipboardAutoParse = s['clipboardAutoParse'] as bool? ?? clipboardAutoParse;
          dailyReminder = s['dailyReminder'] as bool? ?? dailyReminder;
          if (s['reminderHour'] != null && s['reminderMinute'] != null) {
            reminderTime = TimeOfDay(
              hour: s['reminderHour'] as int,
              minute: s['reminderMinute'] as int,
            );
          }
          monthlySummary = s['monthlySummary'] as bool? ?? monthlySummary;
          adaptiveDailyPace = s['adaptiveDailyPace'] as bool? ?? adaptiveDailyPace;
          weekendSurge = s['weekendSurge'] as bool? ?? weekendSurge;
          categorizerMode = s['categorizerMode'] as String? ?? categorizerMode;
        }
      }

      final bioEnabled = await BiometricService().isBiometricEnabled();
      biometricLock = bioEnabled;

      notifyListeners();
      _rescheduleDailyReminderIfEnabled();
    } catch (_) {}
  }
}
