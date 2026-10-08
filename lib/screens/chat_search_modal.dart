import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_user.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import '../services/profile_service.dart';
import '../widgets/center_alert.dart';
import 'chat_conversation_screen.dart';

class ChatSearchModal extends StatefulWidget {
  final String? initialQuery;

  const ChatSearchModal({super.key, this.initialQuery});

  static Future<void> show(BuildContext context, {String? initialQuery}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatSearchModal(initialQuery: initialQuery),
    );
  }

  @override
  State<ChatSearchModal> createState() => _ChatSearchModalState();
}

class _ChatSearchModalState extends State<ChatSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  List<ChatUser> _searchResults = [];
  Set<String> _friendUids = {};
  StreamSubscription? _friendsSubscription;
  bool _isLoading = false;
  String _currentQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
    }
    // Sync current user's profile with indexed username and public profile
    unawaited(AuthService().syncPublicProfile());
    _chatService.syncCurrentUserProfile();
    _friendsSubscription = _chatService.getFriendUidsStream().listen((set) {
      if (mounted) {
        setState(() {
          _friendUids = set;
        });
      }
    });
    _performSearch(_searchController.text);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _friendsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounce search input by 300ms using a Dart Timer to avoid spamming Firestore reads
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final rawQuery = _searchController.text.trim();
      _performSearch(rawQuery);
    });
  }

  Future<void> _performSearch(String rawQuery) async {
    if (!mounted) return;
    final query = rawQuery.trim();
    setState(() {
      _isLoading = true;
      _currentQuery = query;
    });

    final results = await searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  /// Robust Universal Search Logic across public_profiles and users collections
  Future<List<ChatUser>> searchUsers(String input) async {
    final query = input.trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final Map<String, Map<String, dynamic>> matchedUsers = {};

    // Named database instance is the authoritative database
    final List<FirebaseFirestore> databases = [
      AuthService.firestoreInstance,
    ];

    if (query.isEmpty) {
      for (final fs in databases) {
        try {
          final querySnap = await fs.collection('public_profiles').limit(20).get();
          for (var doc in querySnap.docs) {
            if (doc.id != currentUid) {
              final data = Map<String, dynamic>.from(doc.data());
              data['uid'] = doc.id;
              matchedUsers[doc.id] = data;
            }
          }
          if (matchedUsers.isNotEmpty) break;
        } catch (_) {}
      }

      if (matchedUsers.isEmpty) {
        for (final fs in databases) {
          try {
            final querySnap = await fs.collection('users').limit(20).get();
            for (var doc in querySnap.docs) {
              if (doc.id != currentUid) {
                final data = Map<String, dynamic>.from(doc.data());
                data['uid'] = doc.id;
                matchedUsers[doc.id] = data;
              }
            }
            if (matchedUsers.isNotEmpty) break;
          } catch (_) {}
        }
      }

      return matchedUsers.values
          .where((user) => user['uid'] != FirebaseAuth.instance.currentUser?.uid)
          .map((d) => ChatUser.fromMap(d, d['uid'] as String))
          .toList();
    }

    // Handle variations: exact, lower, trimmed '@', and l/I swaps
    final searchKeys = <String>{query};
    if (query.startsWith('@')) {
      searchKeys.add(query.substring(1));
    }
    searchKeys.add(query.toLowerCase());
    // Also handle possible 'l' vs 'I' OCR/typo distinction in UIDs
    searchKeys.add(query.replaceAll('l', 'I'));
    searchKeys.add(query.replaceAll('I', 'l'));

    for (final fs in databases) {
      try {
        // 1. Direct Document ID lookup (UID as Doc ID) across public_profiles
        for (final k in searchKeys) {
          try {
            final docSnap = await fs.collection('public_profiles').doc(k).get();
            if (docSnap.exists && docSnap.id != currentUid) {
              final data = Map<String, dynamic>.from(docSnap.data()!);
              final actualUid = (data['uid'] as String?)?.isNotEmpty == true ? data['uid'] as String : docSnap.id;
              data['uid'] = actualUid;
              matchedUsers[actualUid] = data;
            }
          } catch (_) {}
        }

        // 2. Query where 'uid' field equals the input across public_profiles
        for (final k in searchKeys) {
          try {
            final uidQuery = await fs
                .collection('public_profiles')
                .where('uid', isEqualTo: k)
                .limit(5)
                .get();
            for (var doc in uidQuery.docs) {
              if (doc.id != currentUid) {
                final data = Map<String, dynamic>.from(doc.data());
                data['uid'] = doc.id;
                matchedUsers[doc.id] = data;
              }
            }
          } catch (_) {}
        }

        // 3. Query where 'handle' matches prefix across public_profiles
        final cleanHandle = (query.startsWith('@') ? query.substring(1) : query).toLowerCase();
        try {
          final handleQuery = await fs
              .collection('public_profiles')
              .where('handle', isGreaterThanOrEqualTo: cleanHandle)
              .where('handle', isLessThanOrEqualTo: '$cleanHandle\uf8ff')
              .limit(10)
              .get();
          for (var doc in handleQuery.docs) {
            if (doc.id != currentUid) {
              final data = Map<String, dynamic>.from(doc.data());
              data['uid'] = doc.id;
              matchedUsers[doc.id] = data;
            }
          }
        } catch (_) {}

        // 4. Query where 'email' matches across public_profiles
        try {
          final emailQuery = await fs
              .collection('public_profiles')
              .where('email', isEqualTo: query.toLowerCase())
              .limit(5)
              .get();
          for (var doc in emailQuery.docs) {
            if (doc.id != currentUid) {
              final data = Map<String, dynamic>.from(doc.data());
              data['uid'] = doc.id;
              matchedUsers[doc.id] = data;
            }
          }
        } catch (_) {}

        // 5. Fallback: check users collection directly
        if (matchedUsers.isEmpty) {
          for (final k in searchKeys) {
            try {
              final userDoc = await fs.collection('users').doc(k).get();
              if (userDoc.exists && userDoc.id != currentUid) {
                final data = Map<String, dynamic>.from(userDoc.data()!);
                data['uid'] = userDoc.id;
                matchedUsers[userDoc.id] = data;
              }
            } catch (_) {}
          }

          try {
            final usernameQuery = await fs
                .collection('users')
                .where('username', isEqualTo: cleanHandle)
                .limit(5)
                .get();
            for (var doc in usernameQuery.docs) {
              if (doc.id != currentUid) {
                final data = Map<String, dynamic>.from(doc.data());
                data['uid'] = doc.id;
                matchedUsers[doc.id] = data;
              }
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Search error: $e');
      }

      if (matchedUsers.isNotEmpty) break;
    }

    Set<String> blockedUids = {};
    if (currentUid.isNotEmpty) {
      try {
        final bSnap = await AuthService.firestoreInstance
            .collection('users')
            .doc(currentUid)
            .collection('friends')
            .where('status', isEqualTo: 'blocked')
            .get();
        blockedUids = bSnap.docs.map((d) => d.id).toSet();
      } catch (_) {}
    }

    return matchedUsers.values
        .where((user) => user['uid'] != FirebaseAuth.instance.currentUser?.uid)
        .where((data) {
          final uid = (data['uid'] as String?) ?? '';
          if (uid.isEmpty || uid == currentUid || blockedUids.contains(uid)) return false;
          return true;
        })
        .map((data) {
          final uid = (data['uid'] as String?) ?? '';
          return ChatUser.fromMap(data, uid);
        })
        .toList();
  }

  /// Reactive friendship action bound to live friend request and relation stream:
  /// - If status == 'accepted': Show [ 💬 Chat Now ] (Tapping pushes directly to ChatConversationScreen)
  /// - If status == 'incoming_pending': Show [ ✓ Accept ], [ ✕ Decline ], and pop-up menu with [ 🚫 Block ]
  /// - If status == 'outgoing_pending': Show disabled pill [ ⏳ Waiting for Response ] (Color: Amber/Grey)
  /// - If status == 'blocked': Show [ 🚫 Blocked ]
  /// - If status == null: Show [ + Add Friend ]
  Widget _buildFriendshipAction(ChatUser peer) {
    return StreamBuilder<String?>(
      stream: FriendService().getFriendshipStatusStream(peer.uid),
      initialData: _friendUids.contains(peer.uid) ? 'accepted' : null,
      builder: (context, snapshot) {
        final status = snapshot.data;

        if (status == 'accepted') {
          return SizedBox(
            height: 34,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openChatWith(peer),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
              label: const Text(
                '💬 Chat Now',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          );
        }

        if (status == 'incoming_pending') {
          return Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                      await FriendService.acceptFriendRequest('${peer.uid}_$currentUid', peer.uid, currentUid);
                      if (context.mounted) {
                        CenterAlert.show(
                          context,
                          message: 'Friend Request Accepted ✓',
                          subtitle: 'You can now chat with ${peer.displayName}',
                          icon: Icons.check_circle_outline,
                          iconColor: const Color(0xFF10B981),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text(
                      '✓ Accept',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                      await FriendService.rejectFriendRequest('${peer.uid}_$currentUid');
                      if (context.mounted) {
                        CenterAlert.show(
                          context,
                          message: 'Request Declined',
                          subtitle: 'Friend request was removed',
                          icon: Icons.close_rounded,
                          iconColor: const Color(0xFF64748B),
                        );
                      }
                    },
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      '✕ Decline',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (val) async {
                  if (val == 'block') {
                    await FriendService().blockUser(targetUid: peer.uid);
                    if (context.mounted) {
                      CenterAlert.show(
                        context,
                        message: 'User Blocked 🚫',
                        subtitle: '${peer.displayName} has been blocked',
                        icon: Icons.block,
                        iconColor: const Color(0xFFDC2626),
                      );
                      setState(() {
                        _searchResults.removeWhere((u) => u.uid == peer.uid);
                      });
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, size: 16, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('🚫 Block', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                ),
              ),
            ],
          );
        }

        if (status == 'outgoing_pending') {
          // Disabled status pill: [ ⏳ Waiting for Response ] (Color: Amber/Grey)
          return SizedBox(
            height: 34,
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 6),
                  Text(
                    '⏳ Waiting for Response',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (status == 'blocked') {
          return SizedBox(
            height: 34,
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 14, color: Color(0xFFDC2626)),
                  SizedBox(width: 6),
                  Text(
                    '🚫 Blocked',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Default: status == null (no relation)
        return SizedBox(
          height: 34,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await FriendService.sendFriendRequest(
                targetUid: peer.uid,
                targetName: peer.displayName,
                targetHandle: peer.username,
              );
              if (context.mounted) {
                CenterAlert.show(
                  context,
                  message: 'Friend Request Sent ⏳',
                  subtitle: 'Waiting for ${peer.displayName} to accept',
                  icon: Icons.person_add_alt_rounded,
                  iconColor: const Color(0xFF0F172A),
                );
              }
            },
            icon: const Icon(Icons.person_add_alt_rounded, size: 14, color: Color(0xFF0F172A)),
            label: const Text(
              '+ Add Friend',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openChatWith(ChatUser peer) async {
    Navigator.of(context).pop(); // Immediately dismiss modal
    await _chatService.initializeChat(peer.uid);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            peerUid: peer.uid,
            peerName: peer.displayName,
            peerAvatar: peer.avatarUrl,
            peer: peer,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';
    final currentEmail = currentUser?.email ?? '';
    final currentUsername = currentEmail.contains('@')
        ? currentEmail.split('@').first.toLowerCase()
        : 'user';

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          // Modern bottom sheet with frosted glass background (BackdropFilter(blur: 20))
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: mediaQuery.size.height * 0.88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.8),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.08),
                  blurRadius: 32,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Minimal Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sanchay Connect',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Real-Time 1-on-1 Encrypted Messaging',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

                // My User ID and @handle badge card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fingerprint,
                        size: 18,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR HANDLE & USER ID',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '@$currentUsername • UID: ${currentUid.length > 8 ? currentUid.substring(0, 8) : currentUid}...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.firaCode(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: currentUid));
                          CenterAlert.show(
                            context,
                            message: 'User ID Copied',
                            subtitle: 'Share with friends to connect instantly',
                            icon: Icons.copy_rounded,
                            iconColor: const Color(0xFF10B981),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 13),
                        label: const Text(
                          'Copy',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),

                // Minimal Search Bar with prefix icon and clear button:
                // Search input hint: "Search by username, @handle, or User ID..."
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by username, @handle, or User ID...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _performSearch('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                ),

                // Active / Recent Chats Horizontal Strip (When query is empty)
                if (_currentQuery.isEmpty)
                  StreamBuilder<List<ChatRoom>>(
                    stream: _chatService.getUserChatsStream(),
                    builder: (context, snapshot) {
                      final rooms = snapshot.data ?? [];
                      if (rooms.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 6),
                            child: Text(
                              'RECENT CONVERSATIONS',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 78,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              scrollDirection: Axis.horizontal,
                              itemCount: rooms.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final room = rooms[index];
                                final peerUid = room.getPeerUid(currentUid);
                                final unread = room.getUnreadFor(currentUid);

                                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                  stream: AuthService.firestoreInstance
                                      .collection('public_profiles')
                                      .doc(peerUid)
                                      .snapshots(),
                                  builder: (context, userSnap) {
                                    final profileData = userSnap.data?.data();
                                    final displayName = (profileData?['displayName'] as String?)?.isNotEmpty == true
                                        ? (profileData!['displayName'] as String)
                                        : 'Sanchat Member';
                                    final avatarUrl = (profileData?['avatarUrl'] as String?) ?? '';
                                    final isVerified = (profileData?['isVerified'] as bool?) ?? false;
                                    final initials = displayName.trim().isNotEmpty
                                        ? displayName.trim().substring(0, 1).toUpperCase()
                                        : 'U';

                                    final peer = ChatUser(
                                      uid: peerUid,
                                      name: displayName,
                                      email: (profileData?['email'] as String?) ?? '',
                                      avatarUrl: avatarUrl,
                                      username: (profileData?['handle'] as String?) ?? '',
                                      isVerified: isVerified,
                                    );

                                    return InkWell(
                                      onTap: () => _openChatWith(peer),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        width: 160,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: unread > 0
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFE2E8F0),
                                            width: unread > 0 ? 1.4 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(11),
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: (avatarUrl.isNotEmpty &&
                                                            (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')))
                                                        ? Image.network(
                                                            avatarUrl,
                                                            width: 36,
                                                            height: 36,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) => Text(
                                                              initials,
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          )
                                                        : Text(
                                                            initials,
                                                            style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                                if (unread > 0)
                                                  Positioned(
                                                    right: -2,
                                                    top: -2,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(3.5),
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFFEF4444),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Text(
                                                        '$unread',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          displayName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w700,
                                                            color: const Color(0xFF0F172A),
                                                          ),
                                                        ),
                                                      ),
                                                      if (isVerified) ...[
                                                        const SizedBox(width: 3),
                                                        const Icon(
                                                          Icons.verified,
                                                          size: 11,
                                                          color: Color(0xFF2563EB),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  Text(
                                                    room.lastMessage,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 10,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                // Search Results Header
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentQuery.isEmpty
                            ? 'REGISTERED USERS'
                            : 'SEARCH RESULTS (${_searchResults.length})',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                    ],
                  ),
                ),

                // Search Result List
                Expanded(
                  child: _searchResults.isEmpty && !_isLoading
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.person_search_outlined,
                                  size: 46,
                                  color: Color(0xFFCBD5E1),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _currentQuery.isEmpty
                                      ? 'No registered users found'
                                      : 'No match for "$_currentQuery"',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try searching by @handle, email prefix, or full User ID',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final peer = _searchResults[index];
                            final isPeerOnline = peer.isOnline;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Squircle Avatar with initials
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(13),
                                            child: ProfileService().buildAvatarWidget(
                                              avatarUrl: peer.avatarUrl,
                                              initials: peer.initials,
                                              radius: 21,
                                              isSquircle: true,
                                            ),
                                          ),
                                          if (isPeerOnline)
                                            Positioned(
                                              right: -1,
                                              bottom: -1,
                                              child: Container(
                                                width: 11,
                                                height: 11,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),

                                      // Display name (bold), @username, UID preview
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    peer.displayName,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isPeerOnline) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 4.5,
                                                      vertical: 1.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFDCFCE7),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'ONLINE',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF15803D),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    peer.handle,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF2563EB),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '• UID: ${peer.uidSnippet}...',
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 10.5,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Mutual Friend Request & Chat Permission Action
                                  _buildFriendshipAction(peer),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
