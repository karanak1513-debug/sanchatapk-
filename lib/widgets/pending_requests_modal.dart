import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/friend_request.dart';
import '../services/friend_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import 'center_alert.dart';

class PendingRequestsModal extends StatelessWidget {
  const PendingRequestsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PendingRequestsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final friendService = FriendService();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.crimson.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.crimson,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Friend Requests',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const Text(
                              'Users waiting to connect with you on Sanchay',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Live stream of incoming pending requests
                Flexible(
                  child: StreamBuilder<List<FriendRequest>>(
                    stream: friendService.getIncomingRequestsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }

                      final requests = snapshot.data ?? [];

                      if (requests.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 26,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'All Caught Up',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'You have no pending friend requests right now.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        itemCount: requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final req = requests[index];
                          final initials = req.senderName.isNotEmpty
                              ? req.senderName.substring(0, 1).toUpperCase()
                              : 'U';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ProfileService().buildAvatarWidget(
                                      avatarUrl: req.senderAvatar,
                                      initials: initials,
                                      radius: 20,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req.senderName.isNotEmpty ? req.senderName : 'Sanchay User',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            req.senderHandle,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Action buttons: [ ✓ Accept ] and [ ✕ Decline ]
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 36,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            await FriendService.acceptFriendRequest(
                                              req.requestId,
                                              req.senderUid,
                                              req.receiverUid,
                                            );
                                            if (context.mounted) {
                                              CenterAlert.show(
                                                context,
                                                message: 'Friend Request Accepted ✓',
                                                subtitle: 'You are now mutual friends',
                                                icon: Icons.check_circle_outline,
                                                iconColor: const Color(0xFF10B981),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.check, size: 15),
                                          label: const Text(
                                            '✓ Accept',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: SizedBox(
                                        height: 36,
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            await FriendService.rejectFriendRequest(req.requestId);
                                            if (context.mounted) {
                                              CenterAlert.show(
                                                context,
                                                message: 'Request Declined',
                                                icon: Icons.close_rounded,
                                                iconColor: const Color(0xFF64748B),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.close, size: 15),
                                          label: const Text(
                                            '✕ Decline',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFDC2626),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 36,
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              title: Text(
                                                'Block ${req.senderName.isNotEmpty ? req.senderName : "User"}?',
                                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17),
                                              ),
                                              content: const Text(
                                                'Blocked users will no longer be able to message you or view your profile.',
                                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(ctx).pop(false),
                                                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.of(ctx).pop(true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFDC2626),
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  child: const Text('Block'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await friendService.blockUser(targetUid: req.senderUid);
                                            if (context.mounted) {
                                              CenterAlert.show(
                                                context,
                                                message: 'User Blocked',
                                                icon: Icons.block_rounded,
                                                iconColor: const Color(0xFFDC2626),
                                              );
                                            }
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF64748B),
                                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text(
                                          '🚫 Block',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
