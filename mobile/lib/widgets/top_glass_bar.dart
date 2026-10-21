import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../screens/recent_chats_screen.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import 'avatar_widget.dart';
import 'pending_requests_modal.dart';
import 'profile_image_picker_modal.dart';
import 'brand_logo.dart';

class TopGlassBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  const TopGlassBar({
    super.key,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                if (showBackButton) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                    color: AppColors.obsidian,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                ],
                const SanchatBrandLogo(size: 28),
                const SizedBox(width: 8),
                Text(
                  'SANCHAT',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.2,
                    color: AppColors.obsidian,
                  ),
                ),
                const Spacer(),
                // 1. SyncStatusBadge
                SyncStatusBadge(isCloudConnected: provider.isCloudConnected),
                const SizedBox(width: 8),
                // 2. ChatIconButton
                const ChatIconButton(),
                // 3. UserAvatarButton (size: 36 with 8px horizontal padding)
                UserAvatarButton(
                  avatarUrl: provider.userAvatarUrl,
                  size: 36,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SanchayUnifiedHeader extends StatelessWidget {
  final bool? showBackButton;
  final VoidCallback? onBack;
  final bool showChatHighlight;
  final Widget? subHeader;

  const SanchayUnifiedHeader({
    super.key,
    this.showBackButton,
    this.onBack,
    this.showChatHighlight = false,
    this.subHeader,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton ?? Navigator.canPop(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canPop) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                        color: AppColors.obsidian,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 4),
                    ],
                    const SanchatBrandLogo(size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'SANCHAT',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.2,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SyncStatusBadge(),
                    const SizedBox(width: 4),
                    // Friend Request Bell with Badge
                    StreamBuilder<int>(
                      stream: FriendService().getIncomingRequestsCountStream(),
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.obsidian,
                                size: 21,
                              ),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'Friend Requests',
                              onPressed: () => PendingRequestsModal.show(context),
                            ),
                            if (count > 0)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: GestureDetector(
                                  onTap: () => PendingRequestsModal.show(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      '$count',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    ChatIconButton(showGuideHighlight: showChatHighlight),
                    const UserAvatarButton(size: 36),
                  ],
                ),
              ],
            ),
            if (subHeader != null) ...[
              const SizedBox(height: 12),
              subHeader!,
            ],
          ],
        ),
      ),
    );
  }
}

class SyncStatusBadge extends StatelessWidget {
  final bool? isCloudConnected;

  const SyncStatusBadge({super.key, this.isCloudConnected});

  @override
  Widget build(BuildContext context) {
    final connected = isCloudConnected ??
        context.watch<SanchayProvider>().isCloudConnected;

    return Tooltip(
      message: connected
          ? 'Live Cloud Sync Connected'
          : 'Local Vault Active',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.emeraldFixed.withOpacity(0.35),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: connected
                    ? AppColors.emerald
                    : AppColors.amberPace,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (connected
                            ? AppColors.emerald
                            : AppColors.amberPace)
                        .withOpacity(0.6),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'SYNC',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.onEmeraldFixedVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatIconButton extends StatelessWidget {
  final bool showGuideHighlight;

  const ChatIconButton({super.key, this.showGuideHighlight = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ChatService().getTotalUnreadCountStream(),
      builder: (context, badgeSnap) {
        final unreadCount = badgeSnap.data ?? 0;

        return Tooltip(
          message: showGuideHighlight ? 'Find contacts by handle or UID' : 'Encrypted Chats',
          waitDuration: const Duration(milliseconds: 300),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => RecentChatsScreen.push(context),
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.obsidian.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: AppColors.obsidian,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (showGuideHighlight)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withOpacity(0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}

class UserAvatarButton extends StatelessWidget {
  final String? avatarUrl;
  final String? initials;
  final double size;
  final VoidCallback? onTap;

  const UserAvatarButton({
    super.key,
    this.avatarUrl,
    this.initials,
    this.size = 36,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final effectiveUrl = avatarUrl ?? provider.userAvatarUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onTap ?? () => ProfileImagePickerModal.show(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: buildUserAvatar(
                effectiveUrl,
                radius: size / 2,
                initials: provider.userName.isNotEmpty ? provider.userName.substring(0, 1) : null,
              ),
            ),
            // Active Edit Pencil Overlay Badge
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.obsidian,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.obsidian.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.edit,
                    size: 7.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alias for SanchayUnifiedHeader
typedef SanchatUnifiedHeader = SanchayUnifiedHeader;
