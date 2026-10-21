import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sanchay_target.dart';
import '../providers/sanchay_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'configure_target_modal.dart';
import 'edit_target_modal.dart';
import 'frosted_glass_card.dart';
import 'vault_contribution_modal.dart';

class VaultCard extends StatelessWidget {
  final SanchayTarget target;
  final bool isSelected;
  final VoidCallback? onSelect;

  const VaultCard({
    super.key,
    required this.target,
    this.isSelected = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final isPaused = target.isPaused;
    final isPrimary = target.isPrimary;
    final progress = target.progress;
    final percentage = target.percentage;
    final accentColor = target.accentColor;

    return FrostedGlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          isPrimary
              ? AppColors.obsidian.withOpacity(0.4)
              : (isSelected ? accentColor.withOpacity(0.6) : Colors.white.withOpacity(0.95)),
          isPrimary
              ? AppColors.obsidian.withOpacity(0.2)
              : (isSelected ? accentColor.withOpacity(0.3) : const Color(0xFFCBD5E1).withOpacity(0.40)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Category Icon / Image, Title, and Status/Action Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        image: target.imageProvider != null
                            ? DecorationImage(
                                image: target.imageProvider!,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: target.imageProvider == null
                          ? Icon(target.iconData, color: accentColor, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  target.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isPaused ? AppColors.onSurfaceVariant : AppColors.obsidian,
                                  ),
                                ),
                              ),
                              if (isPrimary) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.obsidian,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'PRIMARY',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${target.category} • Target: ${DateFormat('MMM yyyy').format(target.targetDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.onSurfaceVariant),
                tooltip: 'Edit Vault',
                visualDensity: VisualDensity.compact,
                onPressed: () => EditTargetModal.show(context, vaultId: target.id, target: target),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.onSurfaceVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  if (val == 'edit') {
                    EditTargetModal.show(context, vaultId: target.id, target: target);
                  } else if (val == 'contribute') {
                    VaultContributionModal.show(context, target: target);
                  } else if (val == 'pause') {
                    provider.toggleVaultPause(target.id);
                  } else if (val == 'primary') {
                    provider.setPrimaryVault(target.id);
                  } else if (val == 'delete') {
                    _confirmDelete(context, provider);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'contribute',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 16, color: AppColors.emerald),
                        SizedBox(width: 10),
                        Text('Contribute Funds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.tune, size: 16, color: AppColors.obsidian),
                        SizedBox(width: 10),
                        Text('Configure Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (!isPrimary)
                    const PopupMenuItem(
                      value: 'primary',
                      child: Row(
                        children: [
                          Icon(Icons.star_outline, size: 16, color: AppColors.amberPace),
                          SizedBox(width: 10),
                          Text('Set as Primary Vault', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'pause',
                    child: Row(
                      children: [
                        Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 16, color: AppColors.obsidian),
                        SizedBox(width: 10),
                        Text(isPaused ? 'Resume Pacing' : 'Pause Goal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (provider.targets.length > 1)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: AppColors.crimson),
                          SizedBox(width: 10),
                          Text('Delete Vault', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.crimson)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Balances & Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCUMULATION',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.formatCurrency(target.currentAccumulation),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isPaused ? AppColors.onSurfaceVariant : AppColors.obsidian,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'TARGET CAP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.formatCurrency(target.targetCap),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress < 0.05 ? 0.05 : progress,
              child: Container(
                decoration: BoxDecoration(
                  color: isPaused ? AppColors.onSurfaceVariant : accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Sub-progress labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percentage% fulfilled',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isPaused ? AppColors.onSurfaceVariant : accentColor,
                ),
              ),
              Text(
                '${provider.formatCurrency(target.dailyPace)}/day • ${target.remainingDays}d left',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Button: One-tap Deposit
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => VaultContributionModal.show(context, target: target),
              icon: const Icon(Icons.add, size: 14),
              label: Text(
                'Deposit to ${target.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.obsidian,
                side: BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SanchayProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${target.title}"?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Delete this vault and all its target tracking?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              if (currentUid.isNotEmpty) {
                try {
                  await AuthService.firestoreInstance
                      .collection('users')
                      .doc(currentUid)
                      .collection('targets')
                      .doc(target.id)
                      .delete();
                } catch (e) {
                  debugPrint('Error deleting target in firestore: $e');
                }
              }
              await provider.deleteVault(target.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
            child: const Text('Delete Vault', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
