import 'package:flutter/material.dart';

class VaultTarget {
  final String id;
  final String title;
  final double currentAmount;
  final double targetAmount;
  final IconData icon;
  final Color accentColor;
  final String subtitle;
  final bool autoPacing;

  VaultTarget({
    required this.id,
    required this.title,
    required this.currentAmount,
    required this.targetAmount,
    required this.icon,
    required this.accentColor,
    required this.subtitle,
    this.autoPacing = true,
  });

  double get progress => targetAmount <= 0 ? 0.0 : (currentAmount / targetAmount).clamp(0.0, 1.0);
  int get percentage => (progress * 100).round();
  double get remaining => (targetAmount - currentAmount).clamp(0.0, targetAmount);

  VaultTarget copyWith({
    String? id,
    String? title,
    double? currentAmount,
    double? targetAmount,
    IconData? icon,
    Color? accentColor,
    String? subtitle,
    bool? autoPacing,
  }) {
    return VaultTarget(
      id: id ?? this.id,
      title: title ?? this.title,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
      subtitle: subtitle ?? this.subtitle,
      autoPacing: autoPacing ?? this.autoPacing,
    );
  }
}
