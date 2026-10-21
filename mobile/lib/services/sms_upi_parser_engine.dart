import '../models/transaction.dart';
import 'notification_parser.dart';

/// Structured result from parsing a financial SMS or UPI notification
class ParsedFinancialSms {
  final double amount;
  final String type; // 'debit' or 'credit'
  final String merchant;
  final String category;
  final String channel; // 'UPI' | 'CARD' | 'BANK' | 'CASH'
  final String source; // 'HDFC Bank', 'Google Pay', 'SBI', etc.
  final String? accountNumberLast4;
  final String? referenceNumber;
  final double? balanceAfter;
  final double confidence;
  final String rawText;
  final DateTime timestamp;

  const ParsedFinancialSms({
    required this.amount,
    required this.type,
    required this.merchant,
    required this.category,
    required this.channel,
    required this.source,
    this.accountNumberLast4,
    this.referenceNumber,
    this.balanceAfter,
    this.confidence = 1.0,
    required this.rawText,
    required this.timestamp,
  });

  bool get isDebit => type.toLowerCase() == 'debit' || type.toLowerCase() == 'expense';
  bool get isCredit => type.toLowerCase() == 'credit' || type.toLowerCase() == 'income';
  bool get isValid => amount > 0 && merchant.isNotEmpty;
  String? get accountNumber => accountNumberLast4;

  Transaction toTransaction({
    String? userId,
    String? customId,
    String? customTag,
  }) {
    final nowMs = timestamp.millisecondsSinceEpoch;
    return Transaction(
      id: customId ?? 'tx_auto_${nowMs}_${merchant.hashCode.abs() % 10000}',
      amount: amount,
      type: type,
      merchant: merchant,
      channel: channel,
      source: source,
      category: category,
      timestamp: timestamp,
      isAutoCaptured: true,
      tag: customTag ?? 'Auto SMS/UPI Parsed',
      userId: userId,
      accountNumber: accountNumberLast4,
      referenceNumber: referenceNumber,
      balanceAfter: balanceAfter,
      rawText: rawText,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type,
      'merchant': merchant,
      'category': category,
      'channel': channel,
      'source': source,
      'accountNumberLast4': accountNumberLast4,
      'referenceNumber': referenceNumber,
      'balanceAfter': balanceAfter,
      'confidence': confidence,
      'rawText': rawText,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Production-grade Financial SMS and UPI Notification Parser for India
class SmsUpiParserEngine {
  /// Known Indian Banks & Financial Institutions
  static const Map<String, String> _bankIdentifiers = {
    'HDFCBK': 'HDFC Bank',
    'HDFC': 'HDFC Bank',
    'ICICIB': 'ICICI Bank',
    'ICICI': 'ICICI Bank',
    'SBIINB': 'State Bank of India',
    'SBIN': 'State Bank of India',
    'SBI': 'State Bank of India',
    'AXISBK': 'Axis Bank',
    'AXIS': 'Axis Bank',
    'KOTAKB': 'Kotak Mahindra Bank',
    'KOTAK': 'Kotak Mahindra Bank',
    'PNBSMS': 'Punjab National Bank',
    'PNB': 'Punjab National Bank',
    'BOBSMS': 'Bank of Baroda',
    'BOB': 'Bank of Baroda',
    'IDFCFB': 'IDFC FIRST Bank',
    'IDFC': 'IDFC FIRST Bank',
    'INDUSB': 'IndusInd Bank',
    'INDUS': 'IndusInd Bank',
    'CANBNK': 'Canara Bank',
    'CANARA': 'Canara Bank',
    'YESBNK': 'Yes Bank',
    'YESBANK': 'Yes Bank',
    'RBLBNK': 'RBL Bank',
    'RBL': 'RBL Bank',
    'FDRLBN': 'Federal Bank',
    'FEDERAL': 'Federal Bank',
    'SCBL': 'Standard Chartered',
    'STANCG': 'Standard Chartered',
    'HSBC': 'HSBC India',
    'CITIBK': 'Citibank',
    'UNIONB': 'Union Bank of India',
    'CBOL': 'Central Bank of India',
    'CBIN': 'Central Bank of India',
    'CENTBK': 'Central Bank of India',
    'CENTRAL BANK': 'Central Bank of India',
  };

  /// Known UPI Apps
  static const Map<String, String> _upiAppIdentifiers = {
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'gpay': 'Google Pay',
    'google pay': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'phonepe': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'paytm': 'Paytm',
    'com.dreamplug.androidapp': 'CRED',
    'cred': 'CRED',
    'in.org.npci.upiapp': 'BHIM',
    'bhim': 'BHIM',
    'in.amazon.mShop.android.shopping': 'Amazon Pay',
    'amazon pay': 'Amazon Pay',
    'com.whatsapp': 'WhatsApp Pay',
    'money.jupiter': 'Jupiter',
    'money.epifi': 'Fi Money',
    'indwin.c3.shareSpend': 'Slice',
    'com.naviapp': 'Navi',
  };

  /// Top Indian Merchants mapped to categories
  static const Map<String, String> _merchantCategories = {
    // Food & Dining
    'swiggy': 'Food & Dining',
    'zomato': 'Food & Dining',
    'starbucks': 'Food & Dining',
    'mcdonald': 'Food & Dining',
    'mcdonalds': 'Food & Dining',
    'dominos': 'Food & Dining',
    'kfc': 'Food & Dining',
    'pizza hut': 'Food & Dining',
    'subway': 'Food & Dining',
    'burger king': 'Food & Dining',
    'chai point': 'Food & Dining',
    'blue tokai': 'Food & Dining',
    'third wave coffee': 'Food & Dining',
    'haldirams': 'Food & Dining',
    'rebel foods': 'Food & Dining',
    'eatclub': 'Food & Dining',
    'behrouz': 'Food & Dining',
    'faasos': 'Food & Dining',
    'chaayos': 'Food & Dining',

    // Grocery & Quick Commerce
    'blinkit': 'Groceries',
    'zepto': 'Groceries',
    'bigbasket': 'Groceries',
    'bbdaily': 'Groceries',
    'instamart': 'Groceries',
    'dunzo': 'Groceries',
    'dmart': 'Groceries',
    'reliance fresh': 'Groceries',
    'nature\'s basket': 'Groceries',
    'jiomart': 'Groceries',

    // Transit & Travel
    'uber': 'Transit',
    'ola': 'Transit',
    'rapido': 'Transit',
    'metro': 'Transit',
    'dmrc': 'Transit',
    'bmrcl': 'Transit',
    'fastag': 'Transit',
    'irctc': 'Travel',
    'makemytrip': 'Travel',
    'goibibo': 'Travel',
    'redbus': 'Travel',
    'yatra': 'Travel',
    'indigo': 'Travel',
    'air india': 'Travel',
    'cleartrip': 'Travel',
    'shell': 'Fuel',
    'indian oil': 'Fuel',
    'hpcl': 'Fuel',
    'bpcl': 'Fuel',

    // Shopping & Lifestyle
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'nykaa': 'Shopping',
    'ajio': 'Shopping',
    'tata neu': 'Shopping',
    'meesho': 'Shopping',
    'croma': 'Electronics',
    'reliance digital': 'Electronics',
    'zara': 'Shopping',
    'h&m': 'Shopping',
    'uniqlo': 'Shopping',
    'decathlon': 'Lifestyle',

    // Entertainment & Subscriptions
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'pvr': 'Entertainment',
    'inox': 'Entertainment',
    'prime video': 'Entertainment',
    'hotstar': 'Entertainment',
    'youtube': 'Entertainment',
    'apple': 'Digital Services',
    'play store': 'Digital Services',

    // Bills & Utilities
    'airtel': 'Bills & Utilities',
    'jio': 'Bills & Utilities',
    'vi': 'Bills & Utilities',
    'bescom': 'Bills & Utilities',
    'tata power': 'Bills & Utilities',
    'adani electricity': 'Bills & Utilities',
    'mahanagar gas': 'Bills & Utilities',
    'igl': 'Bills & Utilities',
    'act fibernet': 'Bills & Utilities',
    'hathway': 'Bills & Utilities',

    // Investments & Wealth
    'zerodha': 'Investment',
    'groww': 'Investment',
    'angel one': 'Investment',
    'upstox': 'Investment',
    'kuvera': 'Investment',
    'indmoney': 'Investment',
    'mutual fund': 'Investment',
    'sip': 'Investment',

    // Health & Wellness
    'apollo pharmacy': 'Healthcare',
    'pharmeasy': 'Healthcare',
    'tata 1mg': 'Healthcare',
    'cult.fit': 'Wellness',
    'practo': 'Healthcare',
  };

  /// Parses arbitrary raw text (SMS body, notification body, clipboard text)
  static ParsedFinancialSms? parse({
    required String text,
    String? sender,
    String? packageName,
    DateTime? timestamp,
  }) {
    if (text.trim().isEmpty) return null;

    final combinedText = text.trim();
    final lowerText = combinedText.toLowerCase();

    // 1. Detect if this text looks like a financial message
    final hasFinancialKeywords = _hasFinancialKeywords(lowerText);
    if (!hasFinancialKeywords) return null;

    // 2. Extract transacted amount & separate available balance
    final amountResult = _extractAmounts(combinedText);
    if (amountResult == null) return null;

    final double transactedAmount = amountResult['amount']!;
    final double? balanceAfter = amountResult['balance'];

    if (transactedAmount <= 0) return null;

    // 3. Classify Direction (Debit vs Credit)
    final type = _classifyDirection(lowerText);

    // 4. Classify Channel (UPI vs CASH vs CARD vs BANK)
    final channel = _classifyChannel(lowerText, packageName);

    // 5. Detect Source / Institution
    final source = _detectSource(sender, packageName, combinedText);

    // 6. Extract Account Number (last 4 digits)
    final accountLast4 = _extractAccountLast4(combinedText);

    // 7. Extract UPI Reference / UTR / Txn ID
    final refNumber = _extractReferenceNumber(combinedText);

    // 8. Extract Merchant / Payee
    final merchant = _extractMerchant(
      text: combinedText,
      lowerText: lowerText,
      type: type,
      channel: channel,
      source: source,
    );

    // 9. Infer Category
    final category = _inferCategory(merchant, lowerText, type, channel);

    return ParsedFinancialSms(
      amount: transactedAmount,
      type: type,
      merchant: merchant,
      category: category,
      channel: channel,
      source: source,
      accountNumberLast4: accountLast4,
      referenceNumber: refNumber,
      balanceAfter: balanceAfter,
      confidence: 0.95,
      rawText: combinedText,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Determines whether text contains financial markers
  static bool _hasFinancialKeywords(String lowerText) {
    const triggers = [
      'debited', 'credited', 'paid', 'sent to', 'received', 'transfer to',
      'transferred', 'withdrawn', 'spent', 'txn', 'a/c', 'acct', 'avl bal',
      'upi', 'refund', 'inr', 'rs.', 'rs ', '₹', 'cashback', 'deposited'
    ];
    return triggers.any((k) => lowerText.contains(k));
  }

  /// Extracts transaction amount and balances separately
  static Map<String, double?>? _extractAmounts(String text) {
    // Check for "Avl Bal" or "Bal: Rs X" pattern first to isolate the balance
    double? balance;
    final balPattern = RegExp(
      r'(?:avl(?:[\.\s]+)?bal(?:ance)?|bal(?:ance)?|rem(?:aining)?[\.\s]+bal|clear[\.\s]+bal)\s*(?:is|:|-)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final balMatch = balPattern.firstMatch(text);
    if (balMatch != null && balMatch.group(1) != null) {
      final balStr = balMatch.group(1)!.replaceAll(',', '').trim();
      balance = double.tryParse(balStr);
    }

    // Pattern for transaction amounts:
    // (?:rs|inr|₹)\.?\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:inr|rs|₹)
    final amountPattern = RegExp(
      r'(?:(?:rs|inr|₹)\.?\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:inr|rs|₹))',
      caseSensitive: false,
    );

    final matches = amountPattern.allMatches(text).toList();
    if (matches.isEmpty) return null;

    double? primaryAmount;

    for (final m in matches) {
      final str1 = m.group(1);
      final str2 = m.group(2);
      final raw = (str1 != null && str1.isNotEmpty ? str1 : str2)?.replaceAll(',', '').trim();
      if (raw == null) continue;
      final val = double.tryParse(raw);
      if (val == null || val <= 0) continue;

      // Check if this match is the balance we already detected
      if (balance != null && (val - balance).abs() < 0.01) {
        // This is the balance amount, skip it for transaction amount if other matches exist
        if (matches.length > 1) continue;
      }

      primaryAmount = val;
      break;
    }

    // If only one match was found and it was tagged as balance, fallback to it
    if (primaryAmount == null && balance != null) {
      primaryAmount = balance;
      balance = null;
    }

    if (primaryAmount == null || primaryAmount <= 0) return null;

    return {
      'amount': primaryAmount,
      'balance': balance,
    };
  }

  /// Classifies direction
  static String _classifyDirection(String lowerText) {
    return NotificationParser.classifyType(lowerText);
  }

  /// Classifies financial channel
  static String _classifyChannel(String lowerText, String? packageName) {
    if (lowerText.contains('atm') ||
        lowerText.contains('wdl') ||
        lowerText.contains('cash dispensed') ||
        lowerText.contains('cash withdrawal')) {
      return 'CASH';
    }

    if (packageName != null &&
        (_upiAppIdentifiers.containsKey(packageName) ||
            packageName.contains('paisa') ||
            packageName.contains('phonepe') ||
            packageName.contains('paytm'))) {
      return 'UPI';
    }

    if (lowerText.contains('upi') ||
        lowerText.contains('vpa') ||
        lowerText.contains('gpay') ||
        lowerText.contains('phonepe') ||
        lowerText.contains('paytm') ||
        lowerText.contains('cred') ||
        lowerText.contains('bhim')) {
      return 'UPI';
    }

    if (lowerText.contains('card') ||
        lowerText.contains('pos') ||
        lowerText.contains('swipe')) {
      return 'CARD';
    }

    if (lowerText.contains('neft') ||
        lowerText.contains('rtgs') ||
        lowerText.contains('imps') ||
        lowerText.contains('netbanking')) {
      return 'BANK';
    }

    return 'UPI';
  }

  /// Detects source bank or UPI app
  static String _detectSource(String? sender, String? packageName, String fullText) {
    // Check package name first
    if (packageName != null && _upiAppIdentifiers.containsKey(packageName)) {
      return _upiAppIdentifiers[packageName]!;
    }

    // Check sender ID (e.g. VM-HDFCBK, AD-ICICIB, BZ-SBIINB)
    if (sender != null) {
      final cleanSender = sender.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
      for (final entry in _bankIdentifiers.entries) {
        if (cleanSender.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    // Check inside full text
    final upperText = fullText.toUpperCase();
    for (final entry in _bankIdentifiers.entries) {
      if (upperText.contains(entry.key)) {
        return entry.value;
      }
    }

    final lowerText = fullText.toLowerCase();
    for (final entry in _upiAppIdentifiers.entries) {
      if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }

    return 'Bank SMS';
  }

  /// Extracts account last 4 digits
  static String? _extractAccountLast4(String text) {
    final accountPattern = RegExp(
      r'(?:a\/c|acct|account|card)\s*(?:no\.?|ending)?\s*(?:[xX\*]+)?([0-9]{3,4})',
      caseSensitive: false,
    );
    final match = accountPattern.firstMatch(text);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  /// Extracts UPI reference or transaction ID
  static String? _extractReferenceNumber(String text) {
    final refPattern = RegExp(
      r'(?:(?:upi\s+)?(?:ref(?:\.?|erence)?(?:\s*(?:no\.?|:|\s))\s*)|(?:rrn|utr|txn\s*(?:id)?)\s*[:.\s]\s*)([0-9a-zA-Z]{6,25})',
      caseSensitive: false,
    );
    final match = refPattern.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.replaceAll(RegExp(r'\.+$'), '').trim();
    }
    return null;
  }

  /// Extracts merchant / entity name cleanly
  static String _extractMerchant({
    required String text,
    required String lowerText,
    required String type,
    required String channel,
    required String source,
  }) {
    if (channel == 'CASH') {
      final atmMatch = RegExp(r'(?:at|from)\s+([A-Za-z0-9\s&]{2,30}\s*ATM)', caseSensitive: false).firstMatch(text);
      if (atmMatch != null && atmMatch.group(1) != null) {
        return atmMatch.group(1)!.trim();
      }
      return 'ATM Cash Withdrawal';
    }

    // Check Payer name for "paid you" / "received from" pattern first
    final payer = NotificationParser.extractPayerFromPaidYou(text);
    if (payer != null) {
      return payer;
    }

    // Check top merchant keyword dictionary (longest match first with word boundary safety)
    final sortedEntries = _merchantCategories.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sortedEntries) {
      if (entry.key.length <= 3) {
        if (!RegExp(r'\b' + RegExp.escape(entry.key) + r'\b').hasMatch(lowerText)) {
          continue;
        }
      } else if (!lowerText.contains(entry.key)) {
        continue;
      }

      // Capitalize nicely
      final words = entry.key.split(' ').map((w) {
        if (w.isEmpty) return '';
        return '${w[0].toUpperCase()}${w.substring(1)}';
      }).join(' ');
      return words;
    }

    // Regex preposition pattern: "to [Merchant]", "at [Merchant]", "from [Merchant]"
    final prepPattern = RegExp(
      r'(?:paid to|transfer to|sent to|purchase at|spent at|to|at|from)\s+([A-Za-z0-9\s&]{2,30})',
      caseSensitive: false,
    );

    final match = prepPattern.firstMatch(text);
    if (match != null) {
      final candidate = match.group(1)?.trim();
      if (candidate != null &&
          !candidate.toLowerCase().contains('rs') &&
          !candidate.toLowerCase().contains('inr') &&
          !candidate.toLowerCase().contains('a/c') &&
          !candidate.toLowerCase().contains('bal') &&
          candidate.length >= 2 &&
          candidate.length <= 30) {
        // Clean trailing tokens
        var clean = candidate
            .split(RegExp(r'\s+(?:on|for|ref|txn|via|using|at|dated)\s+', caseSensitive: false))[0]
            .trim();
        clean = clean.replaceAll(RegExp(r'[,\.\-:]+$'), '').trim();
        if (clean.isNotEmpty && clean.length >= 2 && clean.length <= 30) {
          return clean;
        }
      }
    }

    if (type == 'credit') {
      return 'Direct Inflow ($source)';
    }
    return 'Card / UPI Payment ($source)';
  }

  /// Categorizes transaction using merchant & semantic context
  static String _inferCategory(
    String merchant,
    String lowerText,
    String type,
    String channel,
  ) {
    if (channel == 'CASH') return 'Cash & ATM';

    if (type == 'credit' || type == 'income') {
      if (lowerText.contains('salary')) return 'Salary';
      if (lowerText.contains('cashback')) return 'Cashback & Rewards';
      if (lowerText.contains('refund')) return 'Refund';
      if (lowerText.contains('dividend') || lowerText.contains('interest')) return 'Investment Return';
      return 'Received Payment';
    }

    final lowerMerchant = merchant.toLowerCase();

    // 1. Check merchant name first
    for (final entry in _merchantCategories.entries) {
      if (entry.key.length <= 3) {
        if (RegExp(r'\b' + RegExp.escape(entry.key) + r'\b').hasMatch(lowerMerchant)) {
          return entry.value;
        }
      } else if (lowerMerchant.contains(entry.key)) {
        return entry.value;
      }
    }

    // 2. Check full text with word boundary protection for short keys (e.g. 'vi' won't match 'via')
    for (final entry in _merchantCategories.entries) {
      if (entry.key.length <= 3) {
        if (RegExp(r'\b' + RegExp.escape(entry.key) + r'\b').hasMatch(lowerText)) {
          return entry.value;
        }
      } else if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }

    if (lowerText.contains('food') || lowerText.contains('restaurant') || lowerText.contains('cafe')) {
      return 'Food & Dining';
    }
    if (lowerText.contains('fuel') || lowerText.contains('petrol') || lowerText.contains('diesel')) {
      return 'Fuel';
    }
    if (lowerText.contains('recharge') || lowerText.contains('bill')) {
      return 'Bills & Utilities';
    }
    if (lowerText.contains('pharmacy') || lowerText.contains('hospital') || lowerText.contains('clinic')) {
      return 'Healthcare';
    }

    return 'General';
  }

  /// Authentic sample presets for testing and onboarding demo
  static const List<Map<String, String>> samplePresets = [
    {
      'name': 'HDFC Bank — Swiggy Delivery',
      'source': 'VM-HDFCBK',
      'text': 'Sent Rs.480.00 from HDFC Bank A/C *4821 to SWIGGY on 06-10-26 via UPI. Ref 428019284102. Bal Rs.28,450.00.',
    },
    {
      'name': 'ICICI Bank — Blinkit Groceries',
      'source': 'AD-ICICIB',
      'text': 'Dear Customer, Acct XX8912 debited for Rs 1,120.50 on 06-Oct-26. UPI:428011928374-Blinkit. Avl Bal: Rs 64,810.00.',
    },
    {
      'name': 'SBI — Starbucks Coffee',
      'source': 'BZ-SBIINB',
      'text': 'Your A/C XXXXX3319 has been debited by Rs.380.00 on 06/10/26 by transfer to STARBUCKS. UPI Ref No 428091827361. Avl Bal Rs:18,220.00.',
    },
    {
      'name': 'Axis Bank — Uber Transit',
      'source': 'JX-AXISBK',
      'text': 'INR 345.00 debited from A/c no. XX9041 on 06-10-26 at UBER INDIA via UPI. Avl Bal INR 41,200.00. UPI ref no 428099887711.',
    },
    {
      'name': 'Google Pay — Chai Point',
      'source': 'Google Pay',
      'text': 'Paid ₹120 to Chai Point at Indiranagar.',
    },
    {
      'name': 'Google Pay — SUBODH PRASAD (Received Credit)',
      'source': 'Google Pay',
      'text': 'SUBODH PRASAD paid you ₹500.00',
    },
    {
      'name': 'PhonePe — Zepto Quick Commerce',
      'source': 'PhonePe',
      'text': 'Paid ₹640 to Zepto Grocery via PhonePe UPI. Txn ID: T2410061234.',
    },
    {
      'name': 'Canara Bank — Salary Credit',
      'source': 'VK-CANBNK',
      'text': 'Your A/C 9081 has been credited by INR 75,000.00 on 06-Oct-26 by SALARY Oct 2026. Avl Bal INR 1,12,400.00.',
    },
    {
      'name': 'HDFC Bank — ATM Cash Withdrawal',
      'source': 'VM-HDFCBK',
      'text': 'INR 5,000.00 withdrawn from ATM at INDIRANAGAR BLR from A/C *4821. Avl Bal INR 23,450.00.',
    },
  ];
}
