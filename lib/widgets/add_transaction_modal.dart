import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../providers/sanchay_provider.dart';
import '../providers/vault_provider.dart';
import '../theme/app_theme.dart';
import 'center_alert.dart';

class AddTransactionModal extends StatefulWidget {
  const AddTransactionModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddTransactionModal(),
    );
  }

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String _type = 'debit'; // 'debit' or 'credit'
  String _channel = 'PhonePe';
  String _category = 'Food & Dining';

  final List<String> _channels = ['PhonePe', 'GPay', 'Paytm', 'HDFC SMS', 'Cash'];
  final List<String> _categories = [
    'Food & Dining',
    'Transit',
    'Lifestyle',
    'Bills & Utilities',
    'Direct Inflow',
    'Investment',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amountVal = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amountVal <= 0) return;

    final id = 'tx_${DateTime.now().millisecondsSinceEpoch}';
    final title = _titleController.text.trim();
    final now = DateTime.now();
    final tag = _type == 'credit' ? 'Verified' : 'Auto-Intercepted';

    final newTx = Transaction(
      id: id,
      merchant: title,
      amount: amountVal,
      type: _type,
      source: _channel,
      category: _category,
      tag: 'Manual Record',
      timestamp: now,
    );

    final newTxItem = TransactionItem(
      id: id,
      title: title,
      amount: amountVal,
      type: _type,
      channel: _channel,
      category: _category,
      tag: tag,
      timestamp: now,
    );

    try {
      context.read<SanchayProvider>().addTransaction(newTx);
    } catch (_) {}

    try {
      context.read<VaultProvider>().addTransaction(newTxItem);
    } catch (_) {}

    Navigator.of(context).pop();

    CenterAlert.show(
      context,
      message: _type == 'debit'
          ? '₹${amountVal.toStringAsFixed(0)} Expense Recorded'
          : '₹${amountVal.toStringAsFixed(0)} Income Recorded',
      subtitle: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : _category,
      icon: _type == 'debit' ? Icons.arrow_outward_rounded : Icons.check_circle_rounded,
      iconColor: _type == 'debit' ? AppColors.crimson : AppColors.emerald,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.12),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pull Indicator
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

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CAPITAL COMMIT',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: AppColors.crimson,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Record Transaction',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainerLow,
                              shape: const CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Debit / Credit Toggle
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _type = 'debit'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _type == 'debit' ? AppColors.crimson : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _type == 'debit'
                                        ? [
                                            BoxShadow(
                                              color: AppColors.crimson.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Debit (Outflow)',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _type == 'debit' ? Colors.white : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _type = 'credit'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _type == 'credit' ? AppColors.emerald : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _type == 'credit'
                                        ? [
                                            BoxShadow(
                                              color: AppColors.emerald.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Credit (Inflow)',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _type == 'credit' ? Colors.white : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Amount Input
                      Text(
                        'AMOUNT (INR)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: AppTheme.monoNumeric(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: _type == 'debit' ? AppColors.crimson : AppColors.emerald,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: Text(
                              '₹',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: _type == 'debit' ? AppColors.crimson : AppColors.emerald,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 26,
                            color: AppColors.slateWhisper,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLow,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter an amount';
                          final d = double.tryParse(val.trim());
                          if (d == null || d <= 0) return 'Please enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Merchant / Title Input
                      Text(
                        'MERCHANT / DESCRIPTION',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'e.g. Swiggy Dinner, Salary, Uber',
                          hintStyle: TextStyle(color: AppColors.slateWhisper),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLow,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter a title';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Channel Selection
                      Text(
                        'PAYMENT CHANNEL',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _channels.map((ch) {
                          final isSelected = _channel == ch;
                          return ChoiceChip(
                            label: Text(ch),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _channel = ch);
                            },
                            selectedColor: AppColors.obsidian,
                            labelStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                            ),
                            backgroundColor: AppColors.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(
                                color: isSelected ? AppColors.obsidian : Colors.transparent,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Category Selection
                      Text(
                        'CATEGORY',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = _category == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _category = cat);
                            },
                            selectedColor: AppColors.obsidian,
                            labelStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                            ),
                            backgroundColor: AppColors.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(
                                color: isSelected ? AppColors.obsidian : Colors.transparent,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Commit Action Button
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _type == 'debit' ? AppColors.obsidian : AppColors.emerald,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _type == 'debit' ? Icons.check : Icons.account_balance_wallet,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _type == 'debit' ? 'Commit Outflow' : 'Commit Inflow',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
