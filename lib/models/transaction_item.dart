class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final String type; // 'debit' or 'credit'
  final String channel; // 'PhonePe', 'HDFC SMS', 'GPay', 'Paytm', etc.
  final String category; // 'Food & Dining', 'Direct Inflow', 'Transit', etc.
  final String tag; // 'Auto-Intercepted', 'Verified', etc.
  final DateTime timestamp;

  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.channel,
    required this.category,
    required this.tag,
    required this.timestamp,
  });

  bool get isVaultDeposit =>
      type.toLowerCase() == 'vault_deposit' ||
      category.toUpperCase() == 'VAULT TRANSFER' ||
      category == 'Reserve Contribution' ||
      category == 'Vault Allocation';

  bool get isDebit =>
      !isVaultDeposit &&
      (type.toLowerCase() == 'debit' || type.toLowerCase() == 'expense');

  bool get isCredit =>
      !isVaultDeposit &&
      (type.toLowerCase() == 'credit' || type.toLowerCase() == 'income');

  String get formattedAmountString {
    if (isVaultDeposit) {
      final val = amount.abs().toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
      return '₹$val';
    }
    final prefix = isDebit ? '-₹' : '+₹';
    final val = amount.abs().toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    // Format with commas for Indian currency
    return '$prefix$val';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'channel': channel,
      'category': category,
      'tag': tag,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as String? ?? UniqueKey().toString(),
      title: json['title'] as String? ?? 'Transaction',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'debit',
      channel: json['channel'] as String? ?? 'UPI',
      category: json['category'] as String? ?? 'General',
      tag: json['tag'] as String? ?? 'Auto-Intercepted',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// Simple fallback helper for UniqueKey when not importing material
class UniqueKey {
  static int _counter = 0;
  @override
  String toString() => 'tx_${DateTime.now().millisecondsSinceEpoch}_${++_counter}';
}
