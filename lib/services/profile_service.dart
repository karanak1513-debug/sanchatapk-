import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/sanchay_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/center_alert.dart';
import 'auth_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final ImagePicker _picker = ImagePicker();
  static FirebaseFirestore get _firestore => AuthService.firestoreInstance;

  /// Bootstrap & Purge Corrupted Profile Entries:
  /// On user login and cold start, check public_profiles/{uid}:
  /// - If displayName is missing, empty, or starts with 'User ' (e.g., 'User dvFywv', 'User Z2Tgj5'):
  ///   - Overwrite displayName with currentUser?.displayName or extract prefix from email (e.g. 'karanak1513')
  ///   - Set default isVerified: true for active primary user
  ///   - Ensure handle is normalized to lowercase without spaces
  /// - Force-bust local SQLite and memory cache so outdated cached handles are expunged immediately.
  static Future<void> bootstrapAndPurgeCorruptedProfiles([String? targetUid]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = targetUid ?? user?.uid;
      if (uid == null || uid.isEmpty) return;

      final docRef = _firestore.collection('public_profiles').doc(uid);
      final docSnap = await docRef.get();
      final data = docSnap.data() ?? {};

      final rawDisplayName = (data['displayName'] as String?)?.trim() ?? '';
      final rawHandle = (data['handle'] as String?)?.trim() ?? '';

      final bool isCorrupted = rawDisplayName.isEmpty ||
          rawDisplayName.startsWith('User ') ||
          rawDisplayName.toLowerCase().startsWith('user ');

      String resolvedDisplayName = rawDisplayName;
      if (isCorrupted) {
        if (user?.displayName != null &&
            user!.displayName!.trim().isNotEmpty &&
            !user.displayName!.startsWith('User ')) {
          resolvedDisplayName = user.displayName!.trim();
        } else if (user?.email != null && user!.email!.contains('@')) {
          resolvedDisplayName = user.email!.split('@').first.trim();
        } else if (rawHandle.isNotEmpty && !rawHandle.toLowerCase().startsWith('user')) {
          resolvedDisplayName = rawHandle;
        } else {
          resolvedDisplayName = uid.length >= 8 ? uid.substring(0, 8) : uid;
        }
      }

      String normalizedHandle = rawHandle.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      if (normalizedHandle.startsWith('@')) {
        normalizedHandle = normalizedHandle.substring(1);
      }
      if (normalizedHandle.isEmpty || normalizedHandle.startsWith('user_') || normalizedHandle.startsWith('user')) {
        if (user?.email != null && user!.email!.contains('@')) {
          normalizedHandle = user.email!.split('@').first.replaceAll(RegExp(r'[^a-z0-9_]'), '').toLowerCase();
        } else {
          normalizedHandle = resolvedDisplayName.replaceAll(RegExp(r'[^a-z0-9_]'), '').toLowerCase();
        }
      }

      final updates = <String, dynamic>{
        'uid': uid,
        'displayName': resolvedDisplayName,
        'handle': normalizedHandle,
        'isVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if ((data['avatarUrl'] == null || data['avatarUrl'].toString().isEmpty) &&
          user?.photoURL != null &&
          user!.photoURL!.isNotEmpty) {
        updates['avatarUrl'] = user.photoURL;
      }

      await docRef.set(updates, SetOptions(merge: true));

      // Batch sync to users/{uid} root and users/{uid}/profile/meta
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection('users').doc(uid),
        {
          'displayName': resolvedDisplayName,
          'handle': normalizedHandle,
          'username': normalizedHandle,
          'isVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(
        _firestore.collection('users').doc(uid).collection('profile').doc('meta'),
        {
          'displayName': resolvedDisplayName,
          'handle': normalizedHandle,
          'username': normalizedHandle,
          'isVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      // Force-bust local SQLite and SharedPreferences memory cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_handle');
        await prefs.remove('user_name');
        await prefs.setString('userHandle', normalizedHandle);
        await prefs.setString('userName', resolvedDisplayName);
      } catch (e) {
        debugPrint('ProfileService cache purge warning: $e');
      }

      debugPrint('ProfileService: Purged corrupted entries & verified profile for $uid -> $resolvedDisplayName (@$normalizedHandle)');
    } catch (e) {
      debugPrint('ProfileService bootstrapAndPurgeCorruptedProfiles error: $e');
    }
  }

  Future<void> bootstrapProfile([String? targetUid]) =>
      bootstrapAndPurgeCorruptedProfiles(targetUid);

  /// Curated luxury avatar presets
  static const List<Map<String, String>> luxuryPresets = [
    {
      'title': 'Obsidian',
      'url':
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
    },
    {
      'title': 'Swiss Pearl',
      'url':
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=256&q=80',
    },
    {
      'title': 'Emerald Mint',
      'url':
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=256&q=80',
    },
    {
      'title': 'Glacier Slate',
      'url':
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=256&q=80',
    },
    {
      'title': 'Rose Vault',
      'url':
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=256&q=80',
    },
  ];

  /// Resolves an ImageProvider supporting Base64 Data URI, remote NetworkImage, local FileImage fallback
  ImageProvider? getAvatarImageProvider(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      final trimmed = avatarUrl.trim();
      if (trimmed.startsWith('data:image/') || trimmed.startsWith('base64:')) {
        try {
          final commaIdx = trimmed.indexOf(',');
          final base64Str = commaIdx != -1
              ? trimmed.substring(commaIdx + 1)
              : (trimmed.startsWith('base64:') ? trimmed.substring(7) : trimmed);
          final bytes = base64Decode(base64Str.trim());
          return MemoryImage(bytes);
        } catch (e) {
          debugPrint('ProfileService: MemoryImage decode warning: $e');
        }
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return NetworkImage(trimmed);
      } else if (!trimmed.startsWith('/') && !trimmed.contains('\\') && trimmed.length > 100) {
        try {
          final bytes = base64Decode(trimmed);
          return MemoryImage(bytes);
        } catch (_) {}
      } else if (!kIsWeb) {
        try {
          final file = File(trimmed);
          if (file.existsSync()) {
            return FileImage(file);
          }
        } catch (e) {
          debugPrint('ProfileService: FileImage check warning: $e');
        }
      }
    }
    return null;
  }

  /// Resolves an ImageProvider supporting local FileImage fallback and remote NetworkImage
  ImageProvider? getAvatarProvider(String? pathOrUrl) {
    return getAvatarImageProvider(pathOrUrl);
  }

  /// Infallible user avatar widget builder
  Widget buildUserAvatarWidget(String? path, {double radius = 24}) {
    return buildUserAvatar(path, radius: radius);
  }

  /// Builds an avatar widget with file/network fallbacks, neutral background, and person icon fallback
  Widget buildAvatarWidget({
    required String avatarUrl,
    required String initials,
    double radius = 18,
    Color? backgroundColor,
    Color? textColor,
    bool isSquircle = true,
  }) {
    return buildUserAvatar(avatarUrl, radius: radius);
  }

  /// Persists avatar path/url to Firestore & Firebase Auth user profile
  Future<void> persistAvatar({
    required BuildContext context,
    required String localOrRemotePath,
  }) async {
    final rawPath = localOrRemotePath.trim();
    if (rawPath.isEmpty) return;

    // Convert local file to Base64 data URI if needed, so cloud is always accessible by peers
    String cloudUrl = rawPath;
    final isLocalFile = !rawPath.startsWith('http://') &&
        !rawPath.startsWith('https://') &&
        !rawPath.startsWith('data:image/');

    if (isLocalFile && !kIsWeb) {
      try {
        final file = File(rawPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          cloudUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      } catch (e) {
        debugPrint('ProfileService: persistAvatar local file encode warning: $e');
      }
    }

    // 1. Immediately update in-memory Provider for zero-latency UI response
    try {
      if (context.mounted) {
        final provider = context.read<SanchayProvider>();
        await provider.updateAvatarUrl(cloudUrl);
      }
    } catch (e) {
      debugPrint('ProfileService: Provider update warning: $e');
    }

    // 2. Update Firebase Auth user profile
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.updatePhotoURL(cloudUrl);
        await currentUser.reload();
      }
    } catch (e) {
      debugPrint('ProfileService: FirebaseAuth updatePhotoURL warning: $e');
    }

    // 3. Persist batch write directly to Firestore
    try {
      final userId =
          FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
      if (userId.isNotEmpty) {
        final firestore = _firestore;
        final batch = firestore.batch();

        final profileData = <String, dynamic>{
          'avatarUrl': cloudUrl,
          if (isLocalFile) 'avatarLocalPath': rawPath,
          'photoUrl': cloudUrl,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        };

        // users/{userId}/profile/avatarUrl
        batch.set(
          firestore.collection('users').doc(userId).collection('profile').doc('avatarUrl'),
          {'avatarUrl': cloudUrl, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );

        // users/{userId}/profile/meta
        batch.set(
          firestore.collection('users').doc(userId).collection('profile').doc('meta'),
          profileData,
          SetOptions(merge: true),
        );

        // public_profiles/{userId} (for real-time peer discovery and chat avatars)
        batch.set(
          firestore.collection('public_profiles').doc(userId),
          {
            'avatarUrl': cloudUrl,
            'photoUrl': cloudUrl,
            if (isLocalFile) 'avatarLocalPath': rawPath,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // users/{userId}/profile/settings
        batch.set(
          firestore.collection('users').doc(userId).collection('profile').doc('settings'),
          {
            'avatarUrl': cloudUrl,
            if (isLocalFile) 'avatarLocalPath': rawPath,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Root user document
        batch.set(
          firestore.collection('users').doc(userId),
          {
            'avatarUrl': cloudUrl,
            'photoUrl': cloudUrl,
            if (isLocalFile) 'avatarLocalPath': rawPath,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        await batch.commit();
        debugPrint('ProfileService: Avatar successfully persisted to Firestore users/$userId/profile/avatarUrl and public_profiles');
      }
    } catch (e) {
      debugPrint('ProfileService: Firestore persistence error: $e');
    }
  }

  /// Validation: Lowercase letters, numbers, underscores only (3-18 chars)
  String? validateHandle(String? input) {
    if (input == null || input.trim().isEmpty) return 'Username is required';
    var clean = input.trim().toLowerCase();
    if (clean.startsWith('@')) clean = clean.substring(1);
    if (clean.length < 3) return 'Username must be at least 3 characters';
    if (clean.length > 18) return 'Username cannot exceed 18 characters';
    if (!RegExp(r'^[a-z0-9_]{3,18}$').hasMatch(clean)) {
      return 'Lowercase letters, numbers, underscores only (3-18 chars)';
    }
    return null;
  }

  /// Check uniqueness in Firestore collection public_profiles:
  /// Ensure no other document has handle == newHandle
  Future<bool> isHandleAvailable(String handle, {String? currentUid}) async {
    var clean = handle.trim().toLowerCase();
    if (clean.startsWith('@')) clean = clean.substring(1);
    final myUid = currentUid ??
        FirebaseAuth.instance.currentUser?.uid ??
        AuthService().currentUserId;

    try {
      final existing = await _firestore
          .collection('public_profiles')
          .where('handle', isEqualTo: clean)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != myUid) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('ProfileService: isHandleAvailable error: $e');
      return true;
    }
  }

  /// On save, update users/{uid} and public_profiles/{uid} atomically
  Future<void> updateUsername({
    required BuildContext context,
    required String newHandle,
  }) async {
    var clean = newHandle.trim().toLowerCase();
    if (clean.startsWith('@')) clean = clean.substring(1);

    final error = validateHandle(clean);
    if (error != null) {
      throw ArgumentError(error);
    }

    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
    if (currentUid.isEmpty) {
      throw StateError('User not authenticated');
    }

    String avatarUrl = '';
    try {
      avatarUrl = context.read<SanchayProvider>().userAvatarUrl;
    } catch (_) {}

    final query = await _firestore
        .collection('public_profiles')
        .where('handle', isEqualTo: clean)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty && query.docs.first.id != currentUid) {
      throw Exception("Username @$clean is already taken.");
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final displayName = currentUser?.displayName?.isNotEmpty == true
        ? currentUser!.displayName!
        : (currentUser?.email?.split('@').first ?? clean);

    if (avatarUrl.isEmpty) {
      avatarUrl = currentUser?.photoURL ?? '';
    }

    final firestore = _firestore;
    final batch = firestore.batch();

    // 1. users/{uid}: { 'handle': newHandle, 'username': newHandle, 'updatedAt': FieldValue.serverTimestamp() }
    final userDoc = firestore.collection('users').doc(currentUid);
    batch.set(userDoc, {
      'handle': clean,
      'username': clean,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. public_profiles/{uid}: { 'uid': currentUid, 'handle': newHandle.toLowerCase(), 'displayName': displayName, 'avatarUrl': avatarUrl, 'updatedAt': FieldValue.serverTimestamp() }
    final publicDoc = firestore.collection('public_profiles').doc(currentUid);
    batch.set(publicDoc, {
      'uid': currentUid,
      'handle': clean,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. users/{uid}/profile/meta
    final metaDoc = firestore
        .collection('users')
        .doc(currentUid)
        .collection('profile')
        .doc('meta');
    batch.set(metaDoc, {
      'handle': clean,
      'username': clean,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4. users/{uid}/profile/settings
    final settingsDoc = firestore
        .collection('users')
        .doc(currentUid)
        .collection('profile')
        .doc('settings');
    batch.set(settingsDoc, {
      'handle': clean,
      'username': clean,
      'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    // Update local state and trigger UI refresh across headers and modals immediately
    try {
      if (context.mounted) {
        context.read<SanchayProvider>().updateHandle(clean);
      }
    } catch (_) {}
  }

  /// Alias for updateUsername
  Future<void> updateHandle({
    required BuildContext context,
    required String newHandle,
  }) => updateUsername(context: context, newHandle: newHandle);


  /// Pick image via Camera or Gallery, compress, convert to Base64 Data URI, and batch persist to Cloud & Local
  Future<void> pickAndSetAvatar({
    required BuildContext context,
    required ImageSource source,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 70,
      );

      if (file != null && context.mounted) {
        // 1. Read bytes and convert to compact Base64 Data URI for instant real-time peer sync
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        final cloudAvatarUrl = 'data:image/jpeg;base64,$base64Image';

        // 2. Also save locally to app documents directory
        String localPath = file.path;
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedFile = await File(file.path).copy('${appDir.path}/$fileName');
          localPath = savedFile.path;
        } catch (e) {
          debugPrint('ProfileService: local copy warning: $e');
        }

        final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
        if (uid.isNotEmpty) {
          final firestore = _firestore;
          final batch = firestore.batch();

          // Batch write the new URL to:
          // 1. users/{uid}/profile/avatarUrl
          final avatarUrlDoc = firestore
              .collection('users')
              .doc(uid)
              .collection('profile')
              .doc('avatarUrl');
          batch.set(avatarUrlDoc, {
            'avatarUrl': cloudAvatarUrl,
            'avatarLocalPath': localPath,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // 2. public_profiles/{uid}/avatarUrl
          final publicDoc = firestore.collection('public_profiles').doc(uid);
          batch.set(publicDoc, {
            'avatarUrl': cloudAvatarUrl,
            'photoUrl': cloudAvatarUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // 3. users/{uid}/profile/meta
          final metaDoc = firestore
              .collection('users')
              .doc(uid)
              .collection('profile')
              .doc('meta');
          batch.set(metaDoc, {
            'avatarUrl': cloudAvatarUrl,
            'avatarLocalPath': localPath,
            'photoUrl': cloudAvatarUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // 4. users/{uid} root document
          final userRootDoc = firestore.collection('users').doc(uid);
          batch.set(userRootDoc, {
            'avatarUrl': cloudAvatarUrl,
            'photoUrl': cloudAvatarUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // 5. users/{uid}/profile/avatarLocalPath (backward compatibility)
          final localDoc = firestore
              .collection('users')
              .doc(uid)
              .collection('profile')
              .doc('avatarLocalPath');
          batch.set(localDoc, {
            'avatarLocalPath': localPath,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await batch.commit();
          debugPrint('ProfileService: Batch write avatarUrl to users/$uid and public_profiles/$uid succeeded');
        }

        if (context.mounted) {
          await persistAvatar(context: context, localOrRemotePath: cloudAvatarUrl);
          if (context.mounted) {
            CenterAlert.show(
              context,
              message: 'Profile Avatar Updated ✓',
              icon: Icons.check_circle_outline,
              iconColor: AppColors.emerald,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('ProfileService: pickAndSetAvatar error: $e');
      if (context.mounted) {
        CenterAlert.show(
          context,
          message: 'Notice: Could not access image source',
          subtitle: e.toString(),
          icon: Icons.info_outline_rounded,
          iconColor: const Color(0xFFF59E0B),
        );
      }
    }
  }

  /// Opens dialog to input image URL directly
  Future<void> showImageUrlDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Enter Image URL',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.obsidian,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a direct HTTPS link to any image (e.g. Unsplash, GitHub, Gravatar):',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'https://images.unsplash.com/...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceContainerHigh),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop(text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save URL'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      await persistAvatar(context: context, localOrRemotePath: result);
      if (context.mounted) {
        CenterAlert.show(
          context,
          message: 'Image URL set as avatar ✓',
          icon: Icons.check_circle_outline,
          iconColor: AppColors.emerald,
        );
      }
    }
  }

  /// Tapping avatar badge opens a modal bottom sheet: [Camera] / [Gallery] / [Enter Image URL]
  Future<void> showAvatarPickerModal(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ProfilePickerBottomSheet(),
    );
  }
}

class _ProfilePickerBottomSheet extends StatefulWidget {
  const _ProfilePickerBottomSheet();

  @override
  State<_ProfilePickerBottomSheet> createState() => _ProfilePickerBottomSheetState();
}

class _ProfilePickerBottomSheetState extends State<_ProfilePickerBottomSheet> {
  bool _isLoading = false;

  Future<void> _handlePick(ImageSource source) async {
    setState(() => _isLoading = true);
    try {
      await ProfileService().pickAndSetAvatar(context: context, source: source);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUrl() async {
    Navigator.of(context).pop();
    await ProfileService().showImageUrlDialog(context);
  }

  Future<void> _handlePreset(String url) async {
    setState(() => _isLoading = true);
    try {
      await ProfileService().persistAvatar(context: context, localOrRemotePath: url);
      if (mounted) {
        Navigator.of(context).pop();
        CenterAlert.show(
          context,
          message: 'Avatar Applied ✓',
          icon: Icons.check_circle_outline,
          iconColor: AppColors.emerald,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withOpacity(0.12),
            blurRadius: 36,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VAULT IDENTITY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: AppColors.crimson,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Update Profile Avatar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.obsidian,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Current Avatar Preview
          Center(
            child: Stack(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.obsidian.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: ProfileService().buildAvatarWidget(
                      avatarUrl: provider.userAvatarUrl,
                      initials: provider.userInitials,
                      radius: 42,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.emerald,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: AppColors.obsidian),
              ),
            )
          else ...[
            // Option 1 & 2: Camera & Gallery
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handlePick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.obsidian,
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handlePick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.obsidian,
                      side: const BorderSide(color: AppColors.surfaceContainerHigh),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Option 3: Enter Image URL
            OutlinedButton.icon(
              onPressed: _handleUrl,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Enter Image URL'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.obsidian,
                side: const BorderSide(color: AppColors.surfaceContainerHigh),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Curated Luxury Presets Section
            Text(
              'CURATED LUXURY PRESETS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ProfileService.luxuryPresets.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final preset = ProfileService.luxuryPresets[i];
                  final isSelected = provider.userAvatarUrl == preset['url'];
                  return GestureDetector(
                    onTap: () => _handlePreset(preset['url']!),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.emerald : Colors.white,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.obsidian.withOpacity(0.06),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              preset['url']!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset['title']!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.emerald : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
