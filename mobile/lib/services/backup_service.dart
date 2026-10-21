import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../providers/sanchay_provider.dart';

/// Details of a backup export operation.
class BackupExportResult {
  final bool success;
  final String filename;
  final String filePath;
  final int transactionCount;
  final int vaultCount;
  final int byteSize;
  final String? errorMessage;

  const BackupExportResult({
    required this.success,
    required this.filename,
    required this.filePath,
    required this.transactionCount,
    required this.vaultCount,
    required this.byteSize,
    this.errorMessage,
  });

  String get formattedSize {
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Details of a backup restore operation.
class BackupRestoreResult {
  final bool success;
  final bool wasCancelled;
  final int restoredTransactions;
  final int restoredVaults;
  final String message;

  const BackupRestoreResult({
    required this.success,
    this.wasCancelled = false,
    this.restoredTransactions = 0,
    this.restoredVaults = 0,
    required this.message,
  });

  factory BackupRestoreResult.cancelled() => const BackupRestoreResult(
        success: false,
        wasCancelled: true,
        message: 'Backup restore cancelled by user.',
      );
}

/// Thrown when an imported file fails Sanchay schema validation.
class BackupValidationException implements Exception {
  final String message;
  const BackupValidationException([this.message = 'Invalid Sanchay backup file format']);

  @override
  String toString() => message;
}

/// Full Database Backup & Real-Time Hydration Restore Service.
///
/// Exports structured JSON backups and imports/restores them into the local
/// SQLite / provider ledger in real-time, instantly refreshing all UI charts and balances.
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  static const String currentSchemaVersion = '2.0';

  /// Generates the structured JSON payload for full database backup.
  Map<String, dynamic> generateBackupPayload({
    required SanchayProvider provider,
  }) {
    final now = DateTime.now();

    // 1. Metadata
    final metadata = {
      'app': 'Sanchay',
      'appVersion': '1.0.0+1',
      'schemaVersion': currentSchemaVersion,
      'exportTimestamp': now.toIso8601String(),
      'userId': provider.currentUserId,
    };

    // 2. Ledger (full array of transactions)
    final ledger = provider.allTransactions.map((tx) {
      return {
        'id': tx.id,
        'timestamp': tx.timestamp.toIso8601String(),
        'amount': tx.amount,
        'type': tx.type,
        'merchant': tx.merchant,
        'category': tx.category,
        'channel': tx.channel,
        'source': tx.source,
        'isCredit': tx.isCredit,
        'isDebit': tx.isDebit,
        'isAutoCaptured': tx.isAutoCaptured,
        'accountNumber': tx.accountNumber,
        'referenceNumber': tx.referenceNumber,
        'balanceAfter': tx.balanceAfter,
        'rawText': tx.rawText,
        'tag': tx.tag,
        'targetId': tx.targetId,
      };
    }).toList();

    // 3. Vaults (full array of multi-vault goals)
    final vaults = provider.allTargets.map((v) {
      return {
        'id': v.id,
        'title': v.title,
        'targetCap': v.targetCap,
        'currentSaved': v.currentAccumulation,
        'deadline': v.targetDate.toIso8601String(),
        'category': v.category,
        'isPaused': v.isPaused,
        'isPrimary': v.isPrimary,
      };
    }).toList();

    // 4. Preferences (User settings without auth credentials)
    final preferences = {
      'userName': provider.userName,
      'userEmail': provider.userEmail,
      'userHandle': provider.userHandle,
      'isPrivacyMasked': provider.isPrivacyMasked,
      'upiInterceptor': provider.upiInterceptor,
      'biometricLock': provider.biometricLock,
      'dailyReminder': provider.dailyReminder,
      'weekendSurge': provider.weekendSurge,
      'adaptiveDailyPace': provider.adaptiveDailyPace,
      'categorizerMode': provider.categorizerMode,
    };

    return {
      'metadata': metadata,
      'ledger': ledger,
      'vaults': vaults,
      'preferences': preferences,
    };
  }

  /// Exports full JSON backup to a temp file and triggers native share.
  Future<BackupExportResult> exportBackup({
    required SanchayProvider provider,
  }) async {
    try {
      final payload = generateBackupPayload(provider: provider);
      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

      final directory = await getTemporaryDirectory();
      final fileName = 'Sanchay_Backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      final bytes = await file.length();
      debugPrint('BackupService: Wrote $bytes bytes backup to ${file.path}');

      // Native share dialog
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text: 'Sanchay Complete Wealth Backup',
        subject: 'Sanchay System Backup (${payload['ledger'].length} records)',
      );

      return BackupExportResult(
        success: true,
        filename: fileName,
        filePath: file.path,
        transactionCount: (payload['ledger'] as List).length,
        vaultCount: (payload['vaults'] as List).length,
        byteSize: bytes,
      );
    } catch (e, stack) {
      debugPrint('BackupService: Error exporting backup: $e\n$stack');
      return BackupExportResult(
        success: false,
        filename: '',
        filePath: '',
        transactionCount: 0,
        vaultCount: 0,
        byteSize: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Restores database and provider state from a user-selected JSON backup file.
  Future<BackupRestoreResult> restoreBackup({
    required SanchayProvider provider,
  }) async {
    // 1. Pick JSON backup file
    final List<PlatformFile> pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (pickedFiles.isEmpty) {
      debugPrint('BackupService: Restore cancelled by user');
      return BackupRestoreResult.cancelled();
    }

    final pickedFile = pickedFiles.first;
    String? content;

    if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
      final file = File(pickedFile.path!);
      if (await file.exists()) {
        content = await file.readAsString();
      }
    }

    if (content == null) {
      try {
        final bytes = await pickedFile.readAsBytes();
        if (bytes.isNotEmpty) {
          content = utf8.decode(bytes);
        }
      } catch (e) {
        debugPrint('BackupService: readAsBytes failed: $e');
      }
    }

    if (content == null || content.trim().isEmpty) {
      throw const BackupValidationException('Invalid Sanchay backup file format: empty file.');
    }

    // 2. Parse & Validate
    return restoreFromJsonString(jsonString: content, provider: provider);
  }

  /// Parses and validates JSON string, performing atomic batch restore into provider.
  Future<BackupRestoreResult> restoreFromJsonString({
    required String jsonString,
    required SanchayProvider provider,
  }) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      throw const BackupValidationException('Invalid Sanchay backup file format');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BackupValidationException('Invalid Sanchay backup file format');
    }

    // Validate schema: must contain metadata or ledger/transactions or vaults/targets
    final bool hasMetadata = decoded.containsKey('metadata') && decoded['metadata'] is Map;
    final bool hasLedger = decoded.containsKey('ledger') && decoded['ledger'] is List;
    final bool hasTransactions = decoded.containsKey('transactions') && decoded['transactions'] is List;
    final bool hasVaults = decoded.containsKey('vaults') && decoded['vaults'] is List;
    final bool hasTargets = decoded.containsKey('targets') && decoded['targets'] is List;
    final bool hasTarget = decoded.containsKey('target') && decoded['target'] is Map;

    if (!hasMetadata && !hasLedger && !hasTransactions && !hasVaults && !hasTargets && !hasTarget) {
      throw const BackupValidationException('Invalid Sanchay backup file format');
    }

    // 3. Batch Restore into Local Ledger & Database
    int restoredTxCount = 0;
    int restoredVaultCount = 0;

    // Existing IDs in provider to prevent duplicate entries
    final existingTxIds = provider.allTransactions.map((t) => t.id).toSet();
    final existingTargetIds = provider.allTargets.map((t) => t.id).toSet();

    // A. Restore Transactions
    final List<dynamic> txArray = (decoded['ledger'] as List<dynamic>?) ??
        (decoded['transactions'] as List<dynamic>?) ??
        [];

    for (final item in txArray) {
      if (item is! Map<String, dynamic>) continue;
      final txId = item['id']?.toString() ?? '';
      if (txId.isEmpty) continue;

      // Skip duplicate IDs
      if (existingTxIds.contains(txId)) {
        continue;
      }

      final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0) continue;

      final type = item['type']?.toString() ?? 'debit';
      final merchant = item['merchant']?.toString() ?? 'Restored Payment';
      final category = item['category']?.toString() ?? 'General';
      final channel = item['channel']?.toString();
      final source = item['source']?.toString() ?? 'RESTORE';
      final tag = item['tag']?.toString() ?? 'Restored Backup';
      final rawText = item['rawText']?.toString();
      final isAuto = item['isAutoCaptured'] == true;
      final accountNumber = item['accountNumber']?.toString();
      final referenceNumber = item['referenceNumber']?.toString();
      final balanceAfter = (item['balanceAfter'] as num?)?.toDouble();

      DateTime timestamp = DateTime.now();
      if (item['timestamp'] != null) {
        timestamp = DateTime.tryParse(item['timestamp'].toString()) ?? DateTime.now();
      }

      final newTx = Transaction(
        id: txId,
        amount: amount,
        type: type,
        merchant: merchant,
        channel: channel,
        source: source,
        category: category,
        timestamp: timestamp,
        isAutoCaptured: isAuto,
        accountNumber: accountNumber,
        referenceNumber: referenceNumber,
        balanceAfter: balanceAfter,
        rawText: rawText,
        tag: tag,
      );

      await provider.addTransaction(newTx);
      existingTxIds.add(txId);
      restoredTxCount++;
    }

    // B. Restore Vault Goals
    final List<dynamic> vaultArray = (decoded['vaults'] as List<dynamic>?) ??
        (decoded['targets'] as List<dynamic>?) ??
        [];

    for (final item in vaultArray) {
      if (item is! Map<String, dynamic>) continue;
      final vId = item['id']?.toString() ?? '';
      if (vId.isEmpty) continue;

      final title = (item['title'] ?? item['name'] ?? 'Restored Vault').toString();
      final cap = (item['targetCap'] ?? item['cap'] as num?)?.toDouble() ?? 100000.0;
      final isPaused = item['isPaused'] == true;

      DateTime deadline = DateTime.now().add(const Duration(days: 30));
      if (item['deadline'] != null || item['targetDate'] != null) {
        final dStr = (item['deadline'] ?? item['targetDate']).toString();
        deadline = DateTime.tryParse(dStr) ?? deadline;
      }

      if (existingTargetIds.contains(vId)) {
        await provider.updateTarget(
          targetId: vId,
          name: title,
          cap: cap,
          date: deadline,
          isPaused: isPaused,
        );
      } else {
        await provider.createTarget(
          title: title,
          targetCap: cap,
          targetDate: deadline,
          isPaused: isPaused,
        );
        existingTargetIds.add(vId);
      }
      restoredVaultCount++;
    }

    // Handle legacy single target payload
    if (decoded.containsKey('target') && decoded['target'] is Map<String, dynamic>) {
      final t = decoded['target'] as Map<String, dynamic>;
      final cap = (t['cap'] as num?)?.toDouble() ?? 100000.0;
      final name = t['name']?.toString() ?? 'Primary Vault';
      final date = DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30));
      final isPaused = t['isPaused'] == true;

      await provider.updateTarget(
        name: name,
        cap: cap,
        date: date,
        isPaused: isPaused,
      );
      restoredVaultCount++;
    }

    // C. Restore Preferences (if present)
    if (decoded.containsKey('preferences') && decoded['preferences'] is Map<String, dynamic>) {
      final prefs = decoded['preferences'] as Map<String, dynamic>;
      if (prefs['userHandle'] != null && prefs['userHandle'].toString().isNotEmpty) {
        provider.updateHandle(prefs['userHandle'].toString());
      }
      if (prefs['isPrivacyMasked'] != null && prefs['isPrivacyMasked'] is bool) {
        if (provider.isPrivacyMasked != prefs['isPrivacyMasked']) {
          provider.togglePrivacyMode();
        }
      }
    }

    // D. Trigger Real-Time Recalculations & State Refresh
    provider.refreshAllData();

    final summary = 'Successfully restored $restoredTxCount transaction${restoredTxCount == 1 ? "" : "s"} and $restoredVaultCount vault${restoredVaultCount == 1 ? "" : "s"}.';
    debugPrint('BackupService: $summary');

    return BackupRestoreResult(
      success: true,
      restoredTransactions: restoredTxCount,
      restoredVaults: restoredVaultCount,
      message: summary,
    );
  }
}
