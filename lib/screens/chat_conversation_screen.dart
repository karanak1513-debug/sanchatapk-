import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import '../widgets/center_alert.dart';
import '../widgets/message_status_tick.dart';
import '../widgets/user_avatar_tile.dart';

class ChatConversationScreen extends StatefulWidget {
  final String peerUid;
  final String peerName;
  final String peerAvatar;
  final ChatUser? peer;
  final String? _explicitChatId;

  const ChatConversationScreen({
    super.key,
    required this.peerUid,
    this.peerName = 'Sanchat User',
    this.peerAvatar = '',
    this.peer,
    String? chatId,
  }) : _explicitChatId = chatId;

  String get chatId {
    String myUid = '';
    try {
      myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {}
    if (myUid.isNotEmpty && peerUid.isNotEmpty) {
      return ChatService.getDeterministicChatId(myUid, peerUid);
    }
    if (_explicitChatId != null && _explicitChatId.isNotEmpty) {
      return _explicitChatId;
    }
    return ChatService.getDeterministicChatId(myUid, peerUid);
  }

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ChatService _chatService = ChatService();
  StreamSubscription? _messageSubscription;
  late final String _currentUid;
  late final String _chatId;

  bool _isComposing = false;
  ChatMessage? _editingMessage;
  late final AnimationController _springController;
  late final Animation<double> _springScale;

  ChatUser? _resolvedPeer;

  @override
  void initState() {
    super.initState();
    try {
      _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      _currentUid = '';
    }
    _chatId = widget.chatId;
    _resolvedPeer = widget.peer;

    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _springScale = Tween<double>(begin: 1.0, end: 0.84).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeInOut),
    );

    // Instant batch write: mark incoming unread messages as 'seen' on screen entry
    if (_currentUid.isNotEmpty) {
      _chatService.markMessagesAsSeen(widget.peerUid);
    }

    _textController.addListener(_onTextChanged);

    // If full peer object wasn't passed, fetch in background for live status
    if (_resolvedPeer == null && _currentUid.isNotEmpty) {
      _fetchPeerDetails();
    }
  }

  Future<void> _fetchPeerDetails() async {
    final user = await _chatService.getUser(widget.peerUid);
    if (mounted && user != null) {
      setState(() => _resolvedPeer = user);
    }
  }

  void _onTextChanged() {
    final isNotEmpty = _textController.text.trim().isNotEmpty;
    if (isNotEmpty != _isComposing) {
      setState(() => _isComposing = isNotEmpty);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _springController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    // Spring scale-down and snap back
    _springController.forward().then((_) => _springController.reverse());

    if (_editingMessage != null) {
      final msgToEdit = _editingMessage!;
      _editingMessage = null;
      _textController.clear();
      setState(() => _isComposing = false);

      try {
        await _chatService.editMessage(
          peerUid: widget.peerUid,
          messageId: msgToEdit.id,
          newText: text,
        );
        if (mounted) {
          CenterAlert.show(
            context,
            message: 'Message Edited ✓',
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF10B981),
          );
        }
      } catch (e) {
        if (mounted) {
          CenterAlert.show(
            context,
            message: 'Could not edit message',
            subtitle: e.toString(),
            icon: Icons.error_outline,
            iconColor: const Color(0xFFEF4444),
          );
        }
      }
      return;
    }

    _textController.clear();
    setState(() => _isComposing = false);

    // Instant message sending: optimistic UI updates instantly in 0ms!
    await _chatService.sendMessage(widget.peerUid, text);

    // Smoothly scroll to the bottom (index 0 in reverse ListView)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _textController.clear();
      _isComposing = false;
    });
  }

  void _showMessageActionMenu(ChatMessage message, bool isMe) {
    final selectedMessage = message;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.12),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              // Edit Message (Only if senderId == currentUid and not deleted)
              if (isMe && !message.isDeleted) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFF0F172A), size: 20),
                  title: Text(
                    'Edit Message',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _editingMessage = message;
                      _textController.text = message.text;
                      _textController.selection = TextSelection.fromPosition(
                        TextPosition(offset: message.text.length),
                      );
                    });
                    _focusNode.requestFocus();
                  },
                ),
              ],

              // Delete for Everyone (Only if senderId == currentUid and not deleted)
              if (isMe && !message.isDeleted) ...[
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFDC2626), size: 20),
                  title: Text(
                    'Delete for Everyone',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      final success = await ChatService.deleteMessageForEveryone(
                        chatId: widget.chatId,
                        messageId: selectedMessage.id,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Message deleted for everyone'
                                  : 'Could not delete message',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error deleting message for everyone: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not delete message: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],

              // Delete for Me
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 20),
                title: Text(
                  'Delete for Me',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _chatService.deleteMessageForMe(
                    peerUid: widget.peerUid,
                    messageId: message.id,
                  );
                  if (mounted) {
                    CenterAlert.show(
                      context,
                      message: 'Message Deleted for You',
                      icon: Icons.delete_outline,
                    );
                  }
                },
              ),

              // Copy Text (if not deleted)
              if (!message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 18),
                  title: Text(
                    'Copy Text',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Clipboard.setData(ClipboardData(text: message.text));
                    CenterAlert.show(
                      context,
                      message: 'Text Copied',
                      icon: Icons.copy_rounded,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Chat History?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Are you sure you want to clear your chat history? The messages will be removed from your view.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _chatService.clearChatHistoryForMe(chatId: _chatId, userUid: _currentUid);
                if (mounted) {
                  CenterAlert.show(
                    context,
                    message: 'Chat History Cleared',
                    icon: Icons.delete_sweep_rounded,
                    iconColor: const Color(0xFFDC2626),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not clear chat: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const swissPorcelain = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: swissPorcelain,
      body: Stack(
        children: [
          // 1. Subtle, static radial ambient glow layer
          _buildSwissPorcelainAmbientBackground(),

          // 2. Main Chat Layout with Mutual Friendship Enforcement Gate
          SafeArea(
            top: false,
            bottom: false,
            child: StreamBuilder<String?>(
              stream: FriendService().getFriendshipStatusStream(widget.peerUid),
              initialData: 'accepted',
              builder: (context, friendshipSnapshot) {
                final friendshipStatus = friendshipSnapshot.data ?? 'accepted';
                final isMutualFriend = friendshipStatus == 'accepted';

                return Column(
                  children: [
                    // Frosted Glass App Bar
                    _buildFrostedAppBar(context),

                    // Main Content: Message History or Restricted Lock Card
                    Expanded(
                      child: isMutualFriend
                          ? _buildLiveMessageHistory()
                          : _buildRestrictedLockCard(friendshipStatus),
                    ),

                    // Floating Frosted Pill Composer Dock
                    if (isMutualFriend)
                      _buildComposerDock()
                    else
                      _buildDisabledComposerDock(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Subtle static radial ambient glow for Swiss porcelain aesthetic
  Widget _buildSwissPorcelainAmbientBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.6),
            radius: 1.4,
            colors: [
              Color(0xFFF1F5F9), // Subtle light slate mist
              Color(0xFFF8FAFC), // Swiss porcelain
              Color(0xFFFFFFFF), // Crisp pure white highlight
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }

  /// App Bar: Frosted glass bar showing back button, peer avatar, peer display name, status pill, and 3-dots popup menu
  Widget _buildFrostedAppBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: (widget.peerUid.isNotEmpty && Firebase.apps.isNotEmpty)
          ? AuthService.firestoreInstance
              .collection('public_profiles')
              .doc(widget.peerUid)
              .snapshots()
          : null,
      builder: (context, profileSnap) {
        final profileData = profileSnap.data?.data();
        final displayName = (profileData?['displayName'] as String?)?.isNotEmpty == true
            ? (profileData!['displayName'] as String)
            : (_resolvedPeer?.displayName ?? widget.peerName);
        final isOnline = (profileData?['isOnline'] as bool?) ?? (_resolvedPeer?.isOnline ?? true);
        final handle = (profileData?['handle'] as String?) ?? (_resolvedPeer?.handle ?? '@user');

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.only(
                top: topPadding + 6,
                bottom: 12,
                left: 12,
                right: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFE2E8F0).withOpacity(0.8),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back Button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: const Color(0xFF0F172A),
                    splashRadius: 22,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),

                  // Header Identity using UserAvatarTile (Section 5)
                  Expanded(
                    child: UserAvatarTile(
                      peerUid: widget.peerUid,
                      radius: 18,
                      fallbackDisplayName: displayName,
                      nameStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: const Color(0xFF0F172A),
                      ),
                      showSubtitle: true,
                      fallbackSubtitle: handle.isNotEmpty
                          ? (handle.startsWith('@') ? handle : '@$handle')
                          : (isOnline ? 'Online' : 'Sanchat User'),
                    ),
                  ),

                  // Peer Info Action
                  IconButton(
                    tooltip: 'Peer Info',
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () {
                      CenterAlert.show(
                        context,
                        message: displayName,
                        subtitle: '$handle • UID: ${widget.peerUid.substring(0, widget.peerUid.length > 8 ? 8 : widget.peerUid.length)}...',
                        icon: Icons.shield_outlined,
                        iconColor: const Color(0xFF10B981),
                      );
                    },
                  ),

                  // 3-Dots Popup Menu for Clear Chat
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (value) {
                      if (value == 'clear') {
                        _confirmClearChat();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_sweep_outlined, size: 18, color: Color(0xFFDC2626)),
                            const SizedBox(width: 10),
                            Text(
                              'Clear Chat History',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Live Message History Stream
  Widget _buildLiveMessageHistory() {
    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.getMessagesStream(_chatId, limit: 50),
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

        final messages = snapshot.data ?? [];

        // Whenever new messages arrive in the active screen, mark them as seen
        if (messages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _chatService.markMessagesAsSeen(widget.peerUid);
          });
        }

        if (messages.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true, // Reverse list: index 0 is newest at bottom
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 12,
          ),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.isSentByMe(_currentUid);
            return _buildMessageBubble(message, isMe);
          },
        );
      },
    );
  }

  /// Centered Frosted Lock Card displayed when users are NOT mutual friends
  Widget _buildRestrictedLockCard(String status) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.90),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 26,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chat Locked',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chat Locked: Mutual friend request must be accepted before exchanging messages.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  if (status == 'incoming_pending' || status == 'pending_received') ...[
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await FriendService.acceptFriendRequest(
                          '${widget.peerUid}_$_currentUid',
                          widget.peerUid,
                          _currentUid,
                        );
                        await _chatService.acceptFriendRequest(widget.peerUid);
                        if (mounted) {
                          CenterAlert.show(
                            context,
                            message: 'Friend Request Accepted ✓',
                            icon: Icons.check_circle_outline,
                            iconColor: const Color(0xFF10B981),
                          );
                        }
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accept Friend Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ] else if (status == 'none' || status.isEmpty) ...[
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await FriendService.sendFriendRequest(
                          targetUid: widget.peerUid,
                          targetName: _resolvedPeer?.displayName ?? widget.peerName,
                          targetHandle: _resolvedPeer?.handle ?? 'user',
                        );
                        await _chatService.sendFriendRequest(widget.peerUid, _resolvedPeer);
                        if (mounted) {
                          CenterAlert.show(
                            context,
                            message: 'Friend Request Sent ⏳',
                            icon: Icons.person_add_alt_rounded,
                          );
                        }
                      },
                      icon: const Icon(Icons.person_add_alt_rounded, size: 16),
                      label: const Text('Send Friend Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Empty state matching Swiss porcelain minimalist aesthetic
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 26,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Encrypted 1-on-1 Chat',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Messages sent to ${widget.peerName} update instantly with live delivery checkmarks.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Message Bubbles with Long Press action menu and Edit/Delete badges
  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          child: GestureDetector(
            onLongPress: () => _showMessageActionMenu(message, isMe),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: isMe
                  ? BoxDecoration(
                      // Sender: Solid Obsidian Slate
                      color: message.isDeleted
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF0F172A),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    )
                  : BoxDecoration(
                      // Receiver: Pure white capsule
                      color: message.isDeleted
                          ? const Color(0xFFF8FAFC)
                          : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.04),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text Message
                  Text(
                    message.text,
                    style: message.isDeleted
                        ? GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                            color: isMe ? Colors.white60 : const Color(0xFF94A3B8),
                          )
                        : (isMe
                            ? GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                height: 1.35,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                              )
                            : GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                height: 1.35,
                                color: const Color(0xFF0F172A),
                                fontWeight: FontWeight.w400,
                              )),
                  ),
                  const SizedBox(height: 4),

                  // Footer Row: (edited badge) + Timestamp + Status Check
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (message.isEdited && !message.isDeleted) ...[
                        Text(
                          '(edited) ',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontStyle: FontStyle.italic,
                            color: isMe
                                ? Colors.white.withOpacity(0.55)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                      Text(
                        message.formattedTime,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withOpacity(0.65)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (isMe && !message.isDeleted) ...[
                        const SizedBox(width: 4),
                        MessageStatusTick(
                          status: message.status,
                          size: 14,
                          colorOverride: message.status == 'seen'
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF94A3B8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Disabled Composer Dock when not mutual friends
  Widget _buildDisabledComposerDock() {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, safeBottom > 0 ? safeBottom + 8 : 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_outline, size: 16, color: Color(0xFF94A3B8)),
            SizedBox(width: 8),
            Text(
              'Chat Locked: Both users must accept friend requests to message.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Input Composer Dock:
  /// Floating frosted pill container anchored at the bottom with proper SafeArea.
  /// Shows edit banner when _editingMessage != null.
  Widget _buildComposerDock() {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, safeBottom > 0 ? safeBottom + 8 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit Mode Banner
          if (_editingMessage != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 14, color: Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editing: ${_editingMessage!.text}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _cancelEditing,
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],

          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.04),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 6),
                    // Clean Input TextField
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: _editingMessage != null ? 'Edit message...' : 'Type a message...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            color: const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _handleSendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tactile Circular Send Button with Spring Animation
                    GestureDetector(
                      onTapDown: (_) => _springController.forward(),
                      onTapUp: (_) => _springController.reverse(),
                      onTapCancel: () => _springController.reverse(),
                      onTap: _isComposing ? _handleSendMessage : null,
                      child: ScaleTransition(
                        scale: _springScale,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isComposing
                                ? (_editingMessage != null ? const Color(0xFF10B981) : const Color(0xFF0F172A))
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            boxShadow: _isComposing
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _editingMessage != null ? Icons.check : Icons.arrow_upward_rounded,
                            size: 20,
                            color: _isComposing ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
