import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/chat_user.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/pending_requests_modal.dart';
import '../widgets/user_avatar_tile.dart';
import 'chat_conversation_screen.dart';
import 'chat_search_modal.dart';

class ChatMessagesListScreen extends StatefulWidget {
  const ChatMessagesListScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatMessagesListScreen(),
      ),
    );
  }

  @override
  State<ChatMessagesListScreen> createState() => _ChatMessagesListScreenState();
}

class _ChatMessagesListScreenState extends State<ChatMessagesListScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  late final String _currentUid;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _chatService.syncCurrentUserProfile();
    _searchController.addListener(() {
      setState(() {
        _searchFilter = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChatWith(ChatUser peer, {String? avatarUrl, String? displayName}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          peerUid: peer.uid,
          peerName: displayName ?? peer.displayName,
          peerAvatar: avatarUrl ?? peer.avatarUrl,
          peer: peer,
        ),
      ),
    );
  }

  static String formatChatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('hh:mm a').format(date);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(date);
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    const swissPorcelain = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: swissPorcelain,
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                gradient: RadialGradient(
                  center: Alignment(-0.6, -0.6),
                  radius: 1.4,
                  colors: [
                    Color(0xFFF1F5F9),
                    Color(0xFFF8FAFC),
                    Color(0xFFFFFFFF),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Main View
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(context),
                _buildIncomingRequestsHub(context),
                Expanded(
                  child: StreamBuilder<Set<String>>(
                    stream: FriendService().getBlockedUserIdsStream(_currentUid),
                    builder: (context, blockedSnap) {
                      final blockedIds = blockedSnap.data ?? <String>{};

                      return StreamBuilder<List<ChatRoom>>(
                        stream: _chatService.getUserChatsStream(_currentUid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F172A),
                              ),
                            );
                          }

                          final allRooms = (snapshot.data ?? [])
                              .where((r) => !blockedIds.contains(r.getPeerUid(_currentUid)))
                              .toList();

                          if (allRooms.isEmpty) {
                            return _buildEmptyState();
                          }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: allRooms.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final room = allRooms[index];
                          return ChatConversationTile(
                            room: room,
                            currentUid: _currentUid,
                            searchFilter: _searchFilter,
                            onOpenChat: _openChatWith,
                          );
                        },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  ],
),

      // Floating "+" Action Button triggering Discovery Modal
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDiscoveryModal(context),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, size: 22),
        label: Text(
          'Discover Friends',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: const Color(0xFF0F172A),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          const SanchatBrandLogo(size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Sanchat Real-Time Connect',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<int>(
            stream: FriendService().getIncomingRequestsCountStream(_currentUid),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  onTap: () => PendingRequestsModal.show(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          size: 13,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$count',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Discover Registered Users',
            icon: const Icon(Icons.person_search_rounded, size: 22, color: Color(0xFF0F172A)),
            onPressed: () => _showDiscoveryModal(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search by UID, @handle, or message...',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_searchFilter.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                onPressed: () => _searchController.clear(),
              ),
              TextButton(
                onPressed: () => ChatSearchModal.show(context, initialQuery: _searchFilter),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'GLOBAL',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ] else
              TextButton(
                onPressed: () => ChatSearchModal.show(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'FIND',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 30,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Conversations Yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ New Chat" below to search registered users by @handle, email, or UID and start chatting in real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showDiscoveryModal(context),
              icon: const Icon(Icons.person_search_rounded, size: 18),
              label: const Text('Discover Users'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscoveryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserDiscoveryModal(currentUid: _currentUid),
    );
  }

  Widget _buildIncomingRequestsHub(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? _currentUid;
    if (myUid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: AuthService.firestoreInstance
          .collection('friend_requests')
          .where('receiverId', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        final reqs = snapshot.data!.docs;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Color(0xFF0F172A)),
                  const SizedBox(width: 6),
                  Text(
                    "Friend Requests (${reqs.length})",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...reqs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final senderId = (data['senderId'] ?? data['senderUid'] ?? '').toString();
                final senderName = (data['senderName'] ?? 'Sanchat User').toString();
                final senderHandle = (data['senderHandle'] ?? 'user').toString();
                final senderAvatar = (data['senderAvatar'] ?? '').toString();

                return Container(
                  key: ValueKey(doc.id),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0F172A),
                        backgroundImage: (senderAvatar.isNotEmpty && senderAvatar.startsWith('http'))
                            ? NetworkImage(senderAvatar)
                            : null,
                        child: (senderAvatar.isEmpty || !senderAvatar.startsWith('http'))
                            ? Text(
                                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              senderName,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              senderHandle.startsWith('@') ? senderHandle : '@$senderHandle',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // [ ✓ Accept ]
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          elevation: 0,
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          try {
                            await FriendService.acceptFriendRequest(doc.id, senderId, myUid);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not accept: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('✓ Accept', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      // [ ✕ Reject ]
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          try {
                            await FriendService.rejectFriendRequest(doc.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not decline: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('✕ Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class ChatConversationTile extends StatelessWidget {
  final ChatRoom room;
  final String currentUid;
  final String searchFilter;
  final void Function(ChatUser peer, {String? avatarUrl, String? displayName}) onOpenChat;

  const ChatConversationTile({
    super.key,
    required this.room,
    required this.currentUid,
    required this.searchFilter,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final peerUid = room.getPeerUid(currentUid);
    final unread = room.getUnreadFor(currentUid);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              peerUid: peerUid,
              chatId: room.chatId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread > 0
                ? const Color(0xFF10B981).withOpacity(0.5)
                : const Color(0xFFE2E8F0),
            width: unread > 0 ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // List View Integration: Real-time UserAvatarTile with fallbackSubtitle
            Expanded(
              child: UserAvatarTile(
                peerUid: peerUid,
                radius: 22,
                showSubtitle: true,
                fallbackSubtitle: room.lastMessage.isNotEmpty ? room.lastMessage : 'Connected on Sanchat',
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _ChatMessagesListScreenState.formatChatTime(room.lastTimestamp),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                    color: unread > 0 ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic State Button in Discovery Modal
class _UserDiscoveryModal extends StatelessWidget {
  final String currentUid;
  const _UserDiscoveryModal({required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registered Users',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: AuthService.firestoreInstance.collection('public_profiles').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                }

                // Strictly exclude the currently logged-in user:
                final currentUser = FirebaseAuth.instance.currentUser;
                final myUid = currentUser?.uid ?? currentUid;
                final myEmail = currentUser?.email?.toLowerCase().trim() ?? '';
                final users = snapshot.data!.docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final uUid = (d['uid'] ?? doc.id).toString();
                  final uEmail = (d['email'] ?? '').toString().toLowerCase().trim();
                  if (myUid.isNotEmpty && (doc.id == myUid || uUid == myUid)) return false;
                  if (myEmail.isNotEmpty && uEmail == myEmail) return false;
                  return true;
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No other registered users found.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final targetUser = users[index];
                    final data = targetUser.data() as Map<String, dynamic>;
                    final targetName = (data['displayName'] != null &&
                            data['displayName'].toString().trim().isNotEmpty &&
                            !data['displayName'].toString().startsWith('User '))
                        ? data['displayName'].toString()
                        : (data['handle'] != null ? '@${data['handle']}' : 'Sanchat User');
                    final targetHandle = (data['handle'] ?? 'user').toString();

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: UserAvatarTile(
                              peerUid: targetUser.id,
                              radius: 20,
                              showSubtitle: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Dynamic State Button bound to Firestore friend_requests:
                          StreamBuilder<String?>(
                            stream: FriendService().getFriendshipStatusStream(targetUser.id, currentUid),
                            builder: (context, statusSnap) {
                              final status = statusSnap.data;

                              if (status == 'outgoing_pending') {
                                return OutlinedButton(
                                  onPressed: null,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFFCD34D)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text(
                                    "⏳ Waiting for Response",
                                    style: TextStyle(
                                      color: Color(0xFFD97706),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              }

                              if (status == 'incoming_pending') {
                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    try {
                                      await FriendService.acceptFriendRequest('${targetUser.id}_$currentUid', targetUser.id, currentUid);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Could not accept: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text("✓ Accept", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                );
                              }

                              if (status == 'accepted') {
                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatConversationScreen(
                                          peerUid: targetUser.id,
                                          peerName: targetName,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text("💬 Chat Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                );
                              }

                              return ElevatedButton.icon(
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text("Add Friend", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  try {
                                    await FriendService.sendFriendRequest(
                                      targetUid: targetUser.id,
                                      targetName: targetName,
                                      targetHandle: targetHandle,
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$e')),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

