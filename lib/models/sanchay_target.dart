import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SanchayTarget {
  final String id;
  final String title;
  final double targetCap;
  final double currentAccumulation;
  final DateTime targetDate;
  final bool isPaused;
  final DateTime? createdAt;

  // Multi-Vault Enhancement Fields
  final String category; // 'Emergency' | 'Travel' | 'Vehicle' | 'Gadget' | 'Property' | 'Investment' | 'General'
  final String accentColorHex; // e.g. '#DC2626'
  final String iconName; // e.g. 'security', 'flight', 'directions_car', etc.
  final String? imageUrl;
  final bool isPrimary;
  final int priority;

  SanchayTarget({
    required this.id,
    required this.title,
    required this.targetCap,
    this.currentAccumulation = 0.0,
    required this.targetDate,
    this.isPaused = false,
    this.createdAt,
    this.category = 'General',
    this.accentColorHex = '#DC2626',
    this.iconName = 'savings',
    this.imageUrl,
    this.isPrimary = false,
    this.priority = 0,
  });

  /// Resolves an ImageProvider supporting local FileImage fallback and remote NetworkImage
  ImageProvider? get imageProvider {
    if (imageUrl == null || imageUrl!.trim().isEmpty) return null;
    final path = imageUrl!.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    try {
      final f = File(path);
      if (f.existsSync()) {
        return FileImage(f);
      }
    } catch (_) {}
    return null;
  }

  // Calculate remaining days accurately
  int get remainingDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diff = target.difference(today).inDays;
    return diff > 0 ? diff : 1;
  }

  // Dynamic calculations
  double get remainingAmount => (targetCap - currentAccumulation).clamp(0.0, targetCap);
  double get progress => targetCap <= 0 ? 0.0 : (currentAccumulation / targetCap).clamp(0.0, 1.0);
  int get percentage => (progress * 100).round().clamp(0, 100);
  bool get isAchieved => currentAccumulation >= targetCap && targetCap > 0;

  // Dynamic Run-Rate Pacing
  double get dailyPace {
    if (isPaused || isAchieved) return 0.0;
    final rem = remainingAmount;
    if (rem <= 0) return 0.0;
    return rem / remainingDays;
  }

  double get weeklyPace => isPaused ? 0.0 : dailyPace * 7.0;
  double get monthlyPace => isPaused ? 0.0 : dailyPace * 30.0;

  // Visual Helpers
  Color get accentColor {
    try {
      final hex = accentColorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
    } catch (_) {}
    return const Color(0xFFDC2626);
  }

  Color get color => accentColor;

  IconData get iconData {
    switch (iconName.toLowerCase()) {
      case 'security':
      case 'shield':
      case 'emergency':
        return Icons.security_rounded;
      case 'flight':
      case 'travel':
      case 'vacation':
        return Icons.flight_takeoff_rounded;
      case 'directions_car':
      case 'car':
      case 'vehicle':
        return Icons.directions_car_rounded;
      case 'laptop':
      case 'gadget':
      case 'tech':
        return Icons.laptop_mac_rounded;
      case 'home':
      case 'house':
      case 'property':
        return Icons.home_rounded;
      case 'trending_up':
      case 'investment':
      case 'stocks':
        return Icons.trending_up_rounded;
      case 'school':
      case 'education':
        return Icons.school_rounded;
      case 'favorite':
      case 'wedding':
        return Icons.favorite_rounded;
      case 'savings':
      case 'piggy_bank':
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'targetCap': targetCap,
      'currentAccumulation': currentAccumulation,
      'targetDate': Timestamp.fromDate(targetDate),
      'isPaused': isPaused,
      'category': category,
      'accentColorHex': accentColorHex,
      'iconName': iconName,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl!.trim(),
      'isPrimary': isPrimary,
      'priority': priority,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'targetCap': targetCap,
      'currentAccumulation': currentAccumulation,
      'targetDate': targetDate.toIso8601String(),
      'isPaused': isPaused,
      'category': category,
      'accentColorHex': accentColorHex,
      'iconName': iconName,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl!.trim(),
      'isPrimary': isPrimary,
      'priority': priority,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory SanchayTarget.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now().add(const Duration(days: 45));
    if (json['targetDate'] != null) {
      if (json['targetDate'] is Timestamp) {
        parsedDate = (json['targetDate'] as Timestamp).toDate();
      } else if (json['targetDate'] is String) {
        parsedDate = DateTime.tryParse(json['targetDate'] as String) ?? parsedDate;
      }
    }

    DateTime? created;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        created = (json['createdAt'] as Timestamp).toDate();
      } else if (json['createdAt'] is String) {
        created = DateTime.tryParse(json['createdAt'] as String);
      }
    }

    return SanchayTarget(
      id: json['id'] as String? ?? 'vault_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Savings Vault',
      targetCap: (json['targetCap'] as num?)?.toDouble() ?? 100000.0,
      currentAccumulation: (json['currentAccumulation'] as num?)?.toDouble() ?? 0.0,
      targetDate: parsedDate,
      isPaused: json['isPaused'] as bool? ?? false,
      category: json['category'] as String? ?? 'General',
      accentColorHex: json['accentColorHex'] as String? ?? '#DC2626',
      iconName: json['iconName'] as String? ?? 'savings',
      imageUrl: json['imageUrl'] as String? ?? json['imagePath'] as String?,
      isPrimary: json['isPrimary'] as bool? ?? false,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      createdAt: created,
    );
  }

  factory SanchayTarget.fromFirestore(DocumentSnapshot doc, {double? liveAccumulation}) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime parsedDate = DateTime.now().add(const Duration(days: 45));
    final rawDate = data['deadline'] ?? data['targetDate'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? parsedDate;
    }

    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    }

    final isDefaultPrimary = doc.id == 'primary_vault';
    final isPaused = data['isPaused'] as bool? ?? !(data['isActive'] as bool? ?? true);

    String resolvedColorHex = data['accentColorHex'] as String? ?? (isDefaultPrimary ? '#DC2626' : '#059669');
    if (data['colorValue'] != null && data['colorValue'] is int) {
      final cv = data['colorValue'] as int;
      resolvedColorHex = '#${(cv & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }

    return SanchayTarget(
      id: doc.id,
      title: data['title'] as String? ?? 'Master Vault Reserve',
      targetCap: (data['targetCap'] as num?)?.toDouble() ?? 100000.0,
      currentAccumulation: liveAccumulation ?? ((data['currentAccumulation'] as num?)?.toDouble() ?? 0.0),
      targetDate: parsedDate,
      isPaused: isPaused,
      category: data['category'] as String? ?? 'General',
      accentColorHex: resolvedColorHex,
      iconName: data['iconName'] as String? ?? (isDefaultPrimary ? 'security' : 'savings'),
      imageUrl: data['bannerUrl'] as String? ?? data['imageUrl'] as String? ?? data['imagePath'] as String?,
      isPrimary: data['isPrimary'] as bool? ?? isDefaultPrimary,
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      createdAt: created,
    );
  }

  SanchayTarget copyWith({
    String? id,
    String? title,
    double? targetCap,
    double? currentAccumulation,
    DateTime? targetDate,
    bool? isPaused,
    DateTime? createdAt,
    String? category,
    String? accentColorHex,
    String? iconName,
    String? imageUrl,
    bool? isPrimary,
    int? priority,
  }) {
    return SanchayTarget(
      id: id ?? this.id,
      title: title ?? this.title,
      targetCap: targetCap ?? this.targetCap,
      currentAccumulation: currentAccumulation ?? this.currentAccumulation,
      targetDate: targetDate ?? this.targetDate,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      iconName: iconName ?? this.iconName,
      imageUrl: imageUrl ?? this.imageUrl,
      isPrimary: isPrimary ?? this.isPrimary,
      priority: priority ?? this.priority,
    );
  }
}
