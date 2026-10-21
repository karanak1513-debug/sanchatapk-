import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String id;
  final double amount;
  final String type; // 'debit' or 'credit'
  final String merchant;
  final String channel; // 'UPI' | 'CASH' | 'BANK'
  final String source; // 'GPay' | 'PhonePe' | 'Paytm' | 'Manual'
  final String category; // 'Food', 'Commute', 'Bills', 'Reserve', etc.
  final DateTime timestamp;
  final bool isAutoCaptured;
  final String? userId;
  final String tag;

  final String? accountNumber;
  final String? referenceNumber;
  final double? balanceAfter;
  final String? rawText;
  final String? targetId;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.merchant,
    String? channel,
    required this.source,
    required this.category,
    required this.timestamp,
    this.isAutoCaptured = false,
    this.userId,
    String? tag,
    this.accountNumber,
    this.referenceNumber,
    this.balanceAfter,
    this.rawText,
    this.targetId,
  })  : channel = channel ?? (source.toUpperCase() == 'CASH' ? 'CASH' : (source.toUpperCase() == 'BANK' ? 'BANK' : 'UPI')),
        tag = tag ?? (isAutoCaptured ? 'Auto-Captured' : 'Live Intercepted');

  // Backward-compatible aliases for existing UI code
  String get title => merchant;
  String? get vaultId => targetId;

  // Classification getters
  bool get isVaultDeposit =>
      type.toLowerCase() == 'vault_deposit' ||
      type.toLowerCase() == 'internal_transfer' ||
      category.toUpperCase() == 'VAULT TRANSFER' ||
      category == 'Reserve Contribution' ||
      category == 'Vault Allocation';

  bool get isInternalTransfer =>
      isVaultDeposit || type.toLowerCase() == 'internal_transfer';

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
    return '$prefix$val';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'merchant': merchant,
      'title': merchant,
      'channel': channel,
      'source': source,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'isAutoCaptured': isAutoCaptured,
      'tag': tag,
      if (userId != null) 'userId': userId,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (referenceNumber != null) 'referenceNumber': referenceNumber,
      if (balanceAfter != null) 'balanceAfter': balanceAfter,
      if (rawText != null) 'rawText': rawText,
      if (targetId != null) 'targetId': targetId,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'amount': amount,
      'type': type.toLowerCase(),
      'merchant': merchant,
      'channel': channel,
      'source': source,
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
      'isAutoCaptured': isAutoCaptured,
      if (userId != null) 'userId': userId,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (referenceNumber != null) 'referenceNumber': referenceNumber,
      if (balanceAfter != null) 'balanceAfter': balanceAfter,
      if (rawText != null) 'rawText': rawText,
      if (targetId != null) 'targetId': targetId,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime = DateTime.now();
    if (json['timestamp'] != null) {
      if (json['timestamp'] is Timestamp) {
        parsedTime = (json['timestamp'] as Timestamp).toDate();
      } else if (json['timestamp'] is String) {
        parsedTime = DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now();
      } else if (json['timestamp'] is int) {
        parsedTime = DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int);
      }
    }

    final merchantName = (json['merchant'] as String?) ??
        (json['title'] as String?) ??
        (json['note'] as String?) ??
        'Transaction';

    final sourceName = (json['source'] as String?) ?? 'Manual';
    final channelName = (json['channel'] as String?) ??
        (sourceName.toUpperCase() == 'CASH' ? 'CASH' : 'UPI');

    final isAuto = (json['isAutoCaptured'] as bool?) ?? false;

    return Transaction(
      id: json['id'] as String? ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: (json['type'] as String?)?.toLowerCase() ?? 'debit',
      merchant: merchantName,
      channel: channelName,
      source: sourceName,
      category: json['category'] as String? ?? 'Reserve',
      timestamp: parsedTime,
      isAutoCaptured: isAuto,
      tag: json['tag'] as String? ?? (isAuto ? 'Auto-Captured' : 'Manual'),
      userId: json['userId'] as String?,
      accountNumber: json['accountNumber'] as String?,
      referenceNumber: json['referenceNumber'] as String?,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble(),
      rawText: json['rawText'] as String?,
      targetId: json['targetId'] as String?,
    );
  }

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final id = doc.id;

    DateTime parsedTime = DateTime.now();
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      parsedTime = rawTs.toDate();
    } else if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else if (rawTs is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    }

    final merchantName = (data['merchant'] as String?) ??
        (data['title'] as String?) ??
        (data['note'] as String?) ??
        'Transaction';

    final sourceName = (data['source'] as String?) ?? 'Manual';
    final channelName = (data['channel'] as String?) ??
        (sourceName.toUpperCase() == 'CASH' ? 'CASH' : 'UPI');

    final isAuto = (data['isAutoCaptured'] as bool?) ?? false;

    return Transaction(
      id: id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: (data['type'] as String?)?.toLowerCase() ?? 'debit',
      merchant: merchantName,
      channel: channelName,
      source: sourceName,
      category: data['category'] as String? ?? 'Reserve',
      timestamp: parsedTime,
      isAutoCaptured: isAuto,
      tag: data['tag'] as String? ?? (isAuto ? 'Auto-Captured' : 'Live Intercepted'),
      userId: data['userId'] as String?,
      accountNumber: data['accountNumber'] as String?,
      referenceNumber: data['referenceNumber'] as String?,
      balanceAfter: (data['balanceAfter'] as num?)?.toDouble(),
      rawText: data['rawText'] as String?,
      targetId: data['targetId'] as String?,
    );
  }

  Transaction copyWith({
    String? id,
    double? amount,
    String? type,
    String? merchant,
    String? channel,
    String? source,
    String? category,
    DateTime? timestamp,
    bool? isAutoCaptured,
    String? tag,
    String? userId,
    String? accountNumber,
    String? referenceNumber,
    double? balanceAfter,
    String? rawText,
    String? targetId,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      channel: channel ?? this.channel,
      source: source ?? this.source,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isAutoCaptured: isAutoCaptured ?? this.isAutoCaptured,
      tag: tag ?? this.tag,
      userId: userId ?? this.userId,
      accountNumber: accountNumber ?? this.accountNumber,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      rawText: rawText ?? this.rawText,
      targetId: targetId ?? this.targetId,
    );
  }
}
