import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Unified Avatar & Identity Widget:
/// Live real-time mapping of public_profiles/{peerUid}
/// Renders authentic avatar image, verified badge, display name and handle
class UserAvatarTile extends StatelessWidget {
  final String peerUid;
  final double radius;
  final TextStyle? nameStyle;
  final bool showSubtitle;
  final String? fallbackSubtitle;
  final String? fallbackDisplayName;

  const UserAvatarTile({
    super.key,
    required this.peerUid,
    this.radius = 22,
    this.nameStyle,
    this.showSubtitle = false,
    this.fallbackSubtitle,
    this.fallbackDisplayName,
  });

  ImageProvider? _resolveAvatarImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
    final url = avatarUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }
    try {
      final file = File(url);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (peerUid.isEmpty) {
      return Row(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFE2E8F0),
            child: Icon(Icons.person, size: radius * 1.1, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fallbackDisplayName ?? "Sanchat User",
              overflow: TextOverflow.ellipsis,
              style: nameStyle ?? const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ),
        ],
      );
    }

    Stream<DocumentSnapshot>? stream;
    try {
      if (Firebase.apps.isNotEmpty) {
        stream = AuthService.firestoreInstance
            .collection('public_profiles')
            .doc(peerUid)
            .snapshots();
      }
    } catch (_) {
      stream = null;
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String cleanFallback = 'Sanchat User';
        if (fallbackDisplayName != null &&
            fallbackDisplayName!.trim().isNotEmpty &&
            fallbackDisplayName != 'Connecting...' &&
            fallbackDisplayName != 'Chat' &&
            !fallbackDisplayName!.startsWith('User ')) {
          cleanFallback = fallbackDisplayName!.trim();
        }

        if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
          final hasNamedFallback = cleanFallback != 'Sanchat User';

          return Row(
            children: [
              CircleAvatar(
                radius: radius,
                backgroundColor: hasNamedFallback ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                child: hasNamedFallback
                    ? Text(
                        cleanFallback[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: radius * 0.8,
                        ),
                      )
                    : Icon(Icons.person, size: radius * 1.1, color: const Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cleanFallback,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle ?? const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    if (showSubtitle && fallbackSubtitle != null && fallbackSubtitle!.isNotEmpty)
                      Text(
                        fallbackSubtitle!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
            ],
          );
        }

        final data = (snapshot.data!.data() as Map<String, dynamic>?) ?? {};
        final rawDisplayName = (data['displayName'] as String?)?.trim() ?? '';
        final String displayName = (rawDisplayName.isNotEmpty && !rawDisplayName.startsWith('User '))
            ? rawDisplayName
            : (cleanFallback != 'Sanchat User'
                ? cleanFallback
                : ((data['handle'] != null && data['handle'].toString().trim().isNotEmpty)
                    ? '@${data['handle']}'
                    : 'Sanchat User'));
        final String? avatarUrl = data['avatarUrl'] as String?;
        final bool isVerified = data['isVerified'] == true;
        final String handle = (data['handle'] as String?) ?? '';
        final imageProvider = _resolveAvatarImage(avatarUrl);

        return Row(
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: const Color(0xFF0F172A),
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.8),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle ?? const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 16, color: Color(0xFF2563EB)),
                      ],
                    ],
                  ),
                  if (showSubtitle)
                    Text(
                      fallbackSubtitle ?? (handle.isNotEmpty ? '@$handle' : ''),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
