import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../providers/sanchay_provider.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/ledger_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/ai_intelligence_modal.dart';
import '../widgets/center_hud_alert.dart';
import '../widgets/configure_target_modal.dart';
import '../widgets/countdown_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/pending_requests_modal.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/privacy_text.dart';
import '../widgets/safe_to_spend_sheet.dart';
import '../widgets/sms_parser_modal.dart';
import '../widgets/spending_trend_chart.dart';
import '../widgets/brand_logo.dart';
import 'chat_messages_list_screen.dart';
import 'app_guide_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenSettings;

  const DashboardScreen({super.key, this.onOpenSettings});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  int _sessionCount = 1;
  bool _showAnalyticsCharts = false;
  int _dashboardLedgerTab = 0; // 0: UPI & Bank Stream, 1: Vault Allocations

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSessionTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SanchayProvider>().checkNotificationPermission();
      _checkClipboardAutoParse();
      // Onboarding guide sheet auto-launch disabled permanently
    });
  }

  Future<void> _initSessionTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt('dashboard_session_count') ?? 0;
      final updated = current + 1;
      await prefs.setInt('dashboard_session_count', updated);
      if (mounted) {
        setState(() => _sessionCount = updated);
      }
    } catch (e) {
      debugPrint('Error updating dashboard session count: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<SanchayProvider>().checkNotificationPermission();
    }
  }

  Future<void> _checkClipboardAutoParse() async {
    final provider = context.read<SanchayProvider>();
    if (!provider.clipboardAutoParse) return;
    final parsed = await provider.checkClipboardForSms();
    if (parsed != null && mounted) {
      CenterAlert.show(
        context,
        message: '📋 Bank SMS Detected in Clipboard',
        subtitle: '${parsed.merchant} • ${provider.formatCurrency(parsed.amount)}',
        icon: Icons.mark_email_read_outlined,
        iconColor: AppColors.emerald,
      );
      SmsParserModal.show(context, initialText: parsed.rawText);
    }
  }

  void _showTransactionDetails(BuildContext context, Transaction tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.obsidian.withOpacity(0.12),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tx.category.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: tx.isDebit ? AppColors.crimson : AppColors.emerald,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tx.tag,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tx.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Consumer<SanchayProvider>(
              builder: (context, p, child) => Text(
                p.formatCurrency(tx.amount, isSigned: true, isDebit: tx.isDebit),
                style: AppTheme.monoNumeric(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: tx.isDebit ? AppColors.crimson : AppColors.emerald,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.surfaceContainerHigh),
            const SizedBox(height: 12),
            _buildDetailRow('Payment App', tx.channel),
            _buildDetailRow('Date & Time', DateFormat('MMM d, yyyy • hh:mm a').format(tx.timestamp)),
            _buildDetailRow('Reference ID', tx.id),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.read<SanchayProvider>().deleteTransaction(tx.id);
                  CenterAlert.show(
                    context,
                    message: 'Transaction Deleted',
                    subtitle: tx.title,
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.crimson,
                  );
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.crimson, size: 20),
                label: const Text(
                  'Delete Transaction',
                  style: TextStyle(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.crimsonFixedDim),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final isFirst3Sessions = _sessionCount <= 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Single, clean, properly padded Mobile Header inside SafeArea
            SliverToBoxAdapter(
              child: _buildHeader(context, provider),
            ),

            // Unified 20px horizontal margins & 140px bottom dock clearance
            SliverPadding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Permission Banner (Pulsing beacon if ungranted during early sessions)
                  if (!provider.isNotificationPermissionGranted) ...[
                    _StaggeredFadeSlide(
                      index: 0,
                      child: _buildPermissionBanner(context, provider, isFirst3Sessions),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Contextual First-Time Guide Tip Capsule
                  if (isFirst3Sessions) ...[
                    _buildContextualGuideTip(),
                    const SizedBox(height: 16),
                  ],

                  // =========================================================
                  // BENTO CARD A: THE RUNWAY DIAL (DAILY SAFE-TO-SPEND)
                  // =========================================================
                  _StaggeredFadeSlide(
                    index: 1,
                    child: _buildCardARunwayDial(context, provider),
                  ),
                  const SizedBox(height: 16),

                  // =========================================================
                  // BENTO CARD B: ACTIVE VAULT PROGRESS
                  // =========================================================
                  _StaggeredFadeSlide(
                    index: 2,
                    child: _buildCardBActiveVault(context, provider),
                  ),
                  const SizedBox(height: 16),

                  // =========================================================
                  // BENTO CARD C: NET CASH LIQUIDITY
                  // =========================================================
                  _StaggeredFadeSlide(
                    index: 3,
                    child: _buildCardCNetCashLiquidity(context, provider),
                  ),
                  const SizedBox(height: 16),

                  // =========================================================
                  // BENTO CARD D: RECENT ACTIVITY CAPSULE
                  // =========================================================
                  _StaggeredFadeSlide(
                    index: 4,
                    child: _buildCardDRecentActivity(context, provider),
                  ),
                  const SizedBox(height: 20),

                  // Optional Analytics Toggle: Deeper Charts & Countdown
                  _buildAnalyticsToggleSection(context, provider),

                  if (_showAnalyticsCharts) ...[
                    const SizedBox(height: 16),
                    const CountdownCard(),
                    const SizedBox(height: 16),
                    const ExpenseRingChart(),
                    const SizedBox(height: 16),
                    const SpendingTrendChart(),
                  ],

                  const SizedBox(height: 12),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STANDARDIZED MOBILE HEADER ROW (ZERO CLIPPING / ZERO OVERLAP)
  // ===========================================================================
  Widget _buildHeader(BuildContext context, SanchayProvider provider) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        final rawName = (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim().split(' ').first
            : (user?.email?.trim().isNotEmpty ?? false)
                ? user!.email!.trim().split('@').first
                : (provider.userName.trim().isNotEmpty ? provider.userName : 'Karan');
        final displayName = rawName.isNotEmpty
            ? '${rawName[0].toUpperCase()}${rawName.substring(1)}'
            : 'User';

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Brand Logo + 'SANCHAT' | Spacer | Guide Pill | Friend Request Bell | Chat Icon | Avatar.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SanchatBrandLogo(size: 28),
                        SizedBox(width: 8),
                        Text(
                          'SANCHAT',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.2,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Guide Action Pill
                        _TactileBounce(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AppGuideScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.black.withOpacity(0.08)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.obsidian.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.explore_outlined, size: 14, color: AppColors.emerald),
                                SizedBox(width: 4),
                                Text(
                                  'Guide',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.obsidian,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Friend Request Bell with Badge
                        StreamBuilder<int>(
                          stream: FriendService().getIncomingRequestsCountStream(user?.uid),
                          builder: (context, snap) {
                            final count = snap.data ?? 0;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.notifications_outlined,
                                    color: Color(0xFF0F172A),
                                    size: 22,
                                  ),
                                  padding: const EdgeInsets.all(4),
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
                                            fontSize: 9.5,
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
                        // Chat Icon
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF0F172A),
                            size: 22,
                          ),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Sanchay Connect',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChatMessagesListScreen(),
                              ),
                            );
                          },
                        ),
                        // Standard Circular Avatar
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: GestureDetector(
                            onTap: () {
                              if (widget.onOpenSettings != null) {
                                widget.onOpenSettings!();
                              } else {
                                Navigator.pushNamed(context, '/preferences');
                              }
                            },
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: buildUserAvatar(
                                provider.userAvatarUrl,
                                radius: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Sub-Header Row: Greeting Text ("Good day, [Name]") with Live Sync indicator & Pacing Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good day, $displayName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Live Sync Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Pacing Pill
                    _TactileBounce(
                      onTap: () => ConfigureTargetModal.show(context),
                      child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: provider.isTargetPaused
                                ? AppColors.amberPace.withOpacity(0.12)
                                : AppColors.emeraldFixed.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: provider.isTargetPaused
                                  ? AppColors.amberPace.withOpacity(0.3)
                                  : AppColors.emerald.withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                provider.isTargetPaused
                                    ? Icons.pause_circle_outline
                                    : Icons.auto_graph,
                                size: 12,
                                color: provider.isTargetPaused
                                    ? AppColors.amberPace
                                    : AppColors.emerald,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                provider.isTargetPaused ? 'Paused' : 'On Pace',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.obsidian,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }


  // ===========================================================================
  // CONTEXTUAL GUIDE TIP CAPSULE
  // ===========================================================================
  Widget _buildContextualGuideTip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tips_and_updates, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Quick tip: Tap the (+) button below anytime to log a manual deposit or expense.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E3A8A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PERMISSION BANNER WITH PULSING BEACON
  // ===========================================================================
  Widget _buildPermissionBanner(BuildContext context, SanchayProvider provider, bool isFirst3Sessions) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: Colors.white,
      onTap: () => provider.openNotificationListenerSettings(),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.crimsonFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt, color: AppColors.crimson, size: 20),
              ),
              if (isFirst3Sessions)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.amberPace,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Automatic Tracking Off',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.crimson,
                      ),
                    ),
                    if (isFirst3Sessions) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.amberPace.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ACTION NEEDED',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amberPace,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Auto-tracking inactive • Tap to grant notification listener',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.obsidian,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Turn On',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BENTO CARD A: THE RUNWAY DIAL (DAILY SAFE-TO-SPEND)
  // ===========================================================================
  Widget _buildCardARunwayDial(BuildContext context, SanchayProvider provider) {
    final metrics = provider.safeToSpend;
    final safeToSpend = metrics.todaySafeToSpend;
    final burnPercent = (metrics.todayBurnRateRatio.clamp(0.0, 1.0) * 100).round();

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      backgroundColor: Colors.white,
      onTap: () => SafeToSpendSheet.show(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldFixed.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.speed_rounded, color: AppColors.emeraldDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'DAILY SPENDING RUNWAY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldFixed.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(
                      '${metrics.remainingDaysInMonth}d Safe',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.emeraldDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Central Dial Layout
          Row(
            children: [
              // Circular Runway Arc Gauge
              SizedBox(
                width: 88,
                height: 88,
                child: CustomPaint(
                  painter: _CircularGaugePainter(
                    progress: (1.0 - metrics.todayBurnRateRatio).clamp(0.0, 1.0),
                    trackColor: const Color(0xFFF1F5F9),
                    fillColor: metrics.isOverspent ? AppColors.crimson : AppColors.emerald,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${100 - burnPercent}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.obsidian,
                          ),
                        ),
                        Text(
                          'Runway',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Value & Headline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrivacyText(
                      rawText: provider.formatCurrency(safeToSpend),
                      monetaryValue: safeToSpend,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: metrics.isOverspent ? AppColors.crimson : AppColors.obsidian,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Safe to spend ${provider.formatCurrency(safeToSpend)} today',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: metrics.isOverspent ? AppColors.crimson : AppColors.emeraldDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Spent: ${provider.formatCurrency(metrics.todayDebits)} of ${provider.formatCurrency(metrics.todayDailyAllowanceLimit)} daily quota',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BENTO CARD B: ACTIVE VAULT PROGRESS
  // ===========================================================================
  Widget _buildCardBActiveVault(BuildContext context, SanchayProvider provider) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: uid.isNotEmpty
          ? AuthService.firestoreInstance
              .collection('users')
              .doc(uid)
              .collection('targets')
              .snapshots()
          : null,
      builder: (context, snapshot) {
        String targetTitle = provider.targetName;
        double goalCap = provider.goalCap;
        double currentAccumulation = provider.currentVault;
        int daysLeft = provider.remainingDaysToTarget;

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;
          // Find selected vault or primary or first doc
          QueryDocumentSnapshot<Map<String, dynamic>>? activeDoc;
          if (provider.selectedVaultId != null) {
            activeDoc = docs.where((d) => d.id == provider.selectedVaultId).firstOrNull;
          }
          activeDoc ??= docs.where((d) => (d.data()['isPrimary'] as bool?) == true).firstOrNull;
          activeDoc ??= docs.first;

          final activeData = activeDoc.data();
          targetTitle = (activeData['title'] as String?)?.trim().isNotEmpty == true
              ? activeData['title'] as String
              : provider.targetName;
          goalCap = (activeData['targetCap'] as num?)?.toDouble() ?? provider.goalCap;

          final docAccum = (activeData['currentAccumulation'] as num?)?.toDouble() ?? 0.0;
          final totalVaultAccum = docs.fold<double>(
            0.0,
            (total, d) => total + ((d.data()['currentAccumulation'] as num?)?.toDouble() ?? 0.0),
          );

          if (docAccum > 0) {
            currentAccumulation = docAccum;
          } else if (totalVaultAccum > 0) {
            currentAccumulation = totalVaultAccum;
          } else {
            // Check transactions where type is vault_deposit/transfer
            final txVaultDeposits = provider.transactions
                .where((tx) =>
                    tx.type.toLowerCase() == 'vault_deposit' ||
                    tx.type.toLowerCase() == 'vault_transfer' ||
                    tx.category.toLowerCase().contains('vault'))
                .fold<double>(0.0, (acc, tx) => acc + tx.amount);
            if (txVaultDeposits > 0) {
              currentAccumulation = txVaultDeposits;
            }
          }

          DateTime? deadlineDate;
          final rawDate = activeData['deadline'] ?? activeData['targetDate'];
          if (rawDate is Timestamp) {
            deadlineDate = rawDate.toDate();
          } else if (rawDate is String) {
            deadlineDate = DateTime.tryParse(rawDate);
          }
          if (deadlineDate != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final target = DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day);
            final diff = target.difference(today).inDays;
            daysLeft = diff > 0 ? diff : 0;
          }
        } else {
          // Fallback: check transactions for vault deposits so ledger deposits render immediately
          final txVaultDeposits = provider.transactions
              .where((tx) =>
                  tx.type.toLowerCase() == 'vault_deposit' ||
                  tx.type.toLowerCase() == 'vault_transfer' ||
                  tx.category.toLowerCase().contains('vault'))
              .fold<double>(0.0, (acc, tx) => acc + tx.amount);
          if (currentAccumulation == 0 && txVaultDeposits > 0) {
            currentAccumulation = txVaultDeposits;
          }
        }

        final progress = goalCap <= 0 ? 0.0 : (currentAccumulation / goalCap).clamp(0.0, 1.0);
        final percentage = (progress * 100).round();
        final amountRemaining = (goalCap - currentAccumulation).clamp(0.0, double.infinity);

        return GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(22),
          backgroundColor: Colors.white,
          onTap: () => ConfigureTargetModal.show(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Title & Deadline Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        targetTitle.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // Target Deadline Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                    ),
                    child: Text(
                      '$daysLeft Days Left',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.obsidian,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Balance vs Goal Cap
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT ACCUMULATION',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      PrivacyText(
                        rawText: provider.formatCurrency(currentAccumulation),
                        monetaryValue: currentAccumulation,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.obsidian,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'GOAL TARGET',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.formatCurrency(goalCap),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Clean Minimal Linear Progress Bar
              Container(
                height: 7,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.04, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Progress Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${provider.formatCurrency(currentAccumulation)} of ${provider.formatCurrency(goalCap)} ($percentage% Paced)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${provider.formatCurrency(amountRemaining)} remaining',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // BENTO CARD C: NET CASH LIQUIDITY
  // ===========================================================================
  Widget _buildCardCNetCashLiquidity(BuildContext context, SanchayProvider provider) {
    // Exclude vault_deposit transactions: Outflow Debits strictly sums genuine expenses
    final totalCredits = LedgerService.calculateInflowCredits(provider.allTransactions);
    final totalDebits = LedgerService.calculateOutflowDebits(provider.allTransactions);
    // Net Cash Liquidity = Total Inflow Credits - Actual Expenses
    final netLiquidity = LedgerService.calculateNetCashLiquidity(provider.allTransactions);

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      backgroundColor: Colors.white,
      onTap: () => AddTransactionModal.show(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.obsidian, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'NET CASH LIQUIDITY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Live Firestore',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Net Liquidity Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              PrivacyText(
                rawText: provider.formatCurrency(netLiquidity),
                monetaryValue: netLiquidity,
                isSigned: false,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: netLiquidity >= 0 ? AppColors.obsidian : AppColors.crimson,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                netLiquidity >= 0 ? 'available in hand' : 'net deficit',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: netLiquidity >= 0 ? AppColors.emeraldDark : AppColors.crimson,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Credits vs Debits Micro-Tags Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldFixed.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_downward, size: 14, color: AppColors.emerald),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inflow Credits',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.onSurfaceVariant),
                            ),
                            PrivacyText(
                              rawText: provider.formatCurrency(totalCredits),
                              monetaryValue: totalCredits,
                              style: AppTheme.monoNumeric(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emerald),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.crimsonFixed.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_upward, size: 14, color: AppColors.crimson),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Outflow Debits',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.onSurfaceVariant),
                            ),
                            PrivacyText(
                              rawText: provider.formatCurrency(totalDebits),
                              monetaryValue: totalDebits,
                              style: AppTheme.monoNumeric(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.crimson),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BENTO CARD D: RECENT ACTIVITY CAPSULE (SEGMENTED LEDGER ENGINE)
  // ===========================================================================
  Widget _buildCardDRecentActivity(BuildContext context, SanchayProvider provider) {
    // Tab 1: UPI & Bank Stream (Notification / SMS Auto-Logged)
    final bankAndUpiList = provider.allTransactions.where((tx) =>
        !tx.isVaultDeposit &&
        (tx.type.toLowerCase() == 'expense' ||
            tx.type.toLowerCase() == 'income' ||
            tx.type.toLowerCase() == 'debit' ||
            tx.type.toLowerCase() == 'credit')).toList();

    // Tab 2: Vault Allocations (Goal Deposits)
    final vaultAllocationsList = provider.allTransactions.where((tx) =>
        tx.isVaultDeposit ||
        tx.type.toLowerCase() == 'vault_deposit' ||
        tx.category.toUpperCase() == 'VAULT TRANSFER').toList();

    List<Transaction> activeList;
    if (_dashboardLedgerTab == 0) {
      if (provider.activeFilter == 'debit') {
        activeList = bankAndUpiList.where((t) => t.isDebit).toList();
      } else if (provider.activeFilter == 'credit') {
        activeList = bankAndUpiList.where((t) => t.isCredit).toList();
      } else {
        activeList = bankAndUpiList;
      }
    } else {
      activeList = vaultAllocationsList;
    }

    final topTransactions = activeList.take(4).toList();

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + Full Ledger Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: AppColors.obsidian, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'RECENT ACTIVITY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/ledger'),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.crimson,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.crimson),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // TWO DISTINCT SEGMENT TABS: UPI & BANK STREAM vs. VAULT ALLOCATIONS
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _dashboardLedgerTab = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _dashboardLedgerTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _dashboardLedgerTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_outlined,
                            size: 13,
                            color: _dashboardLedgerTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'UPI & Bank Feed',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: _dashboardLedgerTab == 0 ? FontWeight.w700 : FontWeight.w500,
                              color: _dashboardLedgerTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _dashboardLedgerTab = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _dashboardLedgerTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _dashboardLedgerTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 13,
                            color: _dashboardLedgerTab == 1 ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Vault Savings Journal',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: _dashboardLedgerTab == 1 ? FontWeight.w700 : FontWeight.w500,
                              color: _dashboardLedgerTab == 1 ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sub-Filter Pills for Tab 0 (UPI Stream)
          if (_dashboardLedgerTab == 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Outflow & Inflow',
                  style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.onSurfaceVariant),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      _buildFilterPill(provider, 'all', 'All'),
                      _buildFilterPill(provider, 'debit', 'Expenses'),
                      _buildFilterPill(provider, 'credit', 'Income'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined, size: 14, color: AppColors.emeraldDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Goal deposits & savings accumulations (not counted as expense loss)',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Transaction Items or Empty Capsule
          if (topTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    _dashboardLedgerTab == 0 ? Icons.inbox_outlined : Icons.shield_outlined,
                    size: 28,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dashboardLedgerTab == 0
                        ? 'No transactions logged yet. Inflow/outflow updates automatically upon UPI or bank SMS detection.'
                        : 'No vault allocations recorded yet',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topTransactions.length,
              separatorBuilder: (context, index) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final tx = topTransactions[index];
                final isVault = _dashboardLedgerTab == 1 || tx.isVaultDeposit;

                return InkWell(
                  onTap: () => _showTransactionDetails(context, tx),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isVault
                                ? const Color(0xFFECFDF5)
                                : (tx.isDebit ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isVault ? 'VAULT TRANSFER' : tx.category,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isVault
                                  ? AppColors.emeraldDark
                                  : (tx.isDebit ? AppColors.crimson : AppColors.emeraldDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.obsidian,
                                ),
                              ),
                              Text(
                                _formatTxTimestamp(tx.timestamp),
                                style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        // Clean Amount
                        Text(
                          isVault
                              ? '+${provider.formatCurrency(tx.amount)}'
                              : provider.formatCurrency(tx.amount, isSigned: true, isDebit: tx.isDebit),
                          style: AppTheme.monoNumeric(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isVault
                                ? AppColors.emerald
                                : (tx.isDebit ? AppColors.crimson : AppColors.emerald),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(SanchayProvider provider, String key, String label) {
    final isSelected = provider.activeFilter == key;
    return GestureDetector(
      onTap: () => provider.setFilter(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.obsidian : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ANALYTICS EXPANSION TOGGLE
  // ===========================================================================
  Widget _buildAnalyticsToggleSection(BuildContext context, SanchayProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _TactileBounce(
          onTap: () => AIIntelligenceModal.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: AppColors.emerald),
                const SizedBox(width: 6),
                Text(
                  'AI Intelligence',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.obsidian),
                ),
              ],
            ),
          ),
        ),
        _TactileBounce(
          onTap: () => setState(() => _showAnalyticsCharts = !_showAnalyticsCharts),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Icon(_showAnalyticsCharts ? Icons.keyboard_arrow_up : Icons.bar_chart_rounded, size: 16, color: AppColors.obsidian),
                const SizedBox(width: 6),
                Text(
                  _showAnalyticsCharts ? 'Hide Charts' : 'Deep Analytics',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.obsidian),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTxTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return 'Today, ${DateFormat('HH:mm').format(dt)}';
    return DateFormat('MMM d, HH:mm').format(dt);
  }
}

// =============================================================================
// CIRCULAR GAUGE PAINTER FOR BENTO CARD A
// =============================================================================
class _CircularGaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  const _CircularGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 8.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.fillColor != fillColor;
  }
}

// =============================================================================
// TACTILE BOUNCE ANIMATION WRAPPER
// =============================================================================
class _TactileBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TactileBounce({required this.child, this.onTap});

  @override
  State<_TactileBounce> createState() => _TactileBounceState();
}

class _TactileBounceState extends State<_TactileBounce> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.onTap != null ? _controller.forward() : null,
      onTapUp: (_) {
        if (widget.onTap != null) {
          _controller.reverse();
          widget.onTap!();
        }
      },
      onTapCancel: () => widget.onTap != null ? _controller.reverse() : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// STAGGERED FADE & SLIDE-UP ANIMATION WRAPPER
// =============================================================================
class _StaggeredFadeSlide extends StatefulWidget {
  final Widget child;
  final int index;

  const _StaggeredFadeSlide({required this.child, this.index = 0});

  @override
  State<_StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<_StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
