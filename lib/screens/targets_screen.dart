import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sanchay_target.dart';
import '../providers/sanchay_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_intelligence_modal.dart';
import '../widgets/configure_target_modal.dart';
import '../widgets/frosted_glass_card.dart';
import '../widgets/top_glass_bar.dart';
import '../widgets/vault_card.dart';
import '../widgets/vault_contribution_modal.dart';
import '../widgets/vault_transfer_modal.dart';
import '../services/target_service.dart';

class TargetsScreen extends StatelessWidget {
  const TargetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: uid.isNotEmpty
          ? AuthService.firestoreInstance
              .collection('users')
              .doc(uid)
              .collection('targets')
              .snapshots()
          : null,
      builder: (context, snapshot) {
        final provider = context.watch<SanchayProvider>();
        List<SanchayTarget> allVaults = provider.targets;
        if (snapshot.hasData && snapshot.data != null) {
          final docs = snapshot.data!.docs;
          if (docs.isNotEmpty) {
            allVaults = docs.map((d) {
              final data = d.data();
              final directAccum = (data['currentAccumulation'] as num?)?.toDouble() ?? 0.0;
              final target = SanchayTarget.fromFirestore(d, liveAccumulation: directAccum);

              // If Firestore document currentAccumulation is 0, check ledger transactions fallback
              if (target.currentAccumulation == 0) {
                final txSum = provider.transactions
                    .where((tx) =>
                        (tx.type.toLowerCase() == 'vault_deposit' ||
                            tx.type.toLowerCase() == 'vault_transfer') &&
                        (tx.targetId == target.id ||
                            (tx.vaultId != null && tx.vaultId == target.id) ||
                            tx.title.toLowerCase().contains(target.title.toLowerCase()) ||
                            target.title.toLowerCase().contains(tx.title.toLowerCase())))
                    .fold<double>(0.0, (acc, tx) => acc + tx.amount);
                if (txSum > 0) {
                  return target.copyWith(currentAccumulation: txSum);
                }
              }
              return target;
            }).toList();

            // If single vault accumulation is 0 but transactions have vault deposits
            if (allVaults.length == 1 && allVaults.first.currentAccumulation == 0) {
              final anyVaultTx = provider.transactions
                  .where((tx) =>
                      tx.type.toLowerCase() == 'vault_deposit' ||
                      tx.type.toLowerCase() == 'vault_transfer' ||
                      tx.category.toLowerCase().contains('vault'))
                  .fold<double>(0.0, (acc, tx) => acc + tx.amount);
              if (anyVaultTx > 0) {
                allVaults = [allVaults.first.copyWith(currentAccumulation: anyVaultTx)];
              }
            }

            allVaults.sort((a, b) {
              final aCreated = a.createdAt ?? DateTime(2000);
              final bCreated = b.createdAt ?? DateTime(2000);
              return bCreated.compareTo(aCreated);
            });
          } else if (docs.isEmpty) {
            allVaults = [];
          }
        }

        final activeVault = (provider.selectedVaultId != null)
            ? (allVaults.where((t) => t.id == provider.selectedVaultId).firstOrNull ?? allVaults.firstOrNull)
            : (allVaults.where((t) => t.isPrimary).firstOrNull ?? allVaults.firstOrNull);

        final rawVaultAccum = activeVault?.currentAccumulation ?? provider.currentVault;
        final vaultAccumulation = rawVaultAccum > 0
            ? rawVaultAccum
            : provider.transactions
                .where((tx) =>
                    tx.type.toLowerCase() == 'vault_deposit' ||
                    tx.type.toLowerCase() == 'vault_transfer' ||
                    tx.category.toLowerCase().contains('vault'))
                .fold<double>(0.0, (acc, tx) => acc + tx.amount);

        final progress = activeVault != null
            ? (activeVault.targetCap > 0 ? (vaultAccumulation / activeVault.targetCap).clamp(0.0, 1.0) : 0.0)
            : provider.vaultProgress;
        final percentage = (progress * 100).round();
        final isPaused = activeVault != null ? activeVault.isPaused : provider.isTargetPaused;
        final vaultTitle = activeVault?.title ?? provider.targetName;
        final vaultCap = activeVault?.targetCap ?? provider.goalCap;
        final vaultRemaining = (vaultCap - vaultAccumulation).clamp(0.0, double.infinity);
        final vaultTargetDate = activeVault?.targetDate ?? provider.targetDate;
        final vaultRemainingDays = activeVault?.remainingDays ?? provider.remainingDaysToTarget;
        final vaultDailyPace = activeVault?.dailyPace ?? provider.dailyPace;
        final vaultWeeklyPace = activeVault?.weeklyPace ?? provider.weeklyPace;
        final vaultMonthlyPace = activeVault?.monthlyPace ?? provider.monthlyPace;
        final accentColor = activeVault?.accentColor ?? AppColors.crimson;

        // Aggregates across all multi-vaults
        final totalCapAllVaults = allVaults.fold(0.0, (acc, t) => acc + t.targetCap);
        final calcAccumAll = allVaults.fold(0.0, (acc, t) => acc + t.currentAccumulation);
        final totalAccumulationAllVaults = calcAccumAll > 0 ? calcAccumAll : vaultAccumulation;
        final totalDailyPaceAllVaults = allVaults.where((t) => !t.isPaused && !t.isAchieved).fold(0.0, (acc, t) => acc + t.dailyPace);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        bottom: false, // Navigation dock handles bottom clearance
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Responsive App Header
            const SliverToBoxAdapter(
              child: SanchayUnifiedHeader(),
            ),

            // Screen Body with Strict Spacing & Bottom Dock Clearance
            SliverPadding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  // Section Title & Multi-Vault Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MULTI-VAULT GOALS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: AppColors.crimson,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Goals & Multi-Vault',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: AppColors.obsidian,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (allVaults.length >= 2) ...[
                            IconButton(
                              onPressed: () => VaultTransferModal.show(context),
                              tooltip: 'Transfer Between Vaults',
                              icon: const Icon(Icons.swap_horiz, size: 18),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.surfaceContainerLow,
                                foregroundColor: AppColors.obsidian,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton.icon(
                            onPressed: () => CreateTargetModal.show(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New Vault'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.obsidian,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Vault Selection Horizontal Pills
                  if (allVaults.length > 1) ...[
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: allVaults.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final v = allVaults[i];
                          final isSelected = (activeVault?.id == v.id);
                          return InkWell(
                            onTap: () => provider.selectVault(v.id),
                            borderRadius: BorderRadius.circular(999),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.obsidian : Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isSelected ? AppColors.obsidian : AppColors.surfaceContainerHigh,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    v.iconData,
                                    size: 14,
                                    color: isSelected ? Colors.white : v.accentColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    v.title,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: isSelected ? Colors.white : AppColors.obsidian,
                                    ),
                                  ),
                                  if (v.isPrimary) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.star, size: 10, color: isSelected ? Colors.white70 : AppColors.amberPace),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 1. Primary Interactive Hero Target Card
                  FrostedGlassCard(
                    borderRadius: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: (activeVault?.accentColor ?? AppColors.emerald).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      image: activeVault?.imageProvider != null
                                          ? DecorationImage(
                                              image: activeVault!.imageProvider!,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: activeVault?.imageProvider == null
                                        ? Icon(
                                            activeVault?.iconData ?? Icons.flag_rounded,
                                            color: activeVault?.accentColor ?? AppColors.emerald,
                                            size: 20,
                                          )
                                        : null,
                                  ),
                                  Flexible(
                                    child: Text(
                                      vaultTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isPaused ? AppColors.onSurfaceVariant : AppColors.obsidian,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => ConfigureTargetModal.show(context, target: activeVault),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.obsidian),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                if (activeVault != null) {
                                  provider.toggleVaultPause(activeVault.id);
                                } else {
                                  provider.toggleTargetPaused();
                                }
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isPaused
                                      ? AppColors.amberPace.withOpacity(0.15)
                                      : AppColors.emeraldFixed.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isPaused
                                        ? AppColors.amberPace.withOpacity(0.3)
                                        : AppColors.emerald.withOpacity(0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPaused ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                      size: 13,
                                      color: isPaused ? AppColors.amberPace : AppColors.emerald,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isPaused ? 'PAUSED' : 'ACTIVE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: isPaused ? AppColors.amberPace : AppColors.onEmeraldFixedVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Balances Grid
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CURRENT ACCUMULATION',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.formatCurrency(vaultAccumulation),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                    color: isPaused ? AppColors.onSurfaceVariant : AppColors.obsidian,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'GOAL TARGET',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.formatCurrency(vaultCap),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Progress Bar
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress < 0.08 ? 0.08 : progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isPaused ? AppColors.onSurfaceVariant : accentColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${provider.formatCurrency(vaultAccumulation)} of ${provider.formatCurrency(vaultCap)} ($percentage% Paced)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isPaused ? AppColors.onSurfaceVariant : accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${provider.formatCurrency(vaultRemaining)} to Goal',
                              style: AppTheme.monoNumeric(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Target Date Pill & Quick Deposit
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.obsidian),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat('MMM d, yyyy').format(vaultTargetDate),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.obsidian,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '$vaultRemainingDays days left',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => VaultContributionModal.show(context, target: activeVault),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.obsidian,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: const Text('Deposit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Smart Advice Banner
                  InkWell(
                    onTap: () => AIIntelligenceModal.show(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: isPaused
                            ? AppColors.amberPace.withOpacity(0.08)
                            : (provider.isTargetOnTrack
                                ? AppColors.emeraldFixed.withOpacity(0.3)
                                : AppColors.crimsonFixedDim.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPaused
                              ? AppColors.amberPace.withOpacity(0.3)
                              : (provider.isTargetOnTrack
                                  ? AppColors.emerald.withOpacity(0.3)
                                  : AppColors.crimson.withOpacity(0.3)),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPaused
                                  ? Icons.pause_circle_outline
                                  : (provider.isTargetOnTrack
                                      ? Icons.auto_awesome
                                      : Icons.warning_amber_rounded),
                              size: 20,
                              color: isPaused
                                  ? AppColors.amberPace
                                  : (provider.isTargetOnTrack ? AppColors.emerald : AppColors.crimson),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isPaused
                                            ? 'Goal Pacing Paused'
                                            : (provider.isTargetOnTrack
                                                ? "Great pace! You'll hit your goal early"
                                                : 'Behind Schedule (${provider.healthScore.totalScore}/100)'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isPaused
                                              ? AppColors.obsidian
                                              : (provider.isTargetOnTrack
                                                  ? AppColors.onEmeraldFixedVariant
                                                  : AppColors.crimson),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Advice',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.obsidian,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(Icons.chevron_right, size: 12, color: AppColors.obsidian),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.aiInsightMessage,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: AppColors.obsidian.withOpacity(0.85),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Focused Vault Savings Pace Grid
                  Text(
                    '${vaultTitle.toUpperCase()} RUN-RATE PACING',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Daily Target',
                          value: provider.formatCurrency(vaultDailyPace),
                          subtitle: 'Target per day',
                          icon: Icons.speed,
                          color: AppColors.obsidian,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Weekly Target',
                          value: provider.formatCurrency(vaultWeeklyPace),
                          subtitle: 'Target per week',
                          icon: Icons.calendar_view_week,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Monthly Target',
                          value: provider.formatCurrency(vaultMonthlyPace),
                          subtitle: 'Target per month',
                          icon: Icons.event_repeat,
                          color: AppColors.obsidian,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Remaining to Save',
                          value: provider.formatCurrency(vaultRemaining),
                          subtitle: 'To reach goal',
                          icon: Icons.hourglass_bottom,
                          color: AppColors.crimson,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. Multi-Vault Portfolio Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ALL SAVINGS VAULTS (${allVaults.length})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      InkWell(
                        onTap: () => CreateTargetModal.show(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.crimson.withOpacity(0.25), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 14, color: AppColors.crimson),
                              const SizedBox(width: 4),
                              Text(
                                '+ New Vault',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.crimson,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (snapshot.hasError) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.crimson.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.crimson),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Syncing offline cache: ${snapshot.error}',
                              style: const TextStyle(fontSize: 11, color: AppColors.crimson),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (allVaults.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.savings_outlined, size: 36, color: AppColors.onSurfaceVariant.withOpacity(0.4)),
                            const SizedBox(height: 8),
                            Text(
                              'No savings vaults yet. Tap "+ New Vault" to create your first goal.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Render each VaultCard with optional swipe-to-delete
                  ...allVaults.map((vault) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Dismissible(
                        key: ValueKey('vault_dismiss_${vault.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Vault?'),
                              content: const Text('This will remove this goal and its allocation history.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) async {
                          await TargetVaultService.deleteVault(vault.id);
                          provider.deleteVault(vault.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Goal deleted successfully')),
                            );
                          }
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: AppColors.crimson, size: 24),
                        ),
                        child: VaultCard(
                          target: vault,
                          isSelected: activeVault?.id == vault.id,
                          onSelect: () => provider.selectVault(vault.id),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // 5. Aggregated Portfolio Summary Card
                  FrostedGlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL MULTI-VAULT PORTFOLIO',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.obsidian,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPortfolioSummaryCol('Total Target Corpus', provider.formatCurrency(totalCapAllVaults)),
                            _buildPortfolioSummaryCol('Total Accumulated', provider.formatCurrency(totalAccumulationAllVaults), isEmerald: true),
                            _buildPortfolioSummaryCol('Combined Daily Pace', provider.formatCurrency(totalDailyPaceAllVaults)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildPortfolioSummaryCol(String label, String value, {bool isEmerald = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isEmerald ? AppColors.emerald : AppColors.obsidian,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.obsidian,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
