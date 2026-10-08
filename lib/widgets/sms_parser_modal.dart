import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../services/sms_upi_parser_engine.dart';
import '../theme/app_theme.dart';
import 'center_alert.dart';

class SmsParserModal extends StatefulWidget {
  final String? initialText;

  const SmsParserModal({super.key, this.initialText});

  static Future<void> show(BuildContext context, {String? initialText}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmsParserModal(initialText: initialText),
    );
  }

  @override
  State<SmsParserModal> createState() => _SmsParserModalState();
}

class _SmsParserModalState extends State<SmsParserModal> {
  late TextEditingController _textController;
  ParsedFinancialSms? _parsedResult;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
    if (_textController.text.isNotEmpty) {
      _parseCurrentText();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseCurrentText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _parsedResult = null);
      return;
    }
    final res = SmsUpiParserEngine.parse(text: text);
    setState(() => _parsedResult = res);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _textController.text = data.text!;
      _parseCurrentText();
    }
  }

  void _applyPreset(Map<String, String> preset) {
    _textController.text = preset['text']!;
    _parseCurrentText();
  }

  Future<void> _saveParsedTransaction() async {
    if (_parsedResult == null) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<SanchayProvider>();
      final tx = _parsedResult!.toTransaction(
        userId: provider.currentUserId,
        customTag: 'Auto SMS/UPI Parsed',
      );

      await provider.addTransaction(tx);

      if (!mounted) return;
      Navigator.of(context).pop();

      CenterAlert.show(
        context,
        message: '✓ Transaction Recorded',
        subtitle: '${_parsedResult!.merchant} • ${provider.formatCurrency(_parsedResult!.amount)}',
        icon: Icons.check_circle_outline,
        iconColor: AppColors.emerald,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        CenterAlert.show(
          context,
          message: 'Error recording transaction',
          subtitle: e.toString(),
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.crimson,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.obsidian.withOpacity(0.12),
                  blurRadius: 36,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.crimson.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.mark_email_read_outlined,
                                color: AppColors.crimson, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AUTO SMS & UPI PARSER',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.crimson,
                                ),
                              ),
                              Text(
                                'Parse Bank & UPI Alert',
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
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerLow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Presets horizontal selector
                  Text(
                    'QUICK BANK SMS PRESETS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: SmsUpiParserEngine.samplePresets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final preset = SmsUpiParserEngine.samplePresets[i];
                        return InkWell(
                          onTap: () => _applyPreset(preset),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.surfaceContainerHigh,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              preset['name']!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.obsidian,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Text Input Area with Paste Button
                  Stack(
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 4,
                        minLines: 3,
                        onChanged: (_) => _parseCurrentText(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.obsidian,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Paste incoming SMS or UPI notification text here...\nE.g. Sent Rs.450 from HDFC Bank A/C *1234 to SWIGGY via UPI. Bal Rs.24,500.',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant.withOpacity(0.6),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLow,
                          contentPadding: const EdgeInsets.fromLTRB(14, 14, 70, 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.obsidian, width: 1.2),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: TextButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.content_paste, size: 14),
                          label: const Text('Paste'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.crimson,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Extracted Result Card
                  if (_parsedResult != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _parsedResult!.isCredit
                            ? AppColors.emeraldFixed.withOpacity(0.25)
                            : AppColors.crimsonFixedDim.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _parsedResult!.isCredit
                              ? AppColors.emerald.withOpacity(0.4)
                              : AppColors.crimson.withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _parsedResult!.isCredit
                                          ? AppColors.emerald
                                          : AppColors.crimson,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _parsedResult!.isCredit ? 'CREDIT' : 'DEBIT',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _parsedResult!.channel,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.obsidian,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                provider.formatCurrency(_parsedResult!.amount,
                                    isSigned: true, isDebit: _parsedResult!.isDebit),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _parsedResult!.isCredit
                                      ? AppColors.emerald
                                      : AppColors.obsidian,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _buildDetailRow('Merchant / Entity', _parsedResult!.merchant),
                          _buildDetailRow('Inferred Category', _parsedResult!.category),
                          _buildDetailRow('Source / Bank', _parsedResult!.source),
                          if (_parsedResult!.accountNumberLast4 != null)
                            _buildDetailRow('A/C Ending', '•••• ${_parsedResult!.accountNumberLast4!}'),
                          if (_parsedResult!.referenceNumber != null)
                            _buildDetailRow('UPI Ref / UTR', _parsedResult!.referenceNumber!),
                          if (_parsedResult!.balanceAfter != null)
                            _buildDetailRow(
                              'Available Balance',
                              provider.formatCurrency(_parsedResult!.balanceAfter!),
                              isHighlighted: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // One-tap Action Button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveParsedTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_task_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Record to Sanchay Ledger',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ] else if (_textController.text.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.amberPace.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.amberPace.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.amberPace, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Could not extract financial transaction details. Please check that the SMS includes an amount (e.g. Rs 500 or ₹500) and debit/credit status.',
                              style: TextStyle(fontSize: 11, color: AppColors.obsidian),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w700,
              color: isHighlighted ? AppColors.emerald : AppColors.obsidian,
            ),
          ),
        ],
      ),
    );
  }
}
