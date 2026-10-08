import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../providers/sanchay_provider.dart';
import 'notification_parser.dart';

/// Result summary of an SMS Inbox sync pass.
class SmsSyncResult {
  final bool success;
  final int syncedCount;
  final int totalScanned;
  final String message;

  const SmsSyncResult({
    required this.success,
    required this.syncedCount,
    required this.totalScanned,
    required this.message,
  });
}

/// Offline SMS Inbox Fallback Synchronization Service.
///
/// Scans local SMS inbox for missed bank/UPI notifications within the last 24 hours,
/// parses them via [parseUpiMessage], checks for duplicates using cryptographic/timestamp
/// heuristics against existing ledger transactions & persistent storage, and commits
/// them to the local ledger.
class SmsSyncService {
  static final SmsSyncService _instance = SmsSyncService._internal();
  factory SmsSyncService() => _instance;
  SmsSyncService._internal();

  static const String _prefSyncedHashesKey = 'sanchay_synced_sms_hashes_v1';

  /// Regex pattern matching prominent Indian banking & payment sender handles.
  static final RegExp _bankSenderPattern = RegExp(
    r'(HDFC|SBI|ICICI|PAYTM|AXIS|KOTAK|BOI|CBOL|CBIN|CENTBK|CANARA|CANBNK|PNB|UNION|INDUS|YESB|IDBI|FEDB|RBL|CITI|SCBL|BARODA|BOB|IOB|UCO|AIRTEL|AMAZON|GPAY|PHONEPE)',
    caseSensitive: false,
  );

  /// Synchronize bank SMS messages received in the last 24 hours.
  ///
  /// Requests [Permission.sms], queries inbox, filters bank senders,
  /// parses messages, eliminates duplicates, and writes new entries to [provider].
  Future<SmsSyncResult> syncBankSmsInbox({
    required SanchayProvider provider,
    Duration lookback = const Duration(hours: 24),
  }) async {
    try {
      // 1. Request SMS permission
      final permissionStatus = await Permission.sms.request();
      if (!permissionStatus.isGranted) {
        debugPrint('SmsSyncService: SMS permission denied ($permissionStatus)');
        return SmsSyncResult(
          success: false,
          syncedCount: 0,
          totalScanned: 0,
          message: permissionStatus.isPermanentlyDenied
              ? 'SMS permission is permanently denied. Please enable in Settings.'
              : 'SMS reading permission was denied.',
        );
      }

      // 2. Query inbox messages
      final SmsQuery query = SmsQuery();
      final List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 250,
      );

      debugPrint('SmsSyncService: Queried ${messages.length} inbox SMS records');
      if (messages.isEmpty) {
        return const SmsSyncResult(
          success: true,
          syncedCount: 0,
          totalScanned: 0,
          message: 'No inbox SMS messages found.',
        );
      }

      // 3. Load persistent deduplication cache
      final prefs = await SharedPreferences.getInstance();
      final List<String> cachedHashList = prefs.getStringList(_prefSyncedHashesKey) ?? [];
      final Set<String> persistedHashes = Set<String>.from(cachedHashList);

      // Existing ledger transactions for memory/SQLite deduplication
      final existingTxs = provider.allTransactions;

      final now = DateTime.now();
      final cutoff = now.subtract(lookback);

      int totalScanned = 0;
      int syncedCount = 0;
      final List<String> newlyAddedHashes = [];

      // 4. Iterate and filter
      for (final sms in messages) {
        final address = sms.address?.trim() ?? '';
        final body = sms.body?.trim() ?? '';
        final smsDate = sms.date;

        if (body.isEmpty) continue;

        // Verify sender handle matches bank sender pattern
        final isBankSender = _bankSenderPattern.hasMatch(address);
        if (!isBankSender) {
          // If sender format is alphanumeric without common header, verify if text has bank keywords
          final lowerBody = body.toLowerCase();
          final hasBankKeywords = lowerBody.contains('ac no') ||
              lowerBody.contains('a/c') ||
              lowerBody.contains('acct') ||
              lowerBody.contains('vpa') ||
              lowerBody.contains('upi') ||
              lowerBody.contains('ref no') ||
              lowerBody.contains('reference') ||
              lowerBody.contains('credited') ||
              lowerBody.contains('debited') ||
              lowerBody.contains('phonepe wallet') ||
              lowerBody.contains('withdrawal of') ||
              lowerBody.contains('bank') ||
              lowerBody.contains('cbol');
          if (!hasBankKeywords) continue;
        }

        totalScanned++;

        // Filter: only messages received in the last 24 hours
        if (smsDate != null && smsDate.isBefore(cutoff)) {
          continue;
        }

        // 5. Parse UPI / Bank SMS body
        final parsed = parseUpiMessage(body, address);
        if (parsed == null || parsed.amount <= 0) {
          continue;
        }

        // 6. Deduplication Check (strongest identifier priority: reference > sms.id > deterministic fingerprint)
        final type = parsed.isCredit ? 'credit' : 'debit';
        String uniqueHash;
        if (parsed.referenceNumber != null && parsed.referenceNumber!.isNotEmpty) {
          uniqueHash = 'REF_${parsed.referenceNumber}';
        } else if (sms.id != null && sms.id.toString().isNotEmpty) {
          uniqueHash = 'SMSID_${sms.id}';
        } else {
          uniqueHash = _generateSmsHash(
            address: address,
            timestampMs: smsDate?.millisecondsSinceEpoch ?? 0,
            amount: parsed.amount,
            type: type,
            bodySnippet: body.length > 30 ? body.substring(0, 30) : body,
          );
        }

        // Check A: Persistent hash storage
        if (persistedHashes.contains(uniqueHash)) {
          continue;
        }

        // Check B: Compare against existing transactions in ledger
        final isDuplicateInLedger = _isDuplicateInLedger(
          existingTxs: existingTxs,
          amount: parsed.amount,
          isCredit: parsed.isCredit,
          smsDate: smsDate,
          rawBody: body,
          referenceNumber: parsed.referenceNumber,
        );

        if (isDuplicateInLedger) {
          persistedHashes.add(uniqueHash);
          newlyAddedHashes.add(uniqueHash);
          continue;
        }

        // 7. Extract Clean Merchant & Bank Details
        final bankName = parsed.bank ?? _resolveBankName(address);
        String merchantName = bankName;

        if (parsed.subtype == 'WALLET_INFLOW') {
          merchantName = 'PhonePe Wallet Withdrawal';
        } else if (parsed.subtype == 'WALLET_PAYMENT') {
          merchantName = 'PhonePe Wallet Payment';
        } else if (parsed.isCredit) {
          final payer = NotificationParser.extractPayerFromPaidYou(body);
          if (payer != null && payer.isNotEmpty) {
            merchantName = payer;
          } else {
            merchantName = '$bankName Credit';
          }
        } else {
          final merchant = _extractMerchantFromDebitSms(body);
          if (merchant != null && merchant.isNotEmpty) {
            merchantName = merchant;
          } else {
            merchantName = '$bankName Payment';
          }
        }

        final category = parsed.category ?? NotificationParser.inferCategory(body, parsed.isCredit);
        final channel = (parsed.subtype == 'WALLET_INFLOW' || parsed.subtype == 'WALLET_PAYMENT')
            ? 'WALLET'
            : 'BANK / SMS';

        // 8. Construct Transaction and Record into Local Ledger & Balance
        final txId = (parsed.referenceNumber != null && parsed.referenceNumber!.isNotEmpty)
            ? 'tx_sms_ref_${parsed.referenceNumber}'
            : 'sms_${smsDate?.millisecondsSinceEpoch ?? now.millisecondsSinceEpoch}_${sms.id ?? math.Random().nextInt(99999)}';

        final newTx = Transaction(
          id: txId,
          amount: parsed.amount,
          type: type,
          merchant: merchantName,
          channel: channel,
          source: bankName,
          category: category,
          timestamp: smsDate ?? now,
          isAutoCaptured: true,
          rawText: body,
          referenceNumber: parsed.referenceNumber,
          accountNumber: parsed.accountLast4,
          balanceAfter: parsed.balanceAfter,
          tag: 'SMS Inbox Sync',
        );

        await provider.addTransaction(newTx);
        persistedHashes.add(uniqueHash);
        newlyAddedHashes.add(uniqueHash);
        syncedCount++;
      }

      // Persist updated hash list to SharedPreferences (keep last 500 hashes)
      if (newlyAddedHashes.isNotEmpty) {
        final List<String> toSave = persistedHashes.toList();
        if (toSave.length > 500) {
          toSave.removeRange(0, toSave.length - 500);
        }
        await prefs.setStringList(_prefSyncedHashesKey, toSave);
      }

      final summary = syncedCount > 0
          ? 'Successfully synced $syncedCount new bank transaction${syncedCount > 1 ? "s" : ""}.'
          : 'All bank transactions in the last 24h are already up to date.';

      debugPrint('SmsSyncService: Done. $summary (scanned $totalScanned)');
      return SmsSyncResult(
        success: true,
        syncedCount: syncedCount,
        totalScanned: totalScanned,
        message: summary,
      );
    } catch (e, stack) {
      debugPrint('SmsSyncService: Error during syncBankSmsInbox: $e\n$stack');
      return SmsSyncResult(
        success: false,
        syncedCount: 0,
        totalScanned: 0,
        message: 'Sync failed: ${e.toString().split('\n').first}',
      );
    }
  }

  /// Generates a deterministic signature string for an SMS.
  String _generateSmsHash({
    required String address,
    required int timestampMs,
    required double amount,
    required String type,
    required String bodySnippet,
  }) {
    final base = '${address.toUpperCase()}_${amount.toStringAsFixed(2)}_${type}_$timestampMs';
    return base.replaceAll(RegExp(r'\s+'), '');
  }

  /// Checks if an existing transaction matches the SMS amount, type, and approximate timestamp.
  bool _isDuplicateInLedger({
    required List<Transaction> existingTxs,
    required double amount,
    required bool isCredit,
    required DateTime? smsDate,
    required String rawBody,
    String? referenceNumber,
  }) {
    for (final tx in existingTxs) {
      // 0. Reference number exact match (strongest)
      if (referenceNumber != null &&
          referenceNumber.isNotEmpty &&
          tx.referenceNumber != null &&
          tx.referenceNumber == referenceNumber) {
        return true;
      }

      // 1. Direct raw text exact match
      if (tx.rawText != null && tx.rawText!.trim() == rawBody.trim()) {
        return true;
      }

      // 2. Amount and polarity match
      final isSamePolarity = (isCredit && tx.isCredit) || (!isCredit && tx.isDebit);
      final isSameAmount = (tx.amount - amount).abs() < 0.01;

      if (isSamePolarity && isSameAmount) {
        if (smsDate != null) {
          // Check timestamp proximity within 5 minutes (300 seconds)
          final diff = (tx.timestamp.difference(smsDate)).inSeconds.abs();
          if (diff <= 300) {
            return true;
          }
        } else {
          // If SMS date is unavailable, check same calendar day
          final now = DateTime.now();
          if (tx.timestamp.year == now.year &&
              tx.timestamp.month == now.month &&
              tx.timestamp.day == now.day) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Human-friendly bank name resolver.
  String _resolveBankName(String senderHandle) {
    final upper = senderHandle.toUpperCase();
    if (upper.contains('CBOL') || upper.contains('CBIN') || upper.contains('CENTBK')) return 'Central Bank of India';
    if (upper.contains('HDFC')) return 'HDFC Bank';
    if (upper.contains('SBI')) return 'State Bank of India';
    if (upper.contains('ICICI')) return 'ICICI Bank';
    if (upper.contains('PAYTM')) return 'Paytm Payments Bank';
    if (upper.contains('AXIS')) return 'Axis Bank';
    if (upper.contains('KOTAK')) return 'Kotak Mahindra Bank';
    if (upper.contains('BOI')) return 'Bank of India';
    if (upper.contains('CANARA') || upper.contains('CANBNK')) return 'Canara Bank';
    if (upper.contains('PNB')) return 'Punjab National Bank';
    if (upper.contains('UNION')) return 'Union Bank of India';
    if (upper.contains('INDUS')) return 'IndusInd Bank';
    if (upper.contains('YESB')) return 'Yes Bank';
    if (upper.contains('IDBI')) return 'IDBI Bank';
    if (upper.contains('FEDB')) return 'Federal Bank';
    if (upper.contains('RBL')) return 'RBL Bank';
    if (upper.contains('BOB') || upper.contains('BARODA')) return 'Bank of Baroda';
    if (upper.contains('IOB')) return 'Indian Overseas Bank';
    if (upper.contains('UCO')) return 'UCO Bank';
    if (upper.contains('GPAY')) return 'Google Pay';
    if (upper.contains('PHONEPE')) return 'PhonePe';
    return senderHandle.isNotEmpty ? senderHandle : 'Bank Account';
  }

  /// Extracts merchant name from outgoing debit SMS patterns (e.g., "spent at X", "paid to Y", "to VPA Z").
  String? _extractMerchantFromDebitSms(String text) {
    // "spent at [Merchant]" or "paid to [Merchant]"
    final spentReg = RegExp(
      r'(?:spent at|paid to|sent to|transfer to|payment to)\s+([A-Za-z0-9\s&.\-_]{2,30}?)(?:\s+on|\s+at|\s+via|\s+ref|\.|$)',
      caseSensitive: false,
    );
    final match = spentReg.firstMatch(text);
    if (match != null && match.group(1) != null) {
      final name = match.group(1)!.trim();
      if (name.isNotEmpty && !name.toLowerCase().contains('rs') && !name.toLowerCase().contains('inr')) {
        return name;
      }
    }

    // "VPA [handle]"
    final vpaReg = RegExp(r'vpa\s+([A-Za-z0-9.\-_@]{3,30})', caseSensitive: false);
    final vpaMatch = vpaReg.firstMatch(text);
    if (vpaMatch != null && vpaMatch.group(1) != null) {
      return vpaMatch.group(1)!.trim();
    }

    return null;
  }
}
