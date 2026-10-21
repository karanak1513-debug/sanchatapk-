import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/models/gamification_models.dart';
import 'package:sanchay/models/transaction.dart';
import 'package:sanchay/services/gamification_service.dart';

void main() {
  group('Gamification & Wealth Universe Unit Tests', () {
    test('SavingPet progresses and evolves correctly', () {
      const pet = SavingPet(name: 'Kuber', stage: PetStage.newborn, xp: 50, level: 1);
      expect(pet.stageName, contains('Newborn'));
      expect(pet.stageAvatar, equals('🐣'));
      expect(pet.nextLevelXp, equals(200));
      expect(pet.progressToNextLevel, closeTo(0.25, 0.01));

      // Test stage progression
      final evolvedPet = SavingPet.fromMap({
        'name': 'Kuber',
        'stage': 'vaultBeast',
        'xp': 2200,
        'level': 11,
      });
      expect(evolvedPet.stageName, contains('Vault Beast'));
      expect(evolvedPet.stageAvatar, equals('🐲'));
    });

    test('SavingStreak computes milestones accurately', () {
      const streak3 = SavingStreak(currentStreak: 2, bestStreak: 5);
      expect(streak3.nextMilestone, equals(3));

      const streak7 = SavingStreak(currentStreak: 5, bestStreak: 10);
      expect(streak7.nextMilestone, equals(7));

      const streak30 = SavingStreak(currentStreak: 22, bestStreak: 30);
      expect(streak30.nextMilestone, equals(30));
    });

    test('BudgetBoss calculates health percentage and weakness status', () {
      const healthyBoss = BudgetBoss(
        monthKey: '2026-10',
        maxBudget: 30000.0,
        remainingBudget: 24000.0,
      );
      expect(healthyBoss.hpPercent, equals(0.8));
      expect(healthyBoss.bossStatus, contains('BOSS WEAKENED'));

      const enragedBoss = BudgetBoss(
        monthKey: '2026-10',
        maxBudget: 30000.0,
        remainingBudget: 6000.0,
      );
      expect(enragedBoss.hpPercent, equals(0.2));
      expect(enragedBoss.bossStatus, contains('BOSS ENRAGED'));
    });

    test('WealthUniverseTier resolves 100-tier worlds faithfully', () {
      expect(WealthUniverseTier.fromLevel(5).worldName, equals('Starter Village'));
      expect(WealthUniverseTier.fromLevel(20).worldName, equals('Money City'));
      expect(WealthUniverseTier.fromLevel(40).worldName, equals('Wealth Kingdom'));
      expect(WealthUniverseTier.fromLevel(65).worldName, equals('Finance Galaxy'));
      expect(WealthUniverseTier.fromLevel(85).worldName, equals('Cosmic Wealth Realm'));
      expect(WealthUniverseTier.fromLevel(100).worldName, equals('Wealth God'));
    });

    test('Weekly Roast derives strictly from real transaction data', () {
      final service = GamificationService();

      // Empty list
      final emptyRoast = service.generateWeeklyRoast(
        transactions: [],
        personalityMode: 'calm',
      );
      expect(emptyRoast, contains('Zero transactions'));

      // Real transactions
      final txList = [
        Transaction(
          id: 'tx_1',
          amount: 850.0,
          type: 'debit',
          merchant: 'Swiggy',
          category: 'Dining',
          source: 'UPI',
          timestamp: DateTime.now(),
        ),
        Transaction(
          id: 'tx_2',
          amount: 1500.0,
          type: 'debit',
          merchant: 'Shell',
          category: 'Fuel',
          source: 'UPI',
          timestamp: DateTime.now(),
        ),
      ];

      final calmRoast = service.generateWeeklyRoast(
        transactions: txList,
        personalityMode: 'calm',
      );
      expect(calmRoast, contains('₹2350'));
      expect(calmRoast, contains('Fuel'));

      final savageRoast = service.generateWeeklyRoast(
        transactions: txList,
        personalityMode: 'savage',
      );
      expect(savageRoast, contains('Bro...'));
      expect(savageRoast, contains('Fuel'));
    });
  });
}
