/// Single source of truth for Indian UPI & Banking Notification Direction Classification.
/// Defensive parser that strictly rejects marketing/promotional SMS and verifies
/// legitimate transactional headers, transaction phrases, and account/reference evidence.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

class ParsedTransaction {
  final double amount;
  final String senderOrMerchant;
  final bool isCredit;
  final String rawText;
  final String? referenceNumber;
  final String? category;
  final String? subtype;
  final String? bank;
  final String? accountLast4;
  final double? balanceAfter;
  final String fingerprint;

  ParsedTransaction({
    required this.amount,
    required this.senderOrMerchant,
    required this.isCredit,
    required this.rawText,
    this.referenceNumber,
    this.category,
    this.subtype,
    this.bank,
    this.accountLast4,
    this.balanceAfter,
    String? fingerprint,
  }) : fingerprint = fingerprint ??
            NotificationParser.generateFingerprint(
              bankOrSender: bank ?? senderOrMerchant,
              referenceNumber: referenceNumber,
              amount: amount,
              isCredit: isCredit,
              accountLast4: accountLast4,
            );
}

double? _parseAmountFromMatch(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), '').trim();
  final val = double.tryParse(cleaned);
  if (val != null && val > 0) return val;
  return null;
}

/// Defensive parser for SMS / App Notifications
ParsedTransaction? parseUpiMessage(String text, [String? senderAddress]) {
  if (text.trim().isEmpty) return null;

  // Normalize excessive whitespace
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final lower = normalized.toLowerCase();

  // =========================================================================
  // RULE 1 — STRICT TRANSACTION SENDER FILTER
  // Only process messages from legitimate transactional/financial headers.
  // =========================================================================
  if (!NotificationParser.isLegitimateSender(senderAddress, normalized)) {
    return null;
  }

  // =========================================================================
  // RULE 2 — MARKETING/SPAM REJECTION
  // Reject the message if it contains marketing/promotional indicators.
  // =========================================================================
  if (NotificationParser.isMarketingOrSpam(normalized)) {
    return null;
  }

  // =========================================================================
  // RULE 3 & RULE 4 — STRICT TRANSACTION LANGUAGE & REFERENCE/ACCOUNT EVIDENCE
  // Must contain strong transaction phrases AND reference/account verification.
  // =========================================================================
  final referenceNumber = NotificationParser.extractReferenceNumber(normalized);
  final detectedBank = NotificationParser.extractBankOrSender(normalized, senderAddress: senderAddress);
  final accountLast4 = NotificationParser.extractAccountLast4(normalized);
  final balanceAfter = NotificationParser.extractBalanceAfter(normalized);

  final hasAccountEvidence = accountLast4 != null ||
      RegExp(r'\b(?:a/c|account|acct|card)\b', caseSensitive: false).hasMatch(normalized);
  final hasReferenceEvidence = referenceNumber != null ||
      RegExp(r'\b(?:ref(?:\s*no)?|rrn|utr|txn\s*(?:id)?)\b', caseSensitive: false).hasMatch(normalized);

  double? extractedAmount;
  bool? isCredit;
  String? subtype;
  String? defaultCategory;
  String? senderOrMerchant;

  // PRIORITY 1: PhonePe Wallet Inflow / Withdrawal to Bank
  // e.g., "Withdrawal of Rs.1700 from your PhonePe wallet to your Central Bank Of India account has been successful."
  final walletInflowRegex = RegExp(
    r'withdrawal\s+of\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  final walletInflowMatch = walletInflowRegex.firstMatch(normalized);
  if (walletInflowMatch != null &&
      (lower.contains('wallet') || lower.contains('phonepe')) &&
      (lower.contains('account') || hasAccountEvidence)) {
    final amt = _parseAmountFromMatch(walletInflowMatch.group(1));
    if (amt != null) {
      extractedAmount = amt;
      isCredit = true;
      subtype = 'WALLET_INFLOW';
      defaultCategory = 'WALLET_INFLOW';
      senderOrMerchant = detectedBank ?? 'PhonePe Wallet Inflow';
    }
  }

  // PRIORITY 2: PhonePe Wallet Payment / Outflow
  // e.g., "You've paid Rs. 30 via PhonePe wallet. Remaining balance: Rs. 2502."
  if (extractedAmount == null) {
    final walletPaymentRegex = RegExp(
      r"(?:you've|you\s+have)?\s*paid\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s+via\s+phonepe\s+wallet",
      caseSensitive: false,
    );
    final walletPaymentMatch = walletPaymentRegex.firstMatch(normalized);
    if (walletPaymentMatch != null) {
      final amt = _parseAmountFromMatch(walletPaymentMatch.group(1));
      if (amt != null) {
        extractedAmount = amt;
        isCredit = false;
        subtype = 'WALLET_PAYMENT';
        defaultCategory = 'WALLET_PAYMENT';
        senderOrMerchant = detectedBank ?? 'PhonePe Wallet';
      }
    }
  }

  // PRIORITY 3: Strict Bank / UPI Credit
  // "credited by ...", "credited to ...", "received from ..."
  // e.g., "A/c XX4445 credited by Rs. 1700.00 on 08102026 via UPI from PhonePe via Ref No. 628146965625. -CBol"
  // e.g., "Rs.1000 credited to A/c XX1234. Ref No 987654."
  if (extractedAmount == null) {
    // 3a. "credited by [amount]"
    final creditedByRegex = RegExp(
      r'credited\s+by\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final creditedByMatch = creditedByRegex.firstMatch(normalized);
    if (creditedByMatch != null) {
      final amt = _parseAmountFromMatch(creditedByMatch.group(1));
      if (amt != null) {
        extractedAmount = amt;
        isCredit = true;
        defaultCategory = 'Received Payment';
        senderOrMerchant = detectedBank ?? 'Bank Credit';
      }
    }

    // 3b. "[amount] credited to [A/c ...]"
    if (extractedAmount == null) {
      final creditedToRegex = RegExp(
        r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s+credited\s+to\s+(?:a/c|account)',
        caseSensitive: false,
      );
      final creditedToMatch = creditedToRegex.firstMatch(normalized);
      if (creditedToMatch != null) {
        final amt = _parseAmountFromMatch(creditedToMatch.group(1));
        if (amt != null) {
          extractedAmount = amt;
          isCredit = true;
          defaultCategory = 'Received Payment';
          senderOrMerchant = detectedBank ?? 'Bank Credit';
        }
      }
    }

    // 3c. "received from [source]" with reference/account evidence
    if (extractedAmount == null) {
      final receivedFromRegex = RegExp(
        r'received\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s+from',
        caseSensitive: false,
      );
      final receivedMatch = receivedFromRegex.firstMatch(normalized);
      if (receivedMatch != null && (hasAccountEvidence || hasReferenceEvidence)) {
        final amt = _parseAmountFromMatch(receivedMatch.group(1));
        if (amt != null) {
          extractedAmount = amt;
          isCredit = true;
          defaultCategory = 'Received Payment';
          senderOrMerchant = detectedBank ?? 'Incoming Transfer';
        }
      }
    }
  }

  // PRIORITY 4: Strict Bank / UPI Debit
  // "debited by ...", "debited from ...", "paid to ...", "sent to ..."
  // e.g., "A/c XX4445 debited by Rs. 300.00 via UPI with Ref No. ... -CBol"
  // e.g., "Your A/c XX1234 has been debited by Rs.500. UPI Ref 123456789."
  if (extractedAmount == null) {
    // 4a. "debited by [amount]" or "debited by rs. [amount]"
    final debitedByRegex = RegExp(
      r'debited\s+by\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final debitedByMatch = debitedByRegex.firstMatch(normalized);
    if (debitedByMatch != null) {
      final amt = _parseAmountFromMatch(debitedByMatch.group(1));
      if (amt != null) {
        extractedAmount = amt;
        isCredit = false;
        defaultCategory = 'General';
        senderOrMerchant = detectedBank ?? 'Bank Payment';
      }
    }

    // 4b. "[amount] debited from [A/c ...]"
    if (extractedAmount == null) {
      final debitedFromRegex = RegExp(
        r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s+debited\s+from\s+(?:a/c|account)',
        caseSensitive: false,
      );
      final debitedFromMatch = debitedFromRegex.firstMatch(normalized);
      if (debitedFromMatch != null) {
        final amt = _parseAmountFromMatch(debitedFromMatch.group(1));
        if (amt != null) {
          extractedAmount = amt;
          isCredit = false;
          defaultCategory = 'General';
          senderOrMerchant = detectedBank ?? 'Bank Payment';
        }
      }
    }

    // 4c. "paid to [merchant] [amount]" with reference/account evidence
    if (extractedAmount == null) {
      final paidToRegex = RegExp(
        r'paid\s+to\s+([A-Za-z0-9\s&]{2,30})?\s*(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      );
      final paidToMatch = paidToRegex.firstMatch(normalized);
      if (paidToMatch != null && (hasAccountEvidence || hasReferenceEvidence)) {
        final amt = _parseAmountFromMatch(paidToMatch.group(2));
        if (amt != null) {
          extractedAmount = amt;
          isCredit = false;
          defaultCategory = 'General';
          senderOrMerchant = paidToMatch.group(1)?.trim() ?? detectedBank ?? 'Merchant Payment';
        }
      }
    }

    // 4d. "sent to [recipient] [amount]" with reference/account evidence
    if (extractedAmount == null) {
      final sentToRegex = RegExp(
        r'sent\s+to\s+([A-Za-z0-9\s&]{2,30})?\s*(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      );
      final sentToMatch = sentToRegex.firstMatch(normalized);
      if (sentToMatch != null && (hasAccountEvidence || hasReferenceEvidence)) {
        final amt = _parseAmountFromMatch(sentToMatch.group(2));
        if (amt != null) {
          extractedAmount = amt;
          isCredit = false;
          defaultCategory = 'General';
          senderOrMerchant = sentToMatch.group(1)?.trim() ?? detectedBank ?? 'Transfer';
        }
      }
    }
  }

  // RULE 3 & RULE 4 ENFORCEMENT:
  // If neither strong transaction language NOR reference/account evidence exists:
  // RETURN NULL immediately.
  if (extractedAmount == null) {
    return null;
  }

  // Must have at least account OR reference evidence OR valid verified wallet transaction
  if (!hasAccountEvidence && !hasReferenceEvidence && subtype == null) {
    return null;
  }

  // Amount must be positive and non-zero
  if (extractedAmount <= 0) return null;

  final resolvedIsCredit = isCredit ?? false;
  senderOrMerchant ??= (resolvedIsCredit
      ? (NotificationParser.extractPayerFromPaidYou(normalized) ?? (detectedBank ?? 'Incoming Transfer'))
      : (detectedBank ?? 'Merchant Payment'));

  return ParsedTransaction(
    amount: extractedAmount,
    senderOrMerchant: senderOrMerchant,
    isCredit: resolvedIsCredit,
    rawText: text,
    referenceNumber: referenceNumber,
    category: defaultCategory ?? NotificationParser.inferCategory(normalized, resolvedIsCredit),
    subtype: subtype,
    bank: detectedBank,
    accountLast4: accountLast4,
    balanceAfter: balanceAfter,
  );
}

class NotificationParser {
  /// Legitimate financial institution and payment gateway headers (case-insensitive)
  static const List<String> legitimateFinancialHeaders = [
    'BANK',
    'CENTBK',
    'HDFC',
    'SBI',
    'ICICI',
    'AXIS',
    'PNB',
    'PAYTM',
    'PHONEPE',
    'PHONPE',
    'GPAY',
    'CBOL',
    'CBIN',
    'KOTAK',
    'BOB',
    'BARODA',
    'CANARA',
    'CANBNK',
    'UNION',
    'INDUS',
    'YESB',
    'IDBI',
    'FEDB',
    'RBL',
    'IOB',
    'UCO',
    'CITI',
    'HSBC',
    'STANDARD',
    'SCB',
    'BOI',
  ];

  /// Promotional / Marketing rejection keywords
  static final List<RegExp> marketingPatterns = [
    RegExp(r'\btrial\b', caseSensitive: false),
    RegExp(r'\boffers?\b', caseSensitive: false),
    RegExp(r'\bplans?\s+starts?\s+at\b', caseSensitive: false),
    RegExp(r'\brecharge\b', caseSensitive: false),
    RegExp(r'\bvouchers?\b', caseSensitive: false),
    RegExp(r'\bcashbacks?\b', caseSensitive: false),
    RegExp(r'\bcoupons?\b', caseSensitive: false),
    RegExp(r'\bcongratulations?\b', caseSensitive: false),
    RegExp(r'\blimited\s+time\b', caseSensitive: false),
    RegExp(r'\bsubscriptions?\b', caseSensitive: false),
    RegExp(r'\bsubscribe\b', caseSensitive: false),
    RegExp(r'\bdiscounts?\b', caseSensitive: false),
    RegExp(r'\bpromos?\b', caseSensitive: false),
    RegExp(r'\bpromotions?\b', caseSensitive: false),
    RegExp(r'\bsales?\b', caseSensitive: false),
    RegExp(r'\bwins?\b', caseSensitive: false),
    RegExp(r'\bwinners?\b', caseSensitive: false),
    RegExp(r'\brewards?\b', caseSensitive: false),
    RegExp(r'\bbonus(es)?\b', caseSensitive: false),
    RegExp(r'\bfree\b', caseSensitive: false),
    RegExp(r'\bdeals?\b', caseSensitive: false),
    RegExp(r'/month\b', caseSensitive: false),
    RegExp(r'\bper\s+month\b', caseSensitive: false),
  ];

  /// RULE 1: STRICT TRANSACTION SENDER FILTER
  static bool isLegitimateSender(String? senderAddress, String text) {
    if (senderAddress != null && senderAddress.trim().isNotEmpty) {
      final cleanSender = senderAddress.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final isKnown = legitimateFinancialHeaders.any((header) => cleanSender.contains(header));
      if (!isKnown) {
        return false;
      }
      return true;
    }

    // If senderAddress is not explicitly provided (e.g. unit tests or local notifications),
    // check if the text contains legitimate financial headers, banking networks, or verified account headers.
    final upperText = text.toUpperCase();
    if (legitimateFinancialHeaders.any((header) => upperText.contains(header))) {
      return true;
    }
    final hasBankingNetwork = RegExp(r'\b(?:UPI|IMPS|NEFT|RTGS)\b', caseSensitive: false).hasMatch(text);
    final hasAccountHeader = RegExp(r'\ba/c\s*(?:no\.?|xx|\*+|\d+)', caseSensitive: false).hasMatch(text);
    return hasBankingNetwork || hasAccountHeader;
  }

  /// RULE 2: MARKETING / SPAM REJECTION
  static bool isMarketingOrSpam(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final pattern in marketingPatterns) {
      if (pattern.hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  /// RULE 7: Deterministic Transaction Fingerprint Generator
  static String generateFingerprint({
    required String bankOrSender,
    required double amount,
    required bool isCredit,
    String? referenceNumber,
    String? accountLast4,
  }) {
    final cleanBank = bankOrSender.trim().toUpperCase();
    final cleanRef = (referenceNumber != null && referenceNumber.trim().isNotEmpty)
        ? referenceNumber.trim().toUpperCase()
        : 'NOREF';
    final amtFormatted = amount.toStringAsFixed(2);
    final direction = isCredit ? 'CR' : 'DR';
    final cleanAcc = (accountLast4 != null && accountLast4.trim().isNotEmpty)
        ? accountLast4.trim().toUpperCase()
        : 'NOACC';

    final rawKey = 'SANCHAT_TX:$cleanBank:$cleanRef:$amtFormatted:$direction:$cleanAcc';
    return sha256.convert(utf8.encode(rawKey)).toString();
  }

  /// Backward-compatible alias calling parseUpiMessage
  static ParsedTransaction? parse(String text, [String? senderAddress]) =>
      parseUpiMessage(text, senderAddress);

  /// Keyword Classification Engine
  static bool isCreditTransaction(String text) {
    final parsed = parseUpiMessage(text);
    if (parsed != null) return parsed.isCredit;

    final lower = text.toLowerCase();
    if (isMarketingOrSpam(text)) return false;

    if (lower.contains('withdrawal of') &&
        (lower.contains('wallet') || lower.contains('account'))) {
      return true;
    }
    if (lower.contains('credited by') ||
        lower.contains('credited to') ||
        lower.contains('received from') ||
        lower.contains('paid you')) {
      return true;
    }
    return false;
  }

  /// Categorizes transaction type: 'income' for credits, 'expense' for debits.
  static String classifyType(String text) {
    return isCreditTransaction(text) ? 'income' : 'expense';
  }

  /// Suggests category based on direction and content
  static String inferCategory(String text, [bool? isCredit]) {
    final credit = isCredit ?? isCreditTransaction(text);
    final lower = text.toLowerCase();
    if (credit) {
      if (lower.contains('withdrawal of') && lower.contains('wallet')) {
        return 'WALLET_INFLOW';
      }
      if (lower.contains('salary')) return 'Salary';
      return 'Received Payment';
    } else {
      if (lower.contains('wallet')) return 'WALLET_PAYMENT';
      if (lower.contains('swiggy') || lower.contains('zomato')) {
        return 'Food & Dining';
      }
      if (lower.contains('uber') || lower.contains('ola')) {
        return 'Transportation';
      }
    }
    return 'General';
  }

  /// Extracts transaction reference number (e.g., Ref No. 628146965625, UPI Ref: 628146965625)
  static String? extractReferenceNumber(String text) {
    final refPattern = RegExp(
      r'(?:(?:upi\s+)?(?:ref(?:\.?|erence)?(?:\s*(?:no\.?|:|\s))\s*)|(?:rrn|utr|txn\s*(?:id)?)\s*[:.\s]\s*)([A-Za-z0-9]{6,25})',
      caseSensitive: false,
    );
    final match = refPattern.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.replaceAll(RegExp(r'\.+$'), '').trim();
    }
    return null;
  }

  /// Extracts sender / bank / source information generically
  static String? extractBankOrSender(String text, {String? senderAddress}) {
    if (senderAddress != null && senderAddress.isNotEmpty) {
      final resolved = resolveBankName(senderAddress);
      if (resolved != senderAddress) return resolved;
    }

    final lower = text.toLowerCase();

    // Suffix tag like "-CBol" or "-HDFCBK" at end of message or clause
    final suffixTagMatch = RegExp(
      r'(?:^|[.\s])-([A-Za-z0-9]{3,10})(?:\s*|\.|\n|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (suffixTagMatch != null && suffixTagMatch.group(1) != null) {
      final tag = suffixTagMatch.group(1)!.trim();
      final resolved = resolveBankName(tag);
      if (resolved.isNotEmpty) return resolved;
    }

    if (lower.contains('central bank of india') ||
        lower.contains('cbol') ||
        lower.contains('cbin') ||
        lower.contains('centbk')) {
      return 'Central Bank of India';
    }
    if (lower.contains('phonepe wallet') || lower.contains('phonepe')) {
      return 'PhonePe';
    }
    if (lower.contains('google pay') || lower.contains('gpay')) {
      return 'Google Pay';
    }
    if (lower.contains('paytm')) {
      return 'Paytm';
    }
    if (lower.contains('state bank of india') || lower.contains('sbi')) {
      return 'State Bank of India';
    }
    if (lower.contains('hdfc')) {
      return 'HDFC Bank';
    }
    if (lower.contains('icici')) {
      return 'ICICI Bank';
    }
    if (lower.contains('axis bank') || lower.contains('axis')) {
      return 'Axis Bank';
    }
    if (lower.contains('kotak')) {
      return 'Kotak Mahindra Bank';
    }
    if (lower.contains('bank of baroda') || lower.contains('bob')) {
      return 'Bank of Baroda';
    }
    if (lower.contains('punjab national bank') || lower.contains('pnb')) {
      return 'Punjab National Bank';
    }
    if (lower.contains('canara') || lower.contains('canbnk')) {
      return 'Canara Bank';
    }
    if (lower.contains('union bank')) {
      return 'Union Bank of India';
    }

    if (senderAddress != null && senderAddress.trim().isNotEmpty) {
      return senderAddress.trim();
    }
    return null;
  }

  /// Normalizes banking sender handles to official institution names
  static String resolveBankName(String handle) {
    final upper = handle.toUpperCase();
    if (upper.contains('CBOL') || upper.contains('CBIN') || upper.contains('CENTBK')) {
      return 'Central Bank of India';
    }
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
    if (upper.contains('PHONEPE') || upper.contains('PHONPE')) return 'PhonePe';
    return handle;
  }

  /// Extracts account last 4 digits
  static String? extractAccountLast4(String text) {
    final reg = RegExp(
      r'(?:a\/c|acct|account|card)\s*(?:no\.?|ending)?\s*(?:[xX\*]+)?([0-9]{3,4})',
      caseSensitive: false,
    );
    final match = reg.firstMatch(text);
    return match?.group(1);
  }

  /// Extracts available / remaining balance after transaction
  static double? extractBalanceAfter(String text) {
    final balPattern = RegExp(
      r'(?:avl(?:[\.\s]+)?bal(?:ance)?|bal(?:ance)?|rem(?:aining)?[\.\s]+bal|clear[\.\s]+bal)\s*(?:is|:|-)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final match = balPattern.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return _parseAmountFromMatch(match.group(1));
    }
    return null;
  }

  /// Extracts payer name if notification format is "[Payer] paid you"
  static String? extractPayerFromPaidYou(String text) {
    final reg = RegExp(
      r'(?:^|[.:\n]|info:\s*|ref:\s*)\s*([A-Za-z0-9\s&]{2,30})\s+(?:paid you|sent you)',
      caseSensitive: false,
    );
    final match = reg.firstMatch(text.trim());
    if (match != null && match.group(1) != null) {
      final name = match.group(1)!.trim();
      if (name.isNotEmpty &&
          !name.toLowerCase().contains('rs') &&
          !name.toLowerCase().contains('inr')) {
        return name;
      }
    }

    final fromReg = RegExp(
      r'(?:received\s+(?:rs\.?|inr|₹)?\s*[\d,.]*\s*from)\s+([A-Za-z0-9\s&]{2,30})',
      caseSensitive: false,
    );
    final fromMatch = fromReg.firstMatch(text);
    if (fromMatch != null && fromMatch.group(1) != null) {
      final name = fromMatch.group(1)!.trim();
      if (name.isNotEmpty) return name;
    }

    return null;
  }
}
