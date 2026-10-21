import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/services/notification_parser.dart';
import 'package:sanchay/services/sms_upi_parser_engine.dart';

void main() {
  group('Notification UPI Parser Regression Tests (Mandatory Tests)', () {
    test('TEST 1: Central Bank of India Credit with UPI Ref No', () {
      const text =
          'A/c XX4445 credited by Rs. 1700.00 on 08102026 via UPI from PhonePe via Ref No. 628146965625. -CBol';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(1700.00));
      expect(parsed.isCredit, isTrue);
      expect(NotificationParser.classifyType(text), equals('income'));
      expect(parsed.referenceNumber, equals('628146965625'));
      expect(parsed.bank, equals('Central Bank of India'));
      expect(parsed.fingerprint, isNotEmpty);
    });

    test('TEST 2: Central Bank of India Debit with Ref No', () {
      const text =
          'A/c XX4445 debited by Rs. 300.00 via UPI with Ref No. 123456789. -CBol';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(300.00));
      expect(parsed.isCredit, isFalse);
      expect(NotificationParser.classifyType(text), equals('expense'));
      expect(parsed.referenceNumber, equals('123456789'));
      expect(parsed.bank, equals('Central Bank of India'));
      expect(parsed.fingerprint, isNotEmpty);
    });

    test('TEST 3: PhonePe Wallet Inflow / Withdrawal', () {
      const text =
          'Withdrawal of Rs.1700 from your PhonePe wallet to your Central Bank Of India account has been successful.';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(1700.00));
      expect(parsed.isCredit, isTrue);
      expect(parsed.subtype, equals('WALLET_INFLOW'));
      expect(parsed.category, equals('WALLET_INFLOW'));
    });

    test('TEST 4: PhonePe Wallet Payment / Outflow', () {
      const text =
          "You've paid Rs. 30 via PhonePe wallet. Remaining balance: Rs. 2502.";
      final parsed = parseUpiMessage(text);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(30.00));
      expect(parsed.isCredit, isFalse);
      expect(parsed.subtype, equals('WALLET_PAYMENT'));
      expect(parsed.balanceAfter, equals(2502.00));
    });

    test('TEST 5: Comma-formatted Large Amount Credit with Rupee Symbol', () {
      const text = 'credited by ₹1,50,000.00 to A/c XX1234 Ref No 987654 -HDFCBK';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(150000.00));
      expect(parsed.isCredit, isTrue);
    });

    test('TEST 6: INR Amount Debit with Comma', () {
      const text = 'debited by INR 2,500 from A/c XX5678 Ref: 445566 -SBI';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(2500.00));
      expect(parsed.isCredit, isFalse);
    });

    test('TEST 7: Deduplication of Identical SMS via Reference Number & Fingerprint', () {
      const text =
          'A/c XX4445 credited by Rs. 1700.00 on 08102026 via UPI from PhonePe via Ref No. 628146965625. -CBol';
      final parsed1 = parseUpiMessage(text);
      final parsed2 = parseUpiMessage(text);

      expect(parsed1, isNotNull);
      expect(parsed2, isNotNull);
      expect(parsed1!.referenceNumber, equals(parsed2!.referenceNumber));
      expect(parsed1.referenceNumber, equals('628146965625'));
      expect(parsed1.fingerprint, equals(parsed2.fingerprint));

      // Simulate deduplication registry
      final Set<String> dedupeRegistry = {};
      final isFirstDuplicate = dedupeRegistry.contains(parsed1.fingerprint);
      dedupeRegistry.add(parsed1.fingerprint);

      final isSecondDuplicate = dedupeRegistry.contains(parsed2.fingerprint);

      expect(isFirstDuplicate, isFalse);
      expect(isSecondDuplicate, isTrue);
      expect(dedupeRegistry.length, equals(1)); // Only one transaction registered
    });
  });

  group('BUG 1: False Positive Protection & Defensive Filter Tests', () {
    test('Promotional SMS from JioPC is rejected immediately', () {
      const text = 'Plans start at just ₹333/month';
      final parsed = parseUpiMessage(text, 'JioPC');
      expect(parsed, isNull, reason: 'Promotional message must never become an expense');
    });

    test('Promotional cashback message is rejected', () {
      const text = 'Get ₹500 cashback on your next bill';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNull);
    });

    test('Recharge promotion is rejected', () {
      const text = 'Recharge for ₹299 and get unlimited calls';
      final parsed = parseUpiMessage(text, 'Vi-CARE');
      expect(parsed, isNull);
    });

    test('Congratulations / contest spam is rejected', () {
      const text = 'Congratulations! You won ₹1000 in your wallet';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNull);
    });

    test('Monthly plan promotional message is rejected', () {
      const text = '₹333/month plan available now';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNull);
    });

    test('Voucher promotional message is rejected', () {
      const text = 'Flat ₹500 voucher waiting for you';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNull);
    });

    test('Legitimate debit message passes validation', () {
      const text = 'Your A/c XX1234 has been debited by Rs.500. UPI Ref 123456789.';
      final parsed = parseUpiMessage(text, 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(500.0));
      expect(parsed.isCredit, isFalse);
      expect(parsed.referenceNumber, equals('123456789'));
      expect(parsed.accountLast4, equals('1234'));
      expect(parsed.fingerprint, isNotEmpty);
    });

    test('Legitimate credit message passes validation', () {
      const text = 'Rs.1000 credited to A/c XX1234. Ref No 987654.';
      final parsed = parseUpiMessage(text, 'SBIINB');
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(1000.0));
      expect(parsed.isCredit, isTrue);
      expect(parsed.referenceNumber, equals('987654'));
      expect(parsed.accountLast4, equals('1234'));
      expect(parsed.fingerprint, isNotEmpty);
    });

    test('Arbitrary non-bank sender is rejected even if text contains amount', () {
      const text = 'Your payment of Rs. 400 has been received';
      final parsed = parseUpiMessage(text, 'DM-SWIGGY');
      expect(parsed, isNull);
    });
  });

  group('Legacy UPI & Notification Tests', () {
    test('"SUBODH PRASAD paid you ₹500.00" in SmsUpiParserEngine', () {
      const text = 'SUBODH PRASAD paid you ₹500.00';
      expect(NotificationParser.inferCategory(text), equals('Received Payment'));
      expect(NotificationParser.extractPayerFromPaidYou(text), equals('SUBODH PRASAD'));

      final parsed = SmsUpiParserEngine.parse(text: text)!;
      expect(parsed.isValid, isTrue);
      expect(parsed.amount, equals(500.0));
      expect(parsed.type, equals('income'));
      expect(parsed.isCredit, isTrue);
      expect(parsed.isDebit, isFalse);
      expect(parsed.category, equals('Received Payment'));
      expect(parsed.merchant, equals('SUBODH PRASAD'));
    });

    test('"credited" triggers', () {
      expect(NotificationParser.isCreditTransaction('A/c XX1234 credited by Rs 5000.00 Ref 1234 -SBI'), isTrue);
    });

    test('Debit triggers ("paid to", "debited by")', () {
      expect(NotificationParser.isCreditTransaction('A/c XX1234 debited by Rs 150.00 Ref 1234 -HDFC'), isFalse);
      expect(NotificationParser.classifyType('A/c XX1234 debited by Rs 150.00 Ref 1234 -HDFC'), equals('expense'));
    });
  });
}
