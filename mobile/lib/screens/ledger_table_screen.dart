import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/sanchay_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/center_alert.dart';
import '../widgets/glass_card.dart';
import '../widgets/privacy_text.dart';
import '../widgets/data_export_modal.dart';
import '../widgets/sms_parser_modal.dart';

class LedgerTableScreen extends StatefulWidget {
  const LedgerTableScreen({super.key});

  @override
  State<LedgerTableScreen> createState() => _LedgerTableScreenState();
}

class _LedgerTableScreenState extends State<LedgerTableScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'debit', 'credit'
  bool _isTableView = false; // default: full minimal list view

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food & Dining':
        return const Color(0xFFDC2626); // Crimson
      case 'Transit':
        return const Color(0xFF0284C7); // Sky
      case 'Bills & Utilities':
        return const Color(0xFFD97706); // Amber
      case 'Lifestyle':
        return const Color(0xFF7C3AED); // Electric Violet
      case 'Investment':
        return const Color(0xFF059669); // Emerald
      case 'Direct Inflow':
      case 'Salary':
        return const Color(0xFF10B981); // Mint
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getSourceIcon(String source) {
    final s = source.toUpperCase();
    if (s.contains('PHONEPE')) return Icons.bolt;
    if (s.contains('GPAY') || s.contains('GOOGLE')) return Icons.account_balance_wallet;
    if (s.contains('PAYTM')) return Icons.payment;
    if (s.contains('SMS') || s.contains('BANK')) return Icons.sms_outlined;
    if (s.contains('CASH')) return Icons.attach_money;
    return Icons.currency_rupee;
  }

  void _showTransactionDetails(BuildContext context, Transaction tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.obsidian.withOpacity(0.12),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(tx.category).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tx.category.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: _getCategoryColor(tx.category),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tx.tag,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              tx.merchant,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Consumer<SanchayProvider>(
              builder: (context, p, child) => Text(
                p.formatCurrency(tx.amount, isSigned: true, isDebit: tx.isDebit),
                style: AppTheme.monoNumeric(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: tx.isDebit ? AppColors.crimson : AppColors.emerald,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.surfaceContainerHigh),
            const SizedBox(height: 8),
            _buildDetailRow('Timestamp', DateFormat('dd MMM yyyy, hh:mm a').format(tx.timestamp)),
            _buildDetailRow('Payment Channel', tx.source),
            _buildDetailRow('Transaction Type', tx.isDebit ? 'Debit / Outflow' : 'Credit / Inflow'),
            _buildDetailRow('Reference Document ID', tx.id),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tx.toJson().toString()));
                      CenterAlert.show(
                        context,
                        message: 'Metadata Copied',
                        subtitle: 'Transaction JSON saved to clipboard',
                        icon: Icons.copy_rounded,
                        iconColor: AppColors.obsidian,
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy JSON'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.read<SanchayProvider>().deleteTransaction(tx.id);
                      CenterAlert.show(
                        context,
                        message: 'Transaction Removed',
                        subtitle: tx.merchant,
                        icon: Icons.delete_outline_rounded,
                        iconColor: AppColors.crimson,
                      );
                    },
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                    label: const Text('Delete Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context, SanchayProvider provider) {
    DataExportModal.show(context);
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final allTxs = provider.transactions;

    final autoUpiCount = allTxs
        .where((tx) => tx.isAutoCaptured || tx.channel.toUpperCase() == 'UPI')
        .length;
    final manualCount = allTxs
        .where((tx) =>
            !tx.isAutoCaptured ||
            tx.channel.toUpperCase() == 'VAULT_MANUAL' ||
            tx.channel.toUpperCase() == 'MANUAL')
        .length;

    // Apply Filter: [All], [Auto UPI Intercepts], or [Manual Deposits]
    final filteredByType = allTxs.where((tx) {
      if (_filterType == 'auto_upi') {
        return tx.isAutoCaptured || tx.channel.toUpperCase() == 'UPI';
      }
      if (_filterType == 'manual') {
        return !tx.isAutoCaptured ||
            tx.channel.toUpperCase() == 'VAULT_MANUAL' ||
            tx.channel.toUpperCase() == 'MANUAL';
      }
      if (_filterType == 'debit') return tx.isDebit;
      if (_filterType == 'credit') return tx.isCredit;
      return true;
    }).toList();

    // Apply Search Filter
    final query = _searchQuery.trim().toLowerCase();
    final displayedTxs = query.isEmpty
        ? filteredByType
        : filteredByType.where((tx) {
            return tx.merchant.toLowerCase().contains(query) ||
                tx.category.toLowerCase().contains(query) ||
                tx.source.toLowerCase().contains(query) ||
                tx.id.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        bottom: false, // Navigation dock handles bottom clearance
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Responsive App Header
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              sliver: SliverToBoxAdapter(
                child: _buildTopHeader(context, provider),
              ),
            ),

            // Screen Body with Strict Spacing & Bottom Dock Clearance
            SliverPadding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  // Summary Metric Cards
                  _buildSummaryCards(provider),
                  const SizedBox(height: 20),

                  // Controls: Search bar & Quick actions
                  _buildSearchAndFilters(
                    context,
                    provider,
                    allTxs.length,
                    autoUpiCount,
                    manualCount,
                  ),
                  const SizedBox(height: 20),

                  // High-Density Financial Data Container
                  GlassCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Minimalist Table/List Title Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.receipt_long_rounded, size: 17, color: AppColors.obsidian),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ledger Entries',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            color: AppColors.onSurface,
                                          ),
                                        ),
                                        Text(
                                          '${displayedTxs.length} Transactions',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // View Switcher: Minimal List vs Table Grid
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildViewToggleBtn(
                                    icon: Icons.format_list_bulleted_rounded,
                                    isActive: !_isTableView,
                                    tooltip: 'Minimal List',
                                    onTap: () => setState(() => _isTableView = false),
                                  ),
                                  const SizedBox(width: 2),
                                  _buildViewToggleBtn(
                                    icon: Icons.grid_view_rounded,
                                    isActive: _isTableView,
                                    tooltip: 'Detailed Table',
                                    onTap: () => setState(() => _isTableView = true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Content: Minimalist List (Default) or Detailed Grid / Empty State
                        if (displayedTxs.isEmpty)
                          _buildEmptyState(context, allTxs.isEmpty)
                        else if (!_isTableView)
                          _buildMinimalListView(context, provider, displayedTxs)
                        else
                          _buildDataTable(context, provider, displayedTxs),
                      ],
                    ),
                  ),

                  // MANDATORY BOTTOM CLEARANCE FOR FLOATING DOCK
                  const SizedBox(height: 120),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, SanchayProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 22,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SANCHAT WEALTH',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.crimson,
                        ),
                      ),
                      Text(
                        'Executive Ledger',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Parse SMS / UPI
              IconButton(
                tooltip: 'Parse SMS / UPI',
                onPressed: () => SmsParserModal.show(context),
                icon: const Icon(Icons.sms_outlined, size: 20, color: AppColors.onSurfaceVariant),
              ),
              // Export Button
              IconButton(
                tooltip: 'Export CSV / JSON',
                onPressed: () => _showExportOptions(context, provider),
                icon: const Icon(Icons.download_outlined, size: 20, color: AppColors.onSurfaceVariant),
              ),
              // Privacy Mode Toggle Eye Icon
              IconButton(
                tooltip: provider.isPrivacyMasked ? 'Reveal Balances' : 'Mask Balances',
                onPressed: () => provider.togglePrivacyMask(),
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
    );
  }

  Widget _buildSummaryCards(SanchayProvider provider) {
    return Row(
      children: [
        // Credits Card
        Expanded(
          child: GlassCard(
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.arrow_downward, color: AppColors.emerald, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'CREDITS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                PrivacyText(
                  rawText: '₹${provider.totalCredits.toStringAsFixed(0)}',
                  monetaryValue: provider.totalCredits,
                  isSigned: true,
                  isDebit: false,
                  style: AppTheme.monoNumeric(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emerald,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Debits Card
        Expanded(
          child: GlassCard(
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.arrow_upward, color: AppColors.crimson, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'DEBITS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.crimson,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                PrivacyText(
                  rawText: '₹${provider.totalDebits.toStringAsFixed(0)}',
                  monetaryValue: provider.totalDebits,
                  isSigned: true,
                  isDebit: true,
                  style: AppTheme.monoNumeric(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.crimson,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Net Cashflow Card
        Expanded(
          child: GlassCard(
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.account_balance, color: AppColors.obsidian, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'NET FLOW',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.obsidian,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                PrivacyText(
                  rawText: '₹${provider.netSavings.toStringAsFixed(0)}',
                  monetaryValue: provider.netSavings,
                  isSigned: true,
                  isDebit: provider.netSavings < 0,
                  style: AppTheme.monoNumeric(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: provider.netSavings >= 0 ? AppColors.emerald : AppColors.crimson,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggleBtn({
    required IconData icon,
    required bool isActive,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.obsidian.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 15,
            color: isActive ? AppColors.obsidian : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalListView(
    BuildContext context,
    SanchayProvider provider,
    List<Transaction> transactions,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => Divider(
        height: 16,
        thickness: 0.8,
        color: AppColors.surfaceContainerHigh.withOpacity(0.5),
      ),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final catColor = _getCategoryColor(tx.category);

        return InkWell(
          onTap: () => _showTransactionDetails(context, tx),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Direction Icon Badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tx.isDebit
                        ? AppColors.crimsonFixed
                        : AppColors.emeraldFixed,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tx.isDebit ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                    size: 17,
                    color: tx.isDebit ? AppColors.crimson : AppColors.emerald,
                  ),
                ),
                const SizedBox(width: 12),

                // Merchant & Metadata Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tx.merchant,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            DateFormat('dd MMM, HH:mm').format(tx.timestamp),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.outlineVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              tx.source,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.obsidian,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.outlineVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              tx.category,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: catColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Monetary Amount
                PrivacyText(
                  rawText: provider.formatCurrency(
                    tx.amount,
                    isSigned: true,
                    isDebit: tx.isDebit,
                  ),
                  monetaryValue: tx.amount,
                  isSigned: true,
                  isDebit: tx.isDebit,
                  style: AppTheme.monoNumeric(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tx.isDebit ? AppColors.crimson : AppColors.emerald,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context,
    SanchayProvider provider,
    int allCount,
    int autoUpiCount,
    int manualCount,
  ) {
    return Column(
      children: [
        // Sleek Minimal Search Input
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.obsidian.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Search merchant, category, or source...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              prefixIcon: const Icon(Icons.search, size: 17, color: AppColors.onSurfaceVariant),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppColors.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Responsive Filter Segment: [All], [Auto UPI Intercepts], [Manual Deposits] & Add Action
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildFilterTab('all', 'All ($allCount)'),
            ),
            const SizedBox(width: 5),
            Expanded(
              flex: 5,
              child: _buildFilterTab('auto_upi', 'Auto UPI ($autoUpiCount)'),
            ),
            const SizedBox(width: 5),
            Expanded(
              flex: 4,
              child: _buildFilterTab('manual', 'Manual ($manualCount)'),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => AddTransactionModal.show(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.obsidian,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, size: 15, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterTab(String type, String label) {
    final isSelected = _filterType == type;
    return InkWell(
      onTap: () => setState(() => _filterType = type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.obsidian : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.obsidian : AppColors.surfaceContainerHigh,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isOverallEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.obsidian.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 28, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Text(
            isOverallEmpty ? 'Zero Ledger Entries' : 'No Matching Records Found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOverallEmpty
                ? 'Incoming PhonePe, GPay, Paytm receipts, and manual commits will populate this high-density financial table in real-time.'
                : 'Try adjusting your search criteria or switching the active tab filter.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (isOverallEmpty) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => AddTransactionModal.show(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add First Transaction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.obsidian,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    SanchayProvider provider,
    List<Transaction> transactions,
  ) {
    // Dynamic height based on number of rows up to a healthy view size
    final double tableHeight = (transactions.length * 52.0 + 56.0).clamp(200.0, 520.0);

    return SizedBox(
      height: tableHeight,
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 8,
        minWidth: 680, // Enables horizontal scrolling on narrow screens
        headingRowHeight: 44,
        dataRowHeight: 52,
        headingRowColor: WidgetStateProperty.all(
          AppColors.surfaceContainerLow.withOpacity(0.6),
        ),
        headingTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.onSurfaceVariant,
        ),
        columns: const [
          DataColumn2(
            label: Text('DATE / TIME'),
            size: ColumnSize.S,
            fixedWidth: 110,
          ),
          DataColumn2(
            label: Text('ENTITY / MERCHANT'),
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text('SOURCE'),
            size: ColumnSize.M,
            fixedWidth: 115,
          ),
          DataColumn2(
            label: Text('CATEGORY'),
            size: ColumnSize.M,
            fixedWidth: 130,
          ),
          DataColumn2(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('AMOUNT'),
            ),
            size: ColumnSize.S,
            fixedWidth: 120,
            numeric: true,
          ),
        ],
        rows: transactions.map((tx) {
          final catColor = _getCategoryColor(tx.category);

          return DataRow2(
            onTap: () => _showTransactionDetails(context, tx),
            cells: [
              // 1. Date / Time
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMM').format(tx.timestamp),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(tx.timestamp),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Entity / Merchant
              DataCell(
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: tx.isDebit
                            ? AppColors.crimsonFixed
                            : AppColors.emeraldFixed,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        tx.isDebit ? Icons.arrow_outward : Icons.arrow_downward,
                        size: 14,
                        color: tx.isDebit ? AppColors.crimson : AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tx.merchant,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Source Badge
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.surfaceContainerHigh),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSourceIcon(tx.source),
                        size: 12,
                        color: AppColors.obsidian,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tx.source,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Category Tag
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tx.category,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: catColor,
                    ),
                  ),
                ),
              ),

              // 5. Amount (Monospaced & Right Aligned)
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    provider.formatCurrency(
                      tx.amount,
                      isSigned: true,
                      isDebit: tx.isDebit,
                    ),
                    style: AppTheme.monoNumeric(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tx.isDebit ? AppColors.crimson : AppColors.emerald,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
