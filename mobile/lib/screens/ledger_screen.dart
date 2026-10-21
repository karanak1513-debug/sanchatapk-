import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';
import '../providers/sanchay_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/center_alert.dart';
import '../widgets/frosted_glass_card.dart';
import '../widgets/privacy_text.dart';
import '../widgets/top_glass_bar.dart';
import '../services/sms_sync_service.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  // 0: UPI & Bank Stream, 1: Vault Allocations
  int _selectedSegment = 0;
  String _subFilter = 'all'; // 'all', 'debit', 'credit'
  bool _isSyncingSms = false;

  Future<void> _handleSmsSync() async {
    if (_isSyncingSms) return;
    setState(() => _isSyncingSms = true);

    try {
      final provider = context.read<SanchayProvider>();
      final result = await SmsSyncService().syncBankSmsInbox(provider: provider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle_outline : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.message,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: result.success ? AppColors.emeraldDark : AppColors.crimson,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMS Sync error: $e'),
            backgroundColor: AppColors.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingSms = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final allTxs = provider.transactions;

    // Separate Ledger Streams:
    // Tab 1: UPI & Bank Stream (Notification / SMS Auto-Logged)
    // Filter by type: type == 'expense' || type == 'income' (and not vault deposit)
    final bankAndUpiList = allTxs.where((tx) =>
        !tx.isVaultDeposit &&
        (tx.type.toLowerCase() == 'expense' ||
            tx.type.toLowerCase() == 'income' ||
            tx.type.toLowerCase() == 'debit' ||
            tx.type.toLowerCase() == 'credit')).toList();

    // Tab 2: Vault Allocations (Goal Deposits)
    // Filter by type: type == 'vault_deposit'
    final vaultAllocationsList = allTxs.where((tx) =>
        tx.isVaultDeposit ||
        tx.type.toLowerCase() == 'vault_deposit' ||
        tx.category.toUpperCase() == 'VAULT TRANSFER').toList();

    // Active Tab List
    List<Transaction> activeList = _selectedSegment == 0 ? bankAndUpiList : vaultAllocationsList;

    // Apply sub-filter for Tab 1
    if (_selectedSegment == 0) {
      if (_subFilter == 'debit') {
        activeList = activeList.where((tx) => tx.isDebit).toList();
      } else if (_subFilter == 'credit') {
        activeList = activeList.where((tx) => tx.isCredit).toList();
      }
    }

    // Apply search filter
    final displayedTransactions = _searchQuery.isEmpty
        ? activeList
        : activeList.where((tx) {
            final q = _searchQuery.toLowerCase();
            return tx.merchant.toLowerCase().contains(q) ||
                tx.category.toLowerCase().contains(q) ||
                tx.channel.toLowerCase().contains(q) ||
                (tx.source.toLowerCase().contains(q));
          }).toList();

    // Metrics for Tab 1 (Net Cash in Hand & Safe to Spend Runway)
    final totalCredits = bankAndUpiList.where((tx) => tx.isCredit).fold(0.0, (acc, tx) => acc + tx.amount);
    final totalDebits = bankAndUpiList.where((tx) => tx.isDebit).fold(0.0, (acc, tx) => acc + tx.amount);
    final netCashInHand = totalCredits - totalDebits;

    // Metrics for Tab 2 (Vault Accumulations)
    final totalVaultSaved = vaultAllocationsList.fold(0.0, (acc, tx) => acc + tx.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        bottom: false, // Navigation dock handles bottom clearance
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Responsive App Header
            SliverToBoxAdapter(
              child: SanchayUnifiedHeader(
                subHeader: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEDGER & STATEMENTS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: AppColors.crimson,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedSegment == 0 ? 'UPI & Bank Feed' : 'Vault Savings Journal',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.obsidian,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Manual SMS Fallback Sync Trigger
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: InkWell(
                            onTap: _isSyncingSms ? null : _handleSmsSync,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.emerald.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isSyncingSms
                                      ? const SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldDark),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.sync,
                                          size: 15,
                                          color: AppColors.emeraldDark,
                                        ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Sync SMS',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.emeraldDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: provider.isPrivacyMasked ? 'Reveal' : 'Mask',
                          onPressed: () => provider.togglePrivacyMode(),
                          icon: Icon(
                            provider.isPrivacyMasked ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                            color: provider.isPrivacyMasked ? AppColors.crimson : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Screen Body with Strict Spacing & Bottom Dock Clearance
            SliverPadding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // =========================================================
                  // DISTINCT SEGMENT TABS (UPI vs. VAULT SAVINGS)
                  // =========================================================
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSegment = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedSegment == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _selectedSegment == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 16,
                                    color: _selectedSegment == 0 ? AppColors.obsidian : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'UPI & Bank Feed',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: _selectedSegment == 0 ? FontWeight.w700 : FontWeight.w600,
                                      color: _selectedSegment == 0 ? AppColors.obsidian : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSegment = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedSegment == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _selectedSegment == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 16,
                                    color: _selectedSegment == 1 ? AppColors.emeraldDark : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Vault Savings Journal',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: _selectedSegment == 1 ? FontWeight.w700 : FontWeight.w600,
                                      color: _selectedSegment == 1 ? AppColors.emeraldDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // =========================================================
                  // SUMMARY BANNER ACCORDING TO ACTIVE SEGMENT
                  // =========================================================
                  if (_selectedSegment == 0) ...[
                    // Tab 1: Inflow / Outflow & Net Cash in Hand
                    Row(
                      children: [
                        Expanded(
                          child: FrostedGlassCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.arrow_downward, color: AppColors.emerald, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Incoming (Credit)',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                PrivacyText(
                                  rawText: provider.formatCurrency(totalCredits),
                                  monetaryValue: totalCredits,
                                  isSigned: true,
                                  isDebit: false,
                                  style: AppTheme.monoNumeric(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FrostedGlassCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.arrow_upward, color: AppColors.crimson, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Outgoing (Debit)',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                PrivacyText(
                                  rawText: provider.formatCurrency(totalDebits),
                                  monetaryValue: totalDebits,
                                  isSigned: true,
                                  isDebit: true,
                                  style: AppTheme.monoNumeric(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.crimson,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Net Cash in Hand Runway Capsule
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (netCashInHand >= 0 ? AppColors.emerald : AppColors.crimson).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 16,
                                  color: netCashInHand >= 0 ? AppColors.emeraldDark : AppColors.crimson,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Net Cash in Hand',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Safe to Spend Runway',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          PrivacyText(
                            rawText: provider.formatCurrency(netCashInHand),
                            monetaryValue: netCashInHand,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: netCashInHand >= 0 ? AppColors.obsidian : AppColors.crimson,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Tab 2: Vault Allocations Summary
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0F172A),
                            const Color(0xFF1E293B),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.savings_outlined, color: AppColors.emeraldFixed, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'GOAL SAVINGS DEPOSITS',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.emeraldFixed.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'SAVINGS ACCUMULATION',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emeraldFixed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              PrivacyText(
                                rawText: provider.formatCurrency(totalVaultSaved),
                                monetaryValue: totalVaultSaved,
                                isSigned: false,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'allocated to vaults',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Vault deposits are savings accumulations protecting goals, NOT out-of-pocket spending losses.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // =========================================================
                  // SEARCH BAR
                  // =========================================================
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.obsidian.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: _selectedSegment == 0
                            ? 'Search merchant, UPI, tag...'
                            : 'Search vault deposit, goal...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.onSurfaceVariant),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // =========================================================
                  // SUB-FILTERS & RECORD COUNT
                  // =========================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${displayedTransactions.length} ${_selectedSegment == 0 ? "Bank / UPI Records" : "Vault Deposits"}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (_selectedSegment == 0)
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              _buildSubFilterTab('all', 'All'),
                              _buildSubFilterTab('debit', 'Debits'),
                              _buildSubFilterTab('credit', 'Credits'),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // =========================================================
                  // TRANSACTION / DEPOSIT LIST
                  // =========================================================
                  if (displayedTransactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(
                            _selectedSegment == 0 ? Icons.receipt_long_outlined : Icons.savings_outlined,
                            size: 40,
                            color: AppColors.slateWhisper,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedSegment == 0
                                ? 'No transactions logged yet. Inflow/outflow updates automatically upon UPI or bank SMS detection.'
                                : 'No Goal Savings recorded in journal yet.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                          if (_selectedSegment == 0) ...[
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _isSyncingSms ? null : _handleSmsSync,
                              icon: _isSyncingSms
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync, size: 16),
                              label: const Text('Scan Inbox for Bank SMS'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.emeraldDark,
                                side: const BorderSide(color: AppColors.emerald),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedTransactions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tx = displayedTransactions[index];
                        final isVaultTx = _selectedSegment == 1 || tx.isVaultDeposit;

                        return Dismissible(
                          key: Key('ledger_${tx.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.crimson,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            provider.deleteTransaction(tx.id);
                            CenterAlert.show(
                              context,
                              message: 'Record Removed',
                              subtitle: tx.merchant,
                              icon: Icons.delete_outline_rounded,
                              iconColor: AppColors.crimson,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.obsidian.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isVaultTx
                                        ? const Color(0xFFEDE9FE)
                                        : (tx.isCredit
                                            ? AppColors.emeraldFixed.withOpacity(0.4)
                                            : const Color(0xFFFEE2E2)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isVaultTx
                                        ? Icons.shield_rounded
                                        : (tx.isCredit ? Icons.trending_up : Icons.receipt_outlined),
                                    size: 20,
                                    color: isVaultTx
                                        ? const Color(0xFF6D28D9)
                                        : (tx.isCredit ? AppColors.onEmeraldFixedVariant : AppColors.crimson),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Builder(
                                  builder: (context) {
                                    final target = provider.targets.where((t) => t.id == tx.targetId).firstOrNull ?? provider.primaryTarget;
                                    final goalTitle = isVaultTx ? (target?.title ?? (tx.merchant.isNotEmpty ? tx.merchant : 'Primary Vault')) : tx.merchant;
                                    final pacingText = (isVaultTx && target != null && target.targetCap > 0)
                                        ? '+${(tx.amount / target.targetCap * 100).toStringAsFixed(1)}% to goal cap'
                                        : 'Pacing Allocation';

                                    return Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  goalTitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontFamily: 'Plus Jakarta Sans',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: isVaultTx
                                                      ? const Color(0xFFDDD6FE)
                                                      : AppColors.surfaceContainerHigh,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isVaultTx ? 'GOAL SAVINGS' : tx.channel,
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: isVaultTx
                                                        ? const Color(0xFF5B21B6)
                                                        : AppColors.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            isVaultTx
                                                ? '${DateFormat('d MMM yyyy, HH:mm').format(tx.timestamp)} • $pacingText'
                                                : '${tx.category} • ${DateFormat('d MMM, HH:mm').format(tx.timestamp)}',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              color: isVaultTx ? const Color(0xFF6D28D9) : AppColors.onSurfaceVariant,
                                              fontWeight: isVaultTx ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                PrivacyText(
                                  rawText: isVaultTx
                                      ? '+${provider.formatCurrency(tx.amount)}'
                                      : tx.formattedAmountString,
                                  monetaryValue: tx.amount,
                                  isSigned: true,
                                  isDebit: !isVaultTx && tx.isDebit,
                                  style: AppTheme.monoNumeric(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isVaultTx
                                        ? const Color(0xFF6D28D9)
                                        : (tx.isDebit ? AppColors.crimson : AppColors.emerald),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 85),
        child: FloatingActionButton.extended(
          onPressed: () => AddTransactionModal.show(context),
          backgroundColor: AppColors.obsidian,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            _selectedSegment == 0 ? 'Log UPI Payment' : 'Deposit to Vault',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildSubFilterTab(String filterKey, String label) {
    final isSelected = _subFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _subFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.obsidian : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
