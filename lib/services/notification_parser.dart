/// Single source of truth for Indian UPI & Banking Notification Direction Classification.
/// Accurately detects Inflow (Credit/Income) vs Outflow (Debit/Expense).
library;

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
  });
}

double? _parseAmountFromMatch(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), '').trim();
  final val = double.tryParse(cleaned);
  if (val != null && val > 0) return val;
  return null;
}

ParsedTransaction? parseUpiMessage(String text, [String? senderAddress]) {
  if (text.trim().isEmpty) return null;

  // Normalize excessive whitespace
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final lower = normalized.toLowerCase();

  // Extract reference number, bank, account, balance
  final referenceNumber = NotificationParser.extractReferenceNumber(normalized);
  final detectedBank = NotificationParser.extractBankOrSender(normalized, senderAddress: senderAddress);
  final accountLast4 = NotificationParser.extractAccountLast4(normalized);
  final balanceAfter = NotificationParser.extractBalanceAfter(normalized);

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
  if (walletInflowMatch != null && (lower.contains('wallet') || lower.contains('phonepe'))) {
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
      r"(?:you've|you\s+have)?\s*paid\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)",
      caseSensitive: false,
    );
    final walletPaymentMatch = walletPaymentRegex.firstMatch(normalized);
    if (walletPaymentMatch != null && (lower.contains('wallet') || lower.contains('phonepe'))) {
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

  // PRIORITY 3: Bank / UPI Credit ("credited by ...")
  // e.g., "A/c XX4445 credited by Rs. 1700.00 on 08102026 via UPI from PhonePe via Ref No. 628146965625. -CBol"
  if (extractedAmount == null) {
    final creditedByRegex = RegExp(
      r'credited\s+by\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final creditedMatch = creditedByRegex.firstMatch(normalized);
    if (creditedMatch != null) {
      final amt = _parseAmountFromMatch(creditedMatch.group(1));
      if (amt != null) {
        extractedAmount = amt;
        isCredit = true;
        defaultCategory = 'Received Payment';
        senderOrMerchant = detectedBank ?? 'Bank Credit';
      }
    }
  }

  // PRIORITY 4: Bank / UPI Debit ("debited by ...")
  // e.g., "A/c XX4445 debited by Rs. 300.00 via UPI with Ref No. ... -CBol"
  if (extractedAmount == null) {
    final debitedByRegex = RegExp(
      r'debited\s+by\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final debitedMatch = debitedByRegex.firstMatch(normalized);
    if (debitedMatch != null) {
      final amt = _parseAmountFromMatch(debitedMatch.group(1));
      if (amt != null) {
        extractedAmount = amt;
        isCredit = false;
        defaultCategory = 'General';
        senderOrMerchant = detectedBank ?? 'Bank Payment';
      }
    }
  }

  // PRIORITY 5: General Fallback Amount & Polarity Engine
  if (extractedAmount == null) {
    // Detect Polarity
    if (lower.contains('paid you') ||
        lower.contains('received') ||
        lower.contains('credited') ||
        lower.contains('cashback') ||
        lower.contains('refund') ||
        lower.contains('added to account') ||
        lower.contains('added to your account') ||
        lower.contains('money received')) {
      isCredit = true;
    } else if (lower.contains('paid to') ||
               lower.contains('debited') ||
               lower.contains('sent to') ||
               lower.contains('spent at') ||
               lower.contains('transfer to') ||
               lower.contains('transferred to') ||
               lower.contains('payment to')) {
      isCredit = false;
    } else if (lower.contains('paid') && !lower.contains('paid you')) {
      isCredit = false;
    }

    // Extract amount
    final generalAmountRegex = RegExp(
      r'(?:(?:rs|inr|₹)\.?\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs|inr|₹))',
      caseSensitive: false,
    );
    final matches = generalAmountRegex.allMatches(normalized).toList();
    for (final m in matches) {
      final rawStr = (m.group(1) ?? m.group(2) ?? '');
      final amt = _parseAmountFromMatch(rawStr);
      if (amt == null) continue;

      // Skip balance if matched
      if (balanceAfter != null && (amt - balanceAfter).abs() < 0.01 && matches.length > 1) {
        continue;
      }
      extractedAmount = amt;
      break;
    }
  }

  if (extractedAmount == null || extractedAmount <= 0) return null;

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
  /// Backward-compatible alias calling parseUpiMessage
  static ParsedTransaction? parse(String text) => parseUpiMessage(text);

  /// Keyword Classification Engine
  static bool isCreditTransaction(String text) {
    final parsed = parseUpiMessage(text);
    if (parsed != null) return parsed.isCredit;

    final lower = text.toLowerCase();
    if (lower.contains('withdrawal of') && (lower.contains('wallet') || lower.contains('account'))) {
      return true;
    }
    if (lower.contains('paid you') ||
        lower.contains('received') ||
        lower.contains('credited') ||
        lower.contains('cashback') ||
        lower.contains('refund') ||
        lower.contains('added to account') ||
        lower.contains('added to your account') ||
        lower.contains('money received')) {
      return true;
    }

    if (lower.contains('paid to') ||
        lower.contains('debited') ||
        lower.contains('sent to') ||
        lower.contains('spent at') ||
        lower.contains('payment to') ||
        lower.contains('transferred to')) {
      return false;
    }

    if (lower.contains('paid') && !lower.contains('paid you')) {
      return false;
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
      if (lower.contains('withdrawal of') && lower.contains('wallet')) return 'WALLET_INFLOW';
      if (lower.contains('cashback')) return 'Cashback';
      if (lower.contains('refund')) return 'Refund';
      if (lower.contains('salary')) return 'Salary';
      return 'Received Payment';
    } else {
      if (lower.contains('wallet')) return 'WALLET_PAYMENT';
      if (lower.contains('swiggy') || lower.contains('zomato')) return 'Food & Dining';
      if (lower.contains('uber') || lower.contains('ola')) return 'Transportation';
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
    final suffixTagMatch = RegExp(r'(?:^|[.\s])-([A-Za-z0-9]{3,10})(?:\s*|\.|\n|$)', caseSensitive: false).firstMatch(text);
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
    return handle;
  }

  /// Extracts account last 4 digits
  static String? extractAccountLast4(String text) {
    final reg = RegExp(r'(?:a\/c|acct|account|card)\s*(?:no\.?|ending)?\s*(?:[xX\*]+)?([0-9]{3,4})', caseSensitive: false);
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
      if (name.isNotEmpty && !name.toLowerCase().contains('rs') && !name.toLowerCase().contains('inr')) {
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
