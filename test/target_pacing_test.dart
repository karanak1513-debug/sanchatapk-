import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/models/sanchay_target.dart';

void main() {
  group('SanchayTarget Run-Rate Pacing Tests', () {
    test('Calculates remaining days and dynamic pacing correctly', () {
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 40));

      final target = SanchayTarget(
        id: 'vault_test_1',
        title: 'Master Vault Reserve',
        targetCap: 100000.0,
        currentAccumulation: 20000.0,
        targetDate: targetDate,
        isPaused: false,
      );

      expect(target.remainingAmount, 80000.0);
      expect(target.percentage, 20);
      expect(target.remainingDays >= 39 && target.remainingDays <= 41, true);

      // Daily Pace = 80000 / remainingDays
      final expectedDaily = 80000.0 / target.remainingDays;
      expect((target.dailyPace - expectedDaily).abs() < 0.01, true);
      expect((target.weeklyPace - (expectedDaily * 7)).abs() < 0.01, true);
      expect((target.monthlyPace - (expectedDaily * 30)).abs() < 0.01, true);
    });

    test('Paused state freezes pacing calculations to zero', () {
      final target = SanchayTarget(
        id: 'vault_test_2',
        title: 'Master Vault Reserve',
        targetCap: 100000.0,
        currentAccumulation: 50000.0,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        isPaused: true,
      );

      expect(target.dailyPace, 0.0);
      expect(target.weeklyPace, 0.0);
      expect(target.monthlyPace, 0.0);
    });

    test('Simulating deposit increments accumulation and recalculates pace', () {
      final now = DateTime.now();
      final target = SanchayTarget(
        id: 'vault_test_3',
        title: 'Master Vault Reserve',
        targetCap: 100000.0,
        currentAccumulation: 30000.0,
        targetDate: now.add(const Duration(days: 20)),
        isPaused: false,
      );

      final initialDailyPace = target.dailyPace;

      // Simulate depositing 10,000 into vault
      final updated = target.copyWith(
        currentAccumulation: target.currentAccumulation + 10000.0,
      );

      expect(updated.currentAccumulation, 40000.0);
      expect(updated.remainingAmount, 60000.0);
      expect(updated.percentage, 40);
      expect(updated.dailyPace < initialDailyPace, true);
    });
  });
}
