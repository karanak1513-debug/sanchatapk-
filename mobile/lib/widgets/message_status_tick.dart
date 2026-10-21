import 'package:flutter/material.dart';

class MessageStatusTick extends StatelessWidget {
  final String status;
  final double size;
  final Color? colorOverride;

  const MessageStatusTick({
    super.key,
    required this.status,
    this.size = 14,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final cleanStatus = status.toLowerCase();

    if (cleanStatus == 'seen' || cleanStatus == 'read') {
      // Double vibrant blue check
      return Icon(
        Icons.done_all,
        size: size,
        color: colorOverride ?? const Color(0xFF0284C7),
      );
    }

    if (cleanStatus == 'delivered') {
      // Double grey check
      return Icon(
        Icons.done_all,
        size: size,
        color: colorOverride ?? Colors.grey,
      );
    }

    if (cleanStatus == 'sending') {
      // Optimistic Sending state (clock indicator)
      return Icon(
        Icons.access_time_rounded,
        size: size - 1,
        color: colorOverride ?? Colors.white.withOpacity(0.65),
      );
    }

    if (cleanStatus == 'failed') {
      return Icon(
        Icons.error_outline_rounded,
        size: size,
        color: const Color(0xFFEF4444),
      );
    }

    // Default: 'sent' -> Single grey check
    return Icon(
      Icons.check,
      size: size,
      color: colorOverride ?? Colors.grey,
    );
  }
}
