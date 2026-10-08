import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/sanchay_target.dart';
import '../providers/sanchay_provider.dart';
import '../theme/app_theme.dart';
import 'center_alert.dart';

class VaultContributionModal extends StatefulWidget {
  final double? initialAmount;
  final String? initialType;
  final SanchayTarget? target;

  const VaultContributionModal({
    super.key,
    this.initialAmount,
    this.initialType,
    this.target,
  });

  /// Opens the frosted glass bottom sheet modal
  static Future<void> show(
    BuildContext context, {
    double? initialAmount,
    String? initialType,
    SanchayTarget? target,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VaultContributionModal(
        initialAmount: initialAmount,
        initialType: initialType,
        target: target,
      ),
    );
  }

  @override
  State<VaultContributionModal> createState() => _VaultContributionModalState();
}

class _VaultContributionModalState extends State<VaultContributionModal> {
  late TextEditingController _amountController;
  final FocusNode _amountFocusNode = FocusNode();

  // Contribution Type: 'Daily Quota' | 'Weekly Quota' | 'Custom Inflow'
  late String _contributionType;

  // Payment Mode / Source: 'UPI / Bank' | 'Cash Reserve' | 'Direct Goal Allocation'
  String _paymentMode = 'UPI / Bank';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _contributionType = widget.initialType ?? 'Daily Quota';

    String initialText = '';
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      final amt = widget.initialAmount!;
      initialText = amt.truncateToDouble() == amt ? amt.toInt().toString() : amt.toStringAsFixed(0);
    }

    _amountController = TextEditingController(text: initialText);

    // If initial amount wasn't passed and type is Daily Quota, pre-fill in post-frame callback
    if (initialText.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<SanchayProvider>();
        if (_contributionType == 'Daily Quota') {
          _setPresetAmount(provider.dailyPace);
        } else if (_contributionType == 'Weekly Quota') {
          _setPresetAmount(provider.weeklyPace);
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _setPresetAmount(double amount) {
    if (amount <= 0) return;
    final val = amount.roundToDouble();
    final str = val.truncateToDouble() == val ? val.toInt().toString() : val.toStringAsFixed(0);
    setState(() {
      _amountController.text = str;
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: str.length),
      );
    });
  }

  void _quickAddAmount(double addition) {
    final current = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final total = current + addition;
    _setPresetAmount(total);
  }

  double get _parsedAmount {
    return double.tryParse(_amountController.text.trim()) ?? 0.0;
  }

  String _mapPaymentModeToChannel(String mode) {
    switch (mode) {
      case 'Cash Reserve':
        return 'CASH';
      case 'Direct Goal Allocation':
        return 'BANK';
      case 'UPI / Bank':
      default:
        return 'UPI';
    }
  }

  Future<void> _submitDeposit() async {
    final amount = _parsedAmount;
    if (amount <= 0) {
      CenterAlert.show(
        context,
        message: 'Please enter a valid amount',
        icon: Icons.info_outline_rounded,
        iconColor: const Color(0xFFF59E0B),
      );
      _amountFocusNode.requestFocus();
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<SanchayProvider>();
    final target = widget.target ?? provider.primaryTarget;
    final targetId = target?.id ?? provider.primaryTargetId;
    final channel = _mapPaymentModeToChannel(_paymentMode);

    try {
      await provider.contributeToVault(
        amount: amount,
        targetId: targetId,
        contributionType: _contributionType,
        channel: channel,
        source: _paymentMode,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      CenterAlert.show(
        context,
        message: '✓ ${provider.formatCurrency(amount)} Added to Savings',
        subtitle: 'Savings Goal updated',
        icon: Icons.check_circle_outline,
        iconColor: AppColors.emerald,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      CenterAlert.show(
        context,
        message: 'Could not deposit to savings',
        subtitle: e.toString(),
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.crimson,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final target = widget.target ?? provider.primaryTarget;
    final targetName = target?.title ?? provider.targetName;
    final currentVault = provider.currentVault;
    final goalCap = target?.targetCap ?? provider.goalCap;
    final inputAmount = _parsedAmount;
    final newVault = currentVault + inputAmount;
    final currentProgress = goalCap <= 0 ? 0.0 : (currentVault / goalCap).clamp(0.0, 1.0);
    final newProgress = goalCap <= 0 ? 0.0 : (newVault / goalCap).clamp(0.0, 1.0);
    final currentPct = (currentProgress * 100).round();
    final newPct = (newProgress * 100).round();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.obsidian.withOpacity(0.12),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pull Handle Indicator
                    Center(
                      child: Container(
                        width: 42,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AppColors.obsidian.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header Row with Vault Badge & Close
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldFixed.withOpacity(0.35),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.emerald.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.savings_outlined,
                                color: AppColors.emerald,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'DEPOSIT INTO VAULT',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: AppColors.emerald,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.emeraldFixed.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Instant Sync',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onEmeraldFixedVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  targetName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.obsidian,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.obsidian,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 1. Contribution Type: Segmented Selector
                    // [ Daily Quota ] | [ Weekly Quota ] | [ Custom Inflow ]
                    Text(
                      'CONTRIBUTION TYPE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildSegmentItem(
                            title: 'Daily Quota',
                            subtitle: provider.formatCurrency(provider.dailyPace),
                            isSelected: _contributionType == 'Daily Quota',
                            onTap: () {
                              setState(() => _contributionType = 'Daily Quota');
                              _setPresetAmount(provider.dailyPace);
                            },
                          ),
                          _buildSegmentItem(
                            title: 'Weekly Quota',
                            subtitle: provider.formatCurrency(provider.weeklyPace),
                            isSelected: _contributionType == 'Weekly Quota',
                            onTap: () {
                              setState(() => _contributionType = 'Weekly Quota');
                              _setPresetAmount(provider.weeklyPace);
                            },
                          ),
                          _buildSegmentItem(
                            title: 'Custom Inflow',
                            subtitle: 'Flexible',
                            isSelected: _contributionType == 'Custom Inflow',
                            onTap: () {
                              setState(() => _contributionType = 'Custom Inflow');
                              _amountFocusNode.requestFocus();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Amount Input Field with Number Keypad
                    Text(
                      'CONTRIBUTION AMOUNT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: inputAmount > 0 ? AppColors.emerald : AppColors.outlineVariant.withOpacity(0.4),
                          width: inputAmount > 0 ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.obsidian.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(
                            '₹',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: inputAmount > 0 ? AppColors.emerald : AppColors.slateWhisper,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              focusNode: _amountFocusNode,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(9),
                              ],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.obsidian,
                                letterSpacing: -0.5,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.slateWhisper.withOpacity(0.6),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_amountController.text.isNotEmpty)
                            InkWell(
                              onTap: () {
                                _amountController.clear();
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Addition Chips row: [+₹500], [+₹1,000], [+₹2,000], [+ Today's Quota]
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildQuickChip(
                            label: '+₹500',
                            onTap: () => _quickAddAmount(500),
                          ),
                          const SizedBox(width: 8),
                          _buildQuickChip(
                            label: '+₹1,000',
                            onTap: () => _quickAddAmount(1000),
                          ),
                          const SizedBox(width: 8),
                          _buildQuickChip(
                            label: '+₹2,000',
                            onTap: () => _quickAddAmount(2000),
                          ),
                          const SizedBox(width: 8),
                          _buildQuickChip(
                            label: '+ Today\'s Quota (${provider.formatCurrency(provider.dailyPace)})',
                            isAccent: true,
                            onTap: () {
                              setState(() => _contributionType = 'Daily Quota');
                              _setPresetAmount(provider.dailyPace);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Payment Mode / Source Pills:
                    // [ UPI / Bank ] | [ Cash Reserve ] | [ Direct Goal Allocation ]
                    Text(
                      'PAYMENT SOURCE / CHANNEL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPaymentModePill(
                          label: 'UPI / Bank',
                          icon: Icons.qr_code_scanner,
                          mode: 'UPI / Bank',
                        ),
                        const SizedBox(width: 8),
                        _buildPaymentModePill(
                          label: 'Cash Reserve',
                          icon: Icons.payments_outlined,
                          mode: 'Cash Reserve',
                        ),
                        const SizedBox(width: 8),
                        _buildPaymentModePill(
                          label: 'Direct Allocation',
                          icon: Icons.account_balance_outlined,
                          mode: 'Direct Goal Allocation',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 4. Live Impact Preview Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vault After Deposit',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    provider.formatCurrency(currentVault),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                      decoration: inputAmount > 0 ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (inputAmount > 0) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward, size: 12, color: AppColors.emerald),
                                    const SizedBox(width: 6),
                                    Text(
                                      provider.formatCurrency(newVault),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.emerald,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Mini dynamic progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 6,
                              color: AppColors.surfaceContainerHighest,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: (newProgress * 1000).toInt(),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.emeraldFixed,
                                            AppColors.emerald,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: ((1.0 - newProgress) * 1000).toInt(),
                                    child: const SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                inputAmount > 0 ? '$currentPct% → $newPct% Achieved' : '$currentPct% Achieved',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: inputAmount > 0 ? AppColors.emerald : AppColors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${provider.formatCurrency((goalCap - newVault).clamp(0.0, goalCap))} Remaining',
                                style: AppTheme.monoNumeric(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 5. Primary Action Button: "Deposit into Vault"
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitDeposit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock_clock_outlined,
                                  size: 18,
                                  color: AppColors.emeraldFixed,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  inputAmount > 0
                                      ? 'Deposit ${provider.formatCurrency(inputAmount)} into Vault'
                                      : 'Deposit into Vault',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentItem({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.obsidian.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.obsidian : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.emerald : AppColors.slateWhisper,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isAccent ? AppColors.emeraldFixed.withOpacity(0.35) : AppColors.surfaceContainerHigh.withOpacity(0.7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isAccent ? AppColors.emerald.withOpacity(0.35) : AppColors.outlineVariant.withOpacity(0.35),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isAccent ? AppColors.onEmeraldFixedVariant : AppColors.obsidian,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentModePill({
    required String label,
    required IconData icon,
    required String mode,
  }) {
    final isSelected = _paymentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.obsidian : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.obsidian : AppColors.outlineVariant.withOpacity(0.35),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.obsidian.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.emeraldFixed : AppColors.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.obsidian,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
