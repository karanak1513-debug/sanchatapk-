import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sms_upi_parser_engine.dart';

/// Monitors clipboard when enabled to auto-detect incoming bank SMS or UPI receipts
class ClipboardParserService {
  static final ClipboardParserService _instance = ClipboardParserService._internal();
  factory ClipboardParserService() => _instance;
  ClipboardParserService._internal();

  final _detectedSmsStreamController = StreamController<ParsedFinancialSms>.broadcast();
  Stream<ParsedFinancialSms> get onFinancialSmsDetected => _detectedSmsStreamController.stream;

  final Set<String> _processedSnippets = {};
  String _lastCheckedText = '';

  /// Inspects system clipboard and returns parsed financial SMS if detected
  Future<ParsedFinancialSms?> checkClipboard({bool isEnabled = true}) async {
    if (!isEnabled) return null;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty || text == _lastCheckedText) return null;

      _lastCheckedText = text;

      // Anti-duplicate protection across sessions
      final snippetHash = '${text.length}_${text.hashCode}';
      if (_processedSnippets.contains(snippetHash)) return null;

      final parsed = SmsUpiParserEngine.parse(text: text);
      if (parsed != null) {
        _processedSnippets.add(snippetHash);
        _detectedSmsStreamController.add(parsed);
        debugPrint('ClipboardParserService: Detected financial event from clipboard: ${parsed.merchant} ₹${parsed.amount}');
        return parsed;
      }
    } catch (e) {
      debugPrint('ClipboardParserService note: $e');
    }
    return null;
  }

  void markAsProcessed(String rawText) {
    _processedSnippets.add('${rawText.length}_${rawText.hashCode}');
  }
}
