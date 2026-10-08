import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/services/notification_parser.dart';
import 'package:sanchay/services/sms_sync_service.dart';

void main() {
  group('SmsSyncService Unit Tests', () {
    test('NotificationParser correctly parses bank SMS text', () {
      const smsBody = 'Dear Customer, your A/c XX4321 is debited by Rs. 850.00 on 07-Oct-26 spent at Swiggy via UPI.';
      final parsed = parseUpiMessage(smsBody);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(850.0));
      expect(parsed.isCredit, isFalse);

      final category = NotificationParser.inferCategory(smsBody, parsed.isCredit);
      expect(category, isNotEmpty);
    });

    test('NotificationParser accurately marks credit bank SMS', () {
      const creditSms = 'A/c XX1234 credited by Rs. 2,500.00 on 07-Oct-26. Info: SUBODH PRASAD paid you. Balance: Rs. 45,000.00';
      final parsed = parseUpiMessage(creditSms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(2500.0));
      expect(parsed.isCredit, isTrue);

      final payer = NotificationParser.extractPayerFromPaidYou(creditSms);
      expect(payer, isNotNull);
    });

    test('SmsSyncService singleton instance creates cleanly', () {
      final service1 = SmsSyncService();
      final service2 = SmsSyncService();
      expect(identical(service1, service2), isTrue);
    });
  });
}
