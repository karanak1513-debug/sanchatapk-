import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../providers/sanchay_provider.dart';

/// Result details of a statement export operation.
class StatementExportResult {
  final bool success;
  final String filename;
  final String filePath;
  final int recordCount;
  final int byteSize;
  final String? errorMessage;

  const StatementExportResult({
    required this.success,
    required this.filename,
    required this.filePath,
    required this.recordCount,
    required this.byteSize,
    this.errorMessage,
  });

  String get formattedSize {
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// "Sanchay Official Statement" CSV / Excel Exporter.
///
/// Generates a formatted financial statement compatible with Microsoft Excel
/// and Google Sheets, compliant with RFC 4180 standard and shareable natively.
class StatementService {
  static final StatementService _instance = StatementService._internal();
  factory StatementService() => _instance;
  StatementService._internal();

  /// Generates the raw CSV string representation of the Sanchay Financial Statement.
  String generateStatementCsv({
    required List<Transaction> transactions,
    required String displayName,
    required String userHandle,
    required double netLiquidity,
  }) {
    // 1. Sort transactions chronologically (oldest to newest)
    final sortedTxs = List<Transaction>.from(transactions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final now = DateTime.now();
    final generatedAtStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);
    final userIdentifier = userHandle.isNotEmpty
        ? '$displayName (@$userHandle)'
        : displayName;

    final List<List<dynamic>> csvRows = [];

    // 2. Header Metadata Block (Rows 1-5)
    // Row 1: SANCHAY FINANCIAL INTELLIGENCE STATEMENT
    csvRows.add(['SANCHAY FINANCIAL INTELLIGENCE STATEMENT', '', '', '', '', '', '']);
    // Row 2: Account Holder:, [User Display Name] (@[User Handle])
    csvRows.add(['Account Holder:', userIdentifier, '', '', '', '', '']);
    // Row 3: Statement Generated:, [Current Date & Time]
    csvRows.add(['Statement Generated:', generatedAtStr, '', '', '', '', '']);
    // Row 4: Net Cash Liquidity:, ₹[Current Liquidity Balance]
    csvRows.add(['Net Cash Liquidity:', '₹${netLiquidity.toStringAsFixed(2)}', '', '', '', '', '']);
    // Row 5: --- Empty Row ---
    csvRows.add(['', '', '', '', '', '', '']);

    // 3. Column Headers
    csvRows.add([
      'Date & Time',
      'Transaction ID / Ref',
      'Description / Merchant',
      'Category',
      'Type (Credit/Debit)',
      'Amount (₹)',
      'Source (UPI/SMS/Vault)',
    ]);

    // 4. Map Every Transaction
    for (final tx in sortedTxs) {
      final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(tx.timestamp);
      final txRef = (tx.referenceNumber != null && tx.referenceNumber!.isNotEmpty)
          ? tx.referenceNumber!
          : tx.id;
      final merchant = tx.merchant;
      final category = tx.category;

      // Type determination
      final String typeDisplay;
      if (tx.isVaultDeposit) {
        typeDisplay = 'Vault Allocation';
      } else if (tx.isCredit) {
        typeDisplay = 'Credit';
      } else {
        typeDisplay = 'Debit';
      }

      // Format Credit as positive (+500.00) and Debit as negative (-200.00)
      final String amountDisplay;
      if (tx.isVaultDeposit) {
        amountDisplay = '₹${tx.amount.abs().toStringAsFixed(2)}';
      } else if (tx.isCredit) {
        amountDisplay = '+${tx.amount.abs().toStringAsFixed(2)}';
      } else {
        amountDisplay = '-${tx.amount.abs().toStringAsFixed(2)}';
      }

      // Source determination
      final String sourceDisplay;
      if (tx.isVaultDeposit) {
        sourceDisplay = 'Vault';
      } else if (tx.channel.isNotEmpty) {
        sourceDisplay = tx.channel;
      } else {
        sourceDisplay = tx.source.isNotEmpty ? tx.source : 'UPI';
      }

      csvRows.add([
        dateTimeStr,
        txRef,
        merchant,
        category,
        typeDisplay,
        amountDisplay,
        sourceDisplay,
      ]);
    }

    return const ListToCsvConverter().convert(csvRows);
  }

  /// Exports the statement to a local CSV file and triggers native system share.
  Future<StatementExportResult> exportAndShareStatement({
    required SanchayProvider provider,
  }) async {
    try {
      final transactions = provider.allTransactions;
      final sortedTxs = List<Transaction>.from(transactions)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Calculate start and end dates for file name
      final DateFormat fileDateFmt = DateFormat('yyyy-MM-dd');
      final String startDate;
      final String endDate;

      if (sortedTxs.isNotEmpty) {
        startDate = fileDateFmt.format(sortedTxs.first.timestamp);
        endDate = fileDateFmt.format(sortedTxs.last.timestamp);
      } else {
        final today = fileDateFmt.format(DateTime.now());
        startDate = today;
        endDate = today;
      }

      final fileName = 'Sanchay_Statement_${startDate}_to_$endDate.csv';

      final displayName = provider.userName.isNotEmpty
          ? provider.userName
          : 'Sanchay User';
      final userHandle = provider.userHandle;
      final netLiquidity = provider.savedAmount;

      final csvString = generateStatementCsv(
        transactions: transactions,
        displayName: displayName,
        userHandle: userHandle,
        netLiquidity: netLiquidity,
      );

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);

      final bytes = await file.length();
      debugPrint('StatementService: Wrote $bytes bytes to ${file.path}');

      // Trigger system native file share
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: 'My Sanchay Financial Statement',
        subject: 'Sanchay Official Financial Statement ($startDate to $endDate)',
      );

      return StatementExportResult(
        success: true,
        filename: fileName,
        filePath: file.path,
        recordCount: transactions.length,
        byteSize: bytes,
      );
    } catch (e, stack) {
      debugPrint('StatementService: Error exporting statement: $e\n$stack');
      return StatementExportResult(
        success: false,
        filename: '',
        filePath: '',
        recordCount: 0,
        byteSize: 0,
        errorMessage: e.toString(),
      );
    }
  }
}
