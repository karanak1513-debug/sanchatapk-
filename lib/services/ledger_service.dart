import '../models/sanchay_target.dart';
import '../models/transaction.dart';
import 'safe_to_spend_engine.dart';

/// Centralized Ledger Calculation Engine for Sanchay Wealth
/// Implements strict dual-ledger isolation between liquid cashflow and vault reserves.
class LedgerService {
  /// Excludes transactions where type == 'vault_deposit' from Outflow Debits.
  /// Outflow Debits strictly sums genuine expenses (type == 'debit' or 'expense').
  static double calculateOutflowDebits(List<Transaction> transactions) {
    return transactions.where((tx) {
      // 1. Exclude vault deposits and internal allocations
      if (tx.isVaultDeposit) return false;
      final type = tx.type.toLowerCase().trim();
      if (type == 'vault_deposit' || type == 'vault_transfer' || type == 'internal_transfer') {
        return false;
      }
      final cat = tx.category.toLowerCase().trim();
      if (cat.contains('vault') || cat == 'reserve contribution' || cat == 'vault allocation') {
        return false;
      }
      // 2. Strictly include genuine expenses only
      return type == 'debit' || type == 'expense';
    }).fold(0.0, (acc, tx) => acc + tx.amount);
  }

  /// Calculates genuine Inflow Credits (type == 'credit' or 'income').
  /// Excludes internal transfers or vault deposits.
  static double calculateInflowCredits(List<Transaction> transactions) {
    return transactions.where((tx) {
      if (tx.isVaultDeposit) return false;
      final type = tx.type.toLowerCase().trim();
      if (type == 'vault_deposit' || type == 'vault_transfer' || type == 'internal_transfer') {
        return false;
      }
      return type == 'credit' || type == 'income';
    }).fold(0.0, (acc, tx) => acc + tx.amount);
  }

  /// Recomputes Net Cash Liquidity = Total Inflow Credits - Actual Expenses.
  /// Vault deposits are internal reserves and NEVER reduce Net Cash Liquidity.
  static double calculateNetCashLiquidity(List<Transaction> transactions) {
    final credits = calculateInflowCredits(transactions);
    final debits = calculateOutflowDebits(transactions);
    return credits - debits;
  }

  /// Calculates safe Daily Spending Runway so it never crashes to ₹0 when savings are transferred.
  static double calculateDailyRunway({
    required List<Transaction> transactions,
    required List<SanchayTarget> targets,
    required double currentLiquidSavings,
    bool weekendSurgeEnabled = true,
  }) {
    final metrics = SafeToSpendEngine.calculate(
      transactions: transactions,
      targets: targets,
      currentLiquidSavings: currentLiquidSavings,
      weekendSurgeEnabled: weekendSurgeEnabled,
    );
    return metrics.todaySafeToSpend;
  }

  /// Helper to get full SafeToSpendMetrics through the unified ledger engine
  static SafeToSpendMetrics getRunwayMetrics({
    required List<Transaction> transactions,
    required List<SanchayTarget> targets,
    required double currentLiquidSavings,
    bool weekendSurgeEnabled = true,
  }) {
    return SafeToSpendEngine.calculate(
      transactions: transactions,
      targets: targets,
      currentLiquidSavings: currentLiquidSavings,
      weekendSurgeEnabled: weekendSurgeEnabled,
    );
  }
}
