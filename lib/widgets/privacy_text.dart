import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';

class PrivacyText extends StatelessWidget {
  final String rawText;
  final TextStyle? style;
  final num? monetaryValue;
  final bool isSigned;
  final bool isDebit;

  const PrivacyText({
    super.key,
    required this.rawText,
    this.style,
    this.monetaryValue,
    this.isSigned = false,
    this.isDebit = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VaultProvider>();
    final isMasked = provider.isPrivacyMasked;

    String displayText;
    if (isMasked) {
      displayText = '••••••';
    } else if (monetaryValue != null) {
      displayText = provider.formatCurrency(
        monetaryValue!,
        isSigned: isSigned,
        isDebit: isDebit,
      );
    } else {
      displayText = rawText;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: Text(
        displayText,
        key: ValueKey<String>('$displayText-$isMasked'),
        style: style,
      ),
    );
  }
}
