import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/services/notification_parser.dart';
import 'package:sanchay/services/sms_upi_parser_engine.dart';

void main() {
  group('Notification UPI Parser Regression Tests (7 Mandatory Tests)', () {
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
      const text = 'credited by ₹1,50,000.00';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(150000.00));
      expect(parsed.isCredit, isTrue);
    });

    test('TEST 6: INR Amount Debit with Comma', () {
      const text = 'debited by INR 2,500';
      final parsed = parseUpiMessage(text);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(2500.00));
      expect(parsed.isCredit, isFalse);
    });

    test('TEST 7: Deduplication of Identical SMS via Reference Number', () {
      const text =
          'A/c XX4445 credited by Rs. 1700.00 on 08102026 via UPI from PhonePe via Ref No. 628146965625. -CBol';
      final parsed1 = parseUpiMessage(text);
      final parsed2 = parseUpiMessage(text);

      expect(parsed1, isNotNull);
      expect(parsed2, isNotNull);
      expect(parsed1!.referenceNumber, equals(parsed2!.referenceNumber));
      expect(parsed1.referenceNumber, equals('628146965625'));

      // Simulate deduplication registry
      final Set<String> dedupeRegistry = {};
      final key1 = parsed1.referenceNumber != null
          ? 'REF_${parsed1.referenceNumber}'
          : 'HASH_${parsed1.amount}';
      final isFirstDuplicate = dedupeRegistry.contains(key1);
      dedupeRegistry.add(key1);

      final key2 = parsed2.referenceNumber != null
          ? 'REF_${parsed2.referenceNumber}'
          : 'HASH_${parsed2.amount}';
      final isSecondDuplicate = dedupeRegistry.contains(key2);

      expect(isFirstDuplicate, isFalse);
      expect(isSecondDuplicate, isTrue);
      expect(dedupeRegistry.length, equals(1)); // Only one transaction registered
    });
  });

  group('Legacy UPI & Notification Tests', () {
    test('"SUBODH PRASAD paid you ₹500.00" is classified as income / credit', () {
      const text = 'SUBODH PRASAD paid you ₹500.00';
      expect(NotificationParser.isCreditTransaction(text), isTrue);
      expect(NotificationParser.classifyType(text), equals('income'));
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

    test('"Received ₹1,200.00 from Subodh" is classified as credit / income', () {
      const text = 'Received ₹1,200.00 from Subodh';
      expect(NotificationParser.isCreditTransaction(text), isTrue);
      expect(NotificationParser.classifyType(text), equals('income'));
      expect(NotificationParser.inferCategory(text), equals('Received Payment'));
    });

    test('"credited" and "cashback" and "refund" triggers', () {
      expect(NotificationParser.isCreditTransaction('A/c XX1234 credited by Rs 5000.00'), isTrue);
      expect(NotificationParser.isCreditTransaction('Cashback of Rs 50 added to your account'), isTrue);
      expect(NotificationParser.isCreditTransaction('Refund of Rs 499.00 processed successfully'), isTrue);
      expect(NotificationParser.isCreditTransaction('Money received from subodh@upi'), isTrue);
    });

    test('Debit triggers ("paid to", "debited", "spent at", "sent to")', () {
      expect(NotificationParser.isCreditTransaction('Paid to SUBODH PRASAD ₹250.00'), isFalse);
      expect(NotificationParser.classifyType('Paid to SUBODH PRASAD ₹250.00'), equals('expense'));

      expect(NotificationParser.isCreditTransaction('A/c debited by Rs 150.00 for UPI txn'), isFalse);
      expect(NotificationParser.isCreditTransaction('Spent at Starbucks ₹350.00'), isFalse);
      expect(NotificationParser.isCreditTransaction('Sent to Aman ₹1,000.00'), isFalse);
      expect(NotificationParser.isCreditTransaction('Payment to Swiggy ₹420.00'), isFalse);
    });

    test('Fallback "paid" alone without "you" is treated as Debit', () {
      expect(NotificationParser.isCreditTransaction('Paid ₹500 via GPay'), isFalse);
      expect(NotificationParser.classifyType('Paid ₹500 via GPay'), equals('expense'));
    });
  });
}
