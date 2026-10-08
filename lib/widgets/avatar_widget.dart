import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Infallible user avatar builder with Base64, Network, and local File fallback.
/// Renders standard CircleAvatar with neutral background and person icon fallback.
Widget buildUserAvatar(String? path, {double radius = 24, String? initials}) {
  ImageProvider? provider;
  if (path != null && path.trim().isNotEmpty) {
    final cleanPath = path.trim();
    if (cleanPath.startsWith('data:image/') || cleanPath.startsWith('base64:')) {
      try {
        final commaIdx = cleanPath.indexOf(',');
        final base64Str = commaIdx != -1
            ? cleanPath.substring(commaIdx + 1)
            : (cleanPath.startsWith('base64:') ? cleanPath.substring(7) : cleanPath);
        final bytes = base64Decode(base64Str);
        provider = MemoryImage(bytes);
      } catch (e) {
        debugPrint('buildUserAvatar base64 decode error: $e');
      }
    } else if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      provider = NetworkImage(cleanPath);
    } else if (!cleanPath.startsWith('/') &&
        !cleanPath.contains('\\') &&
        cleanPath.length > 100) {
      try {
        final bytes = base64Decode(cleanPath);
        provider = MemoryImage(bytes);
      } catch (_) {}
    } else if (!kIsWeb) {
      try {
        final file = File(cleanPath);
        if (file.existsSync()) {
          provider = FileImage(file);
        }
      } catch (e) {
        debugPrint('buildUserAvatar File check warning: $e');
      }
    }
  }

  Widget? fallbackChild;
  if (provider == null) {
    if (initials != null && initials.trim().isNotEmpty) {
      final safeInitials = initials.trim().length > 2
          ? initials.trim().substring(0, 2).toUpperCase()
          : initials.trim().toUpperCase();
      fallbackChild = Text(
        safeInitials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.78,
          color: const Color(0xFF334155),
          letterSpacing: -0.2,
        ),
      );
    } else {
      fallbackChild = Icon(
        Icons.person,
        size: radius * 1.1,
        color: const Color(0xFF64748B),
      );
    }
  }

  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFE2E8F0),
    backgroundImage: provider,
    child: fallbackChild,
  );
}

class AvatarWidget extends StatelessWidget {
  final String? path;
  final double radius;
  final String? initials;

  const AvatarWidget({
    super.key,
    this.path,
    this.radius = 24,
    this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return buildUserAvatar(path, radius: radius, initials: initials);
  }
}
