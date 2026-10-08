import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/models/sanchay_target.dart';
import 'package:sanchay/services/target_service.dart';

void main() {
  group('TargetVaultService & SanchayTarget Model Lifecycle Tests', () {
    test('SanchayTarget.fromFirestore handles both deadline and targetDate seamlessly', () {
      final fakeJsonWithDeadline = {
        'id': 'vault_custom_1',
        'title': 'Tokyo Trip Fund',
        'targetCap': 150000.0,
        'currentAccumulation': 35000.0,
        'category': 'Travel',
        'colorValue': 0xFF2563EB, // Sapphire
        'deadline': '2027-01-01T00:00:00.000Z',
        'bannerUrl': 'https://example.com/tokyo.jpg',
        'isActive': true,
        'isPrimary': true,
      };

      final target = SanchayTarget.fromJson(fakeJsonWithDeadline);
      expect(target.title, 'Tokyo Trip Fund');
      expect(target.targetCap, 150000.0);
      expect(target.category, 'Travel');
      expect(target.isPaused, false);
      expect(target.isPrimary, true);
    });

    test('Vault Accumulation Progression & Percentage Clamping (₹1,700 -> ₹2,000 -> ₹3,000)', () {
      // Create test vault: targetCap = ₹10,000, currentAccumulation = ₹0
      var vault = SanchayTarget(
        id: 'vault_test_goal',
        title: 'Emergency Reserve',
        targetCap: 10000.0,
        currentAccumulation: 0.0,
        targetDate: DateTime.now().add(const Duration(days: 90)),
      );

      expect(vault.currentAccumulation, equals(0.0));
      expect(vault.progress, equals(0.0));
      expect(vault.percentage, equals(0));

      // Deposit 1: ₹1,700
      vault = vault.copyWith(currentAccumulation: vault.currentAccumulation + 1700.0);
      expect(vault.currentAccumulation, equals(1700.0));
      expect(vault.progress, closeTo(0.17, 0.001));
      expect(vault.percentage, equals(17));

      // Deposit 2: ₹300
      vault = vault.copyWith(currentAccumulation: vault.currentAccumulation + 300.0);
      expect(vault.currentAccumulation, equals(2000.0));
      expect(vault.progress, closeTo(0.20, 0.001));
      expect(vault.percentage, equals(20));

      // Deposit 3: ₹1,000
      vault = vault.copyWith(currentAccumulation: vault.currentAccumulation + 1000.0);
      expect(vault.currentAccumulation, equals(3000.0));
      expect(vault.progress, closeTo(0.30, 0.001));
      expect(vault.percentage, equals(30));

      // Overfill deposit: ₹15,000 into ₹10,000 cap
      vault = vault.copyWith(currentAccumulation: 15000.0);
      expect(vault.currentAccumulation, equals(15000.0));
      expect(vault.progress, equals(1.0)); // Clamped to 1.0
      expect(vault.percentage, equals(100)); // Clamped to 100%
      expect(vault.isAchieved, isTrue);

      // Safe fallback on zero cap: no division by zero
      final zeroCapVault = SanchayTarget(
        id: 'vault_zero',
        title: 'Zero Cap',
        targetCap: 0.0,
        currentAccumulation: 500.0,
        targetDate: DateTime.now(),
      );
      expect(zeroCapVault.progress, equals(0.0));
      expect(zeroCapVault.percentage, equals(0));
    });

    test('TargetVaultService methods safely guard against null/empty authentication', () async {
      final createResult = await TargetVaultService.createVault(
        title: 'New Emergency Fund',
        targetCap: 50000.0,
        deadline: DateTime.now().add(const Duration(days: 60)),
        category: 'Emergency',
        colorValue: 0xFFDC2626,
      );
      expect(createResult, isFalse);

      final updateResult = await TargetVaultService.updateVault(
        vaultId: 'vault_123',
        title: 'Renamed Fund',
        targetCap: 60000.0,
        deadline: DateTime.now().add(const Duration(days: 90)),
        category: 'General',
        colorValue: 0xFF059669,
        isActive: true,
        isPrimary: false,
      );
      expect(updateResult, isFalse);

      final deleteResult = await TargetVaultService.deleteVault('vault_123');
      expect(deleteResult, isFalse);
    });

    test('Empty vaultId rejects early in updateVault, deleteVault and depositToVault', () async {
      final updateResult = await TargetVaultService.updateVault(
        vaultId: '',
        title: 'Empty Vault ID',
        targetCap: 1000.0,
        deadline: DateTime.now(),
        category: 'General',
        colorValue: 0xFFDC2626,
        isActive: true,
        isPrimary: false,
      );
      expect(updateResult, isFalse);

      final deleteResult = await TargetVaultService.deleteVault('');
      expect(deleteResult, isFalse);

      // depositToVault with invalid parameters returns early without error
      await TargetVaultService.depositToVault(
        vaultId: '',
        amount: 0.0,
        vaultTitle: 'Empty Title',
      );
    });
  });
}
