import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../theme/app_theme.dart';
import 'center_alert.dart';

class VaultTransferModal extends StatefulWidget {
  final String? initialFromVaultId;

  const VaultTransferModal({super.key, this.initialFromVaultId});

  static Future<void> show(BuildContext context, {String? initialFromVaultId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VaultTransferModal(initialFromVaultId: initialFromVaultId),
    );
  }

  @override
  State<VaultTransferModal> createState() => _VaultTransferModalState();
}

class _VaultTransferModalState extends State<VaultTransferModal> {
  final _amountController = TextEditingController();
  String? _fromVaultId;
  String? _toVaultId;
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SanchayProvider>();
    final targets = provider.targets;
    if (targets.length >= 2) {
      _fromVaultId = widget.initialFromVaultId ?? targets[0].id;
      _toVaultId = targets.firstWhere((t) => t.id != _fromVaultId, orElse: () => targets[1]).id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _executeTransfer() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0 || _fromVaultId == null || _toVaultId == null) {
      CenterAlert.show(
        context,
        message: 'Enter a valid transfer amount',
        icon: Icons.info_outline,
        iconColor: AppColors.amberPace,
      );
      return;
    }

    final provider = context.read<SanchayProvider>();
    final fromTarget = provider.targets.firstWhere((t) => t.id == _fromVaultId);
    if (amount > fromTarget.currentAccumulation) {
      CenterAlert.show(
        context,
        message: 'Insufficient balance in ${fromTarget.title}',
        subtitle: 'Available: ${provider.formatCurrency(fromTarget.currentAccumulation)}',
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.crimson,
      );
      return;
    }

    setState(() => _isTransferring = true);

    try {
      await provider.transferBetweenVaults(
        fromVaultId: _fromVaultId!,
        toVaultId: _toVaultId!,
        amount: amount,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      final toTarget = provider.targets.firstWhere((t) => t.id == _toVaultId);
      CenterAlert.show(
        context,
        message: '✓ Transfer Complete',
        subtitle: '${provider.formatCurrency(amount)} moved to ${toTarget.title}',
        icon: Icons.swap_horiz_rounded,
        iconColor: AppColors.emerald,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isTransferring = false);
        CenterAlert.show(
          context,
          message: 'Transfer failed',
          subtitle: e.toString(),
          icon: Icons.error_outline,
          iconColor: AppColors.crimson,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final targets = provider.targets;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    if (targets.length < 2) {
      return Container(
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: const Text('You need at least 2 active vaults to transfer between them.'),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.obsidian.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.swap_horiz, color: AppColors.obsidian, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INTER-VAULT CAPITAL FLOW',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.obsidian,
                                ),
                              ),
                              Text(
                                'Transfer Between Vaults',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.obsidian,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(backgroundColor: AppColors.surfaceContainerLow),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // From Vault Dropdown
                  Text('FROM VAULT', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _fromVaultId,
                        isExpanded: true,
                        items: targets.map((t) {
                          return DropdownMenuItem<String>(
                            value: t.id,
                            child: Text(
                              '${t.title} (Available: ${provider.formatCurrency(t.currentAccumulation)})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _fromVaultId = val;
                              if (_toVaultId == val) {
                                _toVaultId = targets.firstWhere((t) => t.id != val).id;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // To Vault Dropdown
                  Text('TO VAULT', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _toVaultId,
                        isExpanded: true,
                        items: targets.where((t) => t.id != _fromVaultId).map((t) {
                          return DropdownMenuItem<String>(
                            value: t.id,
                            child: Text(
                              '${t.title} (Goal: ${provider.formatCurrency(t.targetCap)})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _toVaultId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount Input
                  Text('TRANSFER AMOUNT (₹)', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.obsidian),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.obsidian),
                      hintText: '5000',
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _isTransferring ? null : _executeTransfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.obsidian,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isTransferring
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Execute Transfer',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
