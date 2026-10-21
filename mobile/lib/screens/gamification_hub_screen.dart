import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/gamification_models.dart';
import '../providers/sanchay_provider.dart';
import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/center_hud_alert.dart';

/// Streamlined, Minimalist Discipline & Universe Screen
/// Clean fintech hierarchy:
/// 1. Level / Current World / Streak
/// 2. Featured Challenge
/// 3. Available Challenges (non-colliding responsive cards)
/// 4. Compact Finance Roast (Calm, Friendly, Coach, Savage)
/// 5. Secondary Systems (Saving Pet, Monthly Budget Boss, Secret Badges)
class GamificationHubScreen extends StatefulWidget {
  const GamificationHubScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const GamificationHubScreen(),
      ),
    );
  }

  @override
  State<GamificationHubScreen> createState() => _GamificationHubScreenState();
}

class _GamificationHubScreenState extends State<GamificationHubScreen> {
  final GamificationService _service = GamificationService();
  String _selectedPersonality = 'calm';
  bool _showAllAchievements = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final universeTier = WealthUniverseTier.fromLevel(provider.currentLevel);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discipline & Universe',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${universeTier.icon} ${universeTier.worldName} • Level ${provider.currentLevel}',
              style: GoogleFonts.jetBrainsMono(
                color: AppColors.emerald,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===============================================================
              // 1. LEVEL / CURRENT WORLD & STREAK
              // ===============================================================
              _buildLevelAndStreakCard(provider, universeTier),
              const SizedBox(height: 20),

              // ===============================================================
              // 2. FEATURED CHALLENGE
              // ===============================================================
              StreamBuilder<List<MoneyChallenge>>(
                stream: _service.getChallengesStream(),
                initialData: const [],
                builder: (context, snapshot) {
                  final challenges = snapshot.data ?? [];
                  if (challenges.isEmpty) return const SizedBox.shrink();

                  final featured = challenges.first;
                  final available = challenges.skip(1).take(4).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Featured Challenge Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'FEATURED CHALLENGE',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 1.0,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 12, color: AppColors.emerald),
                                const SizedBox(width: 4),
                                Text(
                                  'Top Focus',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildFeaturedChallengeCard(featured),
                      const SizedBox(height: 24),

                      // =========================================================
                      // 3. AVAILABLE CHALLENGES (3–5 ITEMS)
                      // =========================================================
                      Text(
                        'AVAILABLE CHALLENGES',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...available.map((c) => _buildChallengeCard(c)),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // ===============================================================
              // 4. COMPACT FINANCE ROAST (OPTIONAL)
              // ===============================================================
              _buildFinanceRoastSection(provider),
              const SizedBox(height: 24),

              // ===============================================================
              // 5. SECONDARY DISCIPLINE PROGRESS
              // ===============================================================
              Text(
                'DISCIPLINE SYSTEMS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              _buildPetCompanionCard(),
              const SizedBox(height: 12),
              _buildBudgetBossCard(provider),
              const SizedBox(height: 12),
              _buildAchievementsSection(provider),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: LEVEL / CURRENT WORLD / STREAK CARD
  // ===========================================================================
  Widget _buildLevelAndStreakCard(SanchayProvider provider, WealthUniverseTier tier) {
    return StreamBuilder<SavingStreak>(
      stream: _service.getStreakStream(),
      initialData: const SavingStreak(),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? const SavingStreak();
        final currentLvl = provider.currentLevel;
        final nextLvlXp = currentLvl * 500;
        final currentXp = (provider.currentSavings * 0.1).toInt().clamp(0, nextLvlXp);
        final progress = nextLvlXp > 0 ? (currentXp / nextLvlXp).clamp(0.0, 1.0) : 0.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: World Name & Streak Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(tier.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        tier.worldName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '${streak.currentStreak}d Streak',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Level & XP Metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level $currentLvl',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  Text(
                    '$currentXp / $nextLvlXp XP',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Smooth XP Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SECTION 2: ONE FEATURED CHALLENGE
  // ===========================================================================
  Widget _buildFeaturedChallengeCard(MoneyChallenge challenge) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.emerald.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(challenge.icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${challenge.rewardXp} XP',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: challenge.isJoined
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
                foregroundColor: challenge.isJoined
                    ? const Color(0xFF475569)
                    : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () async {
                await _service.toggleChallenge(challenge.id);
              },
              child: Text(
                challenge.isJoined ? 'Joined • Active' : 'Join Challenge',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 3: AVAILABLE CHALLENGES (RESPONSIVE NO-COLLISION CARD)
  // ===========================================================================
  Widget _buildChallengeCard(MoneyChallenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 320;

          if (isNarrow) {
            // Stacked layout for very narrow screen
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(challenge.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          challenge.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '+${challenge.rewardXp} XP',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  challenge.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _service.toggleChallenge(challenge.id),
                      child: Text(
                        challenge.isJoined ? 'Joined' : 'Join',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Standard responsive row layout: Icon | Content Column | Join Button
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: Text(challenge.icon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+${challenge.rewardXp} XP',
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: challenge.isJoined
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF0F172A),
                    foregroundColor: challenge.isJoined
                        ? const Color(0xFF475569)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    await _service.toggleChallenge(challenge.id);
                  },
                  child: Text(
                    challenge.isJoined ? 'Joined' : 'Join',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // SECTION 4: COMPACT FINANCE ROAST (OPTIONAL)
  // ===========================================================================
  Widget _buildFinanceRoastSection(SanchayProvider provider) {
    final roastText = _service.generateWeeklyRoast(
      transactions: provider.transactions,
      personalityMode: _selectedPersonality,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Roast (Optional)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Entertainment only',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tone Selector: [Calm] [Friendly] [Coach] [Savage]
          Row(
            children: [
              _buildToneChip('Calm', 'calm'),
              const SizedBox(width: 6),
              _buildToneChip('Friendly', 'friendly'),
              const SizedBox(width: 6),
              _buildToneChip('Coach', 'coach'),
              const SizedBox(width: 6),
              _buildToneChip('Savage', 'savage'),
            ],
          ),
          const SizedBox(height: 12),

          // Compact Roast Text Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              roastText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF334155),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons: Regenerate & Privacy Share
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(
                  'Regenerate',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                onPressed: () => setState(() {}),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.emerald,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.share_outlined, size: 14),
                label: Text(
                  'Privacy Share',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  CenterAlert.show(
                    context,
                    message: 'Privacy Safe Graphic Ready 📸',
                    subtitle: 'Zero bank or UPI account numbers exposed!',
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.emerald,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToneChip(String label, String modeKey) {
    final isSelected = _selectedPersonality == modeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPersonality = modeKey);
          _service.setPersonalityMode(modeKey);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 5A: SAVING PET COMPANION TILE
  // ===========================================================================
  Widget _buildPetCompanionCard() {
    return StreamBuilder<SavingPet>(
      stream: _service.getPetStream(),
      initialData: const SavingPet(),
      builder: (context, snapshot) {
        final pet = snapshot.data ?? const SavingPet();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(pet.stageAvatar, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pet.name} (${pet.stageName})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pet.xp} / ${pet.nextLevelXp} XP • Grows when you save',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: () async {
                    await _service.feedPetWithDiscipline(50);
                    await _service.recordDisciplineCheckin();
                    if (context.mounted) {
                      CenterAlert.show(
                        context,
                        message: 'Pet Fed! +50 XP 🐣',
                        subtitle: 'Discipline streak maintained!',
                        icon: Icons.favorite,
                        iconColor: AppColors.emerald,
                      );
                    }
                  },
                  child: Text(
                    '+50 XP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SECTION 5B: BUDGET BOSS TILE
  // ===========================================================================
  Widget _buildBudgetBossCard(SanchayProvider provider) {
    return StreamBuilder<BudgetBoss>(
      stream: _service.getBudgetBossStream(
        maxBudget: 35000.0,
        currentSpent: provider.currentMonthExpense,
      ),
      initialData: const BudgetBoss(monthKey: 'current'),
      builder: (context, snapshot) {
        final boss = snapshot.data ?? const BudgetBoss(monthKey: 'current');
        final hpInt = (boss.hpPercent * 100).toInt();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('👹', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        boss.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$hpInt% HP',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: boss.hpPercent > 0.4 ? AppColors.emerald : Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: boss.hpPercent,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    boss.hpPercent > 0.4 ? AppColors.emerald : Colors.redAccent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                boss.bossStatus,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SECTION 5C: SECRET ACHIEVEMENTS & UNIVERSE ROADMAP
  // ===========================================================================
  Widget _buildAchievementsSection(SanchayProvider provider) {
    return StreamBuilder<List<HiddenAchievement>>(
      stream: _service.getAchievementsStream(),
      initialData: const [],
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        final unlockedCount = list.where((a) => a.isUnlocked).length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'Achievements',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$unlockedCount of ${list.length} Unlocked',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => setState(() => _showAllAchievements = !_showAllAchievements),
                child: Text(
                  _showAllAchievements ? 'Hide Badges ▲' : 'View Badges & Worlds ▼',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
              if (_showAllAchievements) ...[
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final ach = list[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: ach.isUnlocked ? AppColors.emerald.withOpacity(0.4) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(ach.icon, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  ach.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  ach.isUnlocked ? 'Unlocked' : 'Locked',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    color: ach.isUnlocked ? AppColors.emerald : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
