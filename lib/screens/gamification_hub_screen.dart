import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/gamification_models.dart';
import '../providers/sanchay_provider.dart';
import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/center_hud_alert.dart';

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

class _GamificationHubScreenState extends State<GamificationHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GamificationService _service = GamificationService();
  String _selectedPersonality = 'calm';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();
    final universeTier = WealthUniverseTier.fromLevel(provider.currentLevel);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discipline Hub & Universe',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Row(
              children: [
                Text(
                  '${universeTier.icon} ${universeTier.worldName}',
                  style: GoogleFonts.jetBrainsMono(
                    color: AppColors.emerald,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '• Level ${provider.currentLevel}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.emerald,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.emerald,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: '🐣 Saving Pet & Streak'),
            Tab(text: '👹 Budget Boss'),
            Tab(text: '🎙️ Finance Roast'),
            Tab(text: '🌌 Universe & Badges'),
          ],
        ),
      ),
      body: AmbientBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPetAndStreakTab(provider),
            _buildBudgetBossTab(provider),
            _buildRoastAndPersonalityTab(provider),
            _buildUniverseAndAchievementsTab(provider),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: SAVING PET & SAVING STREAK
  // ===========================================================================
  Widget _buildPetAndStreakTab(SanchayProvider provider) {
    return StreamBuilder<SavingPet>(
      stream: _service.getPetStream(),
      initialData: const SavingPet(),
      builder: (context, petSnap) {
        final pet = petSnap.data ?? const SavingPet();

        return StreamBuilder<SavingStreak>(
          stream: _service.getStreakStream(),
          initialData: const SavingStreak(),
          builder: (context, streakSnap) {
            final streak = streakSnap.data ?? const SavingStreak();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // 1. Pet Interactive Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                pet.stageName,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF047857),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Text(
                              'Level ${pet.level}',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Big Animated Avatar
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: AppColors.emerald.withOpacity(0.3), width: 3),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            pet.stageAvatar,
                            style: const TextStyle(fontSize: 54),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          '${pet.name} the Companion',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Grows strictly when you save and stay within your safe runway. Never rewards spending.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Progress to next evolution
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Evolution Progress',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '${pet.xp} / ${pet.nextLevelXp} XP',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.emerald,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: pet.progressToNextLevel,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Feed with Discipline action
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.favorite, color: Color(0xFF10B981), size: 18),
                            label: Text(
                              'Feed with Daily Discipline (+50 XP)',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () async {
                              await _service.feedPetWithDiscipline(50);
                              await _service.recordDisciplineCheckin();
                              if (context.mounted) {
                                CenterAlert.show(
                                  context,
                                  message: 'Pet Fed! +50 XP Gained 🐣',
                                  subtitle: 'Discipline streak maintained!',
                                  icon: Icons.auto_awesome,
                                  iconColor: AppColors.emerald,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Saving Streak Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
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
                                const Text('🔥', style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 8),
                                Text(
                                  'Saving Streak',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Next Goal: ${streak.nextMilestone} Days',
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStreakMetric('Current Streak', '${streak.currentStreak} Days', const Color(0xFFD97706)),
                            Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                            _buildStreakMetric('Best Record', '${streak.bestStreak} Days', const Color(0xFF0F172A)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStreakMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: BUDGET BOSS & CHALLENGES
  // ===========================================================================
  Widget _buildBudgetBossTab(SanchayProvider provider) {
    return StreamBuilder<BudgetBoss>(
      stream: _service.getBudgetBossStream(
        maxBudget: 35000.0,
        currentSpent: provider.currentMonthExpense,
      ),
      initialData: BudgetBoss(
        monthKey: 'current',
        maxBudget: 35000.0,
        remainingBudget: (35000.0 - provider.currentMonthExpense).clamp(0.0, 35000.0),
      ),
      builder: (context, bossSnap) {
        final boss = bossSnap.data ?? const BudgetBoss(monthKey: 'current');

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Boss Visualizer Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MONTHLY SPENDING BOSS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF34D399),
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          boss.monthKey,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('👹', style: TextStyle(fontSize: 60)),
                    const SizedBox(height: 8),
                    Text(
                      boss.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      boss.bossStatus,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF34D399),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Boss HP bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Boss HP (Safe Runway Budget)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                        Text(
                          '${(boss.hpPercent * 100).toInt()}% Remaining',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: boss.hpPercent,
                        minHeight: 10,
                        backgroundColor: const Color(0xFF334155),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          boss.hpPercent > 0.4 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'HP depletes as real monthly expenses occur. When your budget survives the 30-day cycle, the boss is vanquished!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Active Money Challenges',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              StreamBuilder<List<MoneyChallenge>>(
                stream: _service.getChallengesStream(),
                initialData: const [],
                builder: (context, challengesSnap) {
                  final challenges = challengesSnap.data ?? [];
                  return Column(
                    children: challenges.map((c) => _buildChallengeTile(c)).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChallengeTile(MoneyChallenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(challenge.icon, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      challenge.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
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
                const SizedBox(height: 3),
                Text(
                  challenge.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: challenge.isJoined ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              foregroundColor: challenge.isJoined ? const Color(0xFF475569) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              await _service.toggleChallenge(challenge.id);
            },
            child: Text(
              challenge.isJoined ? 'Joined' : 'Join',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: WEEKLY ROAST & PERSONALITY MODE
  // ===========================================================================
  Widget _buildRoastAndPersonalityTab(SanchayProvider provider) {
    final roastText = _service.generateWeeklyRoast(
      transactions: provider.transactions,
      personalityMode: _selectedPersonality,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personality Switcher
          Text(
            'Sanchat Financial Tone',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust the personality tone of your weekly entertainment roast and milestone notes. Never changes actual calculations.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              _buildPersonalityChip('🧘 Calm', 'calm'),
              const SizedBox(width: 8),
              _buildPersonalityChip('😎 Friendly', 'friendly'),
              const SizedBox(width: 8),
              _buildPersonalityChip('🔥 Coach', 'coach'),
              const SizedBox(width: 8),
              _buildPersonalityChip('💀 Savage', 'savage'),
            ],
          ),

          const SizedBox(height: 24),

          // The Roast Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🎙️', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          'Weekly Finance Roast',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _selectedPersonality.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    roastText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(
                          'Regenerate',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () {
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.share_outlined, size: 16),
                        label: Text(
                          'Privacy Share',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityChip(String label, String modeKey) {
    final isSelected = _selectedPersonality == modeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPersonality = modeKey);
          _service.setPersonalityMode(modeKey);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 4: 100-LEVEL UNIVERSE & HIDDEN ACHIEVEMENTS
  // ===========================================================================
  Widget _buildUniverseAndAchievementsTab(SanchayProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Universe Roadmap
          Text(
            '100-Level Wealth Universe',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          _buildUniverseWorldCard(1, 10, '🌱 Starter Village', 'Planting initial discipline seeds and establishing on-device tracking.', provider.currentLevel),
          _buildUniverseWorldCard(11, 25, '🏙️ Money City', 'Navigating daily cash flows and active multi-vault allocations.', provider.currentLevel),
          _buildUniverseWorldCard(26, 50, '🏰 Wealth Kingdom', 'Building fortified emergency buffers and multi-month safe runways.', provider.currentLevel),
          _buildUniverseWorldCard(51, 75, '🌌 Finance Galaxy', 'Expanding compounding discipline across long-range target horizons.', provider.currentLevel),
          _buildUniverseWorldCard(76, 99, '🪐 Cosmic Wealth Realm', 'Achieving complete financial calm with zero impulse vulnerability.', provider.currentLevel),
          _buildUniverseWorldCard(100, 100, '👑 Wealth God', 'Permanent mastery over life capital and sovereign financial peace.', provider.currentLevel),

          const SizedBox(height: 24),

          // Hidden Achievements Grid
          Text(
            'Secret Achievements',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<HiddenAchievement>>(
            stream: _service.getAchievementsStream(),
            initialData: const [],
            builder: (context, snap) {
              final list = snap.data ?? [];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final ach = list[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: ach.isUnlocked ? AppColors.emerald.withOpacity(0.4) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(ach.icon, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 6),
                        Text(
                          ach.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ach.isUnlocked ? 'Unlocked 🏆' : 'Locked 🔒',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: ach.isUnlocked ? AppColors.emerald : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUniverseWorldCard(int min, int max, String title, String desc, int userLvl) {
    final isActive = userLvl >= min && userLvl <= max;
    final isPassed = userLvl > max;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.emerald : const Color(0xFFE2E8F0),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'L$min-$max',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF047857) : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (isPassed)
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18)
          else if (isActive)
            const Text('🎯', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
