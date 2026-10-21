import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/gamification_models.dart';
import '../models/transaction.dart';

class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get _uid {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 1. SAVING PET ( users/{uid}/gamification/pet )
  // ---------------------------------------------------------------------------
  Stream<SavingPet> getPetStream() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(const SavingPet());
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('pet')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return const SavingPet();
      }
      return SavingPet.fromMap(doc.data()!);
    });
  }

  Future<void> feedPetWithDiscipline(int addedXp) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('gamification')
          .doc('pet');
      final snapshot = await docRef.get();
      SavingPet currentPet = const SavingPet();
      if (snapshot.exists && snapshot.data() != null) {
        currentPet = SavingPet.fromMap(snapshot.data()!);
      }

      final newXp = currentPet.xp + addedXp;
      int newLevel = currentPet.level;
      if (newXp >= currentPet.nextLevelXp) {
        newLevel += 1;
      }

      PetStage newStage = currentPet.stage;
      if (newLevel >= 21) {
        newStage = PetStage.wealthGuardian;
      } else if (newLevel >= 11) {
        newStage = PetStage.vaultBeast;
      } else if (newLevel >= 6) {
        newStage = PetStage.smartSaver;
      } else if (newLevel >= 3) {
        newStage = PetStage.growing;
      }

      final updated = SavingPet(
        name: currentPet.name,
        stage: newStage,
        xp: newXp,
        level: newLevel,
        streakDays: currentPet.streakDays + 1,
        lastFedDate: DateTime.now(),
      );

      await docRef.set(updated.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating saving pet: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 2. SAVING STREAK ( users/{uid}/gamification/streak )
  // ---------------------------------------------------------------------------
  Stream<SavingStreak> getStreakStream() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(const SavingStreak());
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('streak')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return const SavingStreak();
      }
      return SavingStreak.fromMap(doc.data()!);
    });
  }

  Future<void> recordDisciplineCheckin() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('gamification')
          .doc('streak');
      final snapshot = await docRef.get();
      int current = 1;
      int best = 1;

      if (snapshot.exists && snapshot.data() != null) {
        final streak = SavingStreak.fromMap(snapshot.data()!);
        current = streak.currentStreak + 1;
        best = current > streak.bestStreak ? current : streak.bestStreak;
      }

      await docRef.set({
        'currentStreak': current,
        'bestStreak': best,
        'lastCheckinDate': DateTime.now().toIso8601String(),
        'isShieldActive': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error recording streak checkin: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 3. BUDGET BOSS ( users/{uid}/gamification/boss )
  // ---------------------------------------------------------------------------
  Stream<BudgetBoss> getBudgetBossStream({double maxBudget = 30000.0, double currentSpent = 8500.0}) {
    final uid = _uid;
    final remaining = (maxBudget - currentSpent).clamp(0.0, maxBudget);
    final monthKey = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

    if (uid == null) {
      return Stream.value(BudgetBoss(
        monthKey: monthKey,
        maxBudget: maxBudget,
        remainingBudget: remaining,
        isDefeated: remaining > 0 && DateTime.now().day >= 28,
      ));
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('boss')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return BudgetBoss(
          monthKey: monthKey,
          maxBudget: maxBudget,
          remainingBudget: remaining,
          isDefeated: remaining > 0 && DateTime.now().day >= 28,
        );
      }
      return BudgetBoss.fromMap(doc.data()!);
    });
  }

  // ---------------------------------------------------------------------------
  // 4. MONEY CHALLENGES ( users/{uid}/gamification/challenges )
  // ---------------------------------------------------------------------------
  Stream<List<MoneyChallenge>> getChallengesStream() {
    final defaultChallenges = [
      const MoneyChallenge(
        id: 'save_500',
        title: 'Save ₹500 Today',
        description: 'Deposit ₹500 into any savings vault before midnight.',
        icon: '💰',
        targetDays: 1,
        currentDays: 0,
        rewardXp: 100,
      ),
      const MoneyChallenge(
        id: 'no_impulse_7',
        title: '7-Day No Impulse Spend',
        description: 'Zero unbudgeted retail or shopping debits for a full week.',
        icon: '🧘',
        targetDays: 7,
        currentDays: 3,
        rewardXp: 350,
      ),
      const MoneyChallenge(
        id: 'under_budget_5',
        title: '5-Day Under Budget',
        description: 'Remain strictly within your safe daily runway for 5 days.',
        icon: '⚡',
        targetDays: 5,
        currentDays: 2,
        rewardXp: 250,
      ),
      const MoneyChallenge(
        id: 'food_discipline_7',
        title: '7-Day Food Discipline',
        description: 'Keep dining & delivery expenses under your allocated daily quota.',
        icon: '🥗',
        targetDays: 7,
        currentDays: 4,
        rewardXp: 300,
      ),
      const MoneyChallenge(
        id: 'vault_boost_1000',
        title: 'Vault Boost Milestone',
        description: 'Allocate a ₹1,000 discipline surplus into the Master Vault.',
        icon: '🚀',
        targetDays: 1,
        currentDays: 0,
        rewardXp: 200,
      ),
    ];

    final uid = _uid;
    if (uid == null) {
      return Stream.value(defaultChallenges);
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('challenges')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return defaultChallenges;
      }
      final rawList = doc.data()!['list'] as List<dynamic>?;
      if (rawList == null || rawList.isEmpty) {
        return defaultChallenges;
      }
      return rawList
          .map((item) => MoneyChallenge.fromMap(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> toggleChallenge(String challengeId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('gamification')
          .doc('challenges');
      final snapshot = await docRef.get();
      List<MoneyChallenge> challenges = [];
      if (snapshot.exists && snapshot.data() != null) {
        final raw = snapshot.data()!['list'] as List<dynamic>?;
        if (raw != null) {
          challenges = raw.map((e) => MoneyChallenge.fromMap(e as Map<String, dynamic>)).toList();
        }
      }
      if (challenges.isEmpty) {
        challenges = [
          const MoneyChallenge(id: 'save_500', title: 'Save ₹500 Today', description: 'Deposit ₹500 into any vault.', icon: '💰', targetDays: 1, rewardXp: 100),
          const MoneyChallenge(id: 'no_impulse_7', title: '7-Day No Impulse Spend', description: 'Zero unbudgeted retail debits.', icon: '🧘', targetDays: 7, rewardXp: 350),
          const MoneyChallenge(id: 'under_budget_5', title: '5-Day Under Budget', description: 'Stay under safe runway for 5 days.', icon: '⚡', targetDays: 5, rewardXp: 250),
        ];
      }

      final updated = challenges.map((c) {
        if (c.id == challengeId) {
          return MoneyChallenge(
            id: c.id,
            title: c.title,
            description: c.description,
            icon: c.icon,
            targetDays: c.targetDays,
            currentDays: c.currentDays,
            rewardXp: c.rewardXp,
            isJoined: !c.isJoined,
            isCompleted: c.isCompleted,
          );
        }
        return c;
      }).toList();

      await docRef.set({'list': updated.map((e) => e.toMap()).toList()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error toggling challenge: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 5. HIDDEN ACHIEVEMENTS ( users/{uid}/gamification/achievements )
  // ---------------------------------------------------------------------------
  Stream<List<HiddenAchievement>> getAchievementsStream() {
    final defaultAchievements = [
      const HiddenAchievement(
        id: 'first_10k',
        title: '💎 First ₹10K',
        icon: '💎',
        description: 'Accumulate ₹10,000 across savings vaults.',
        isUnlocked: true,
      ),
      const HiddenAchievement(
        id: 'streak_30',
        title: '🔥 30-Day Saver',
        icon: '🔥',
        description: 'Maintain 30 consecutive active discipline days.',
        isUnlocked: false,
      ),
      const HiddenAchievement(
        id: 'impulse_master',
        title: '🧘 Impulse Master',
        icon: '🧘',
        description: 'Stay under daily runway quota 10 days in a row.',
        isUnlocked: true,
      ),
      const HiddenAchievement(
        id: 'vault_beast',
        title: '💰 Vault Beast',
        icon: '💰',
        description: 'Reach 50% or higher on Master Reserve Vault.',
        isUnlocked: false,
      ),
      const HiddenAchievement(
        id: 'budget_immortal',
        title: '🗿 Budget Immortal',
        icon: '🗿',
        description: 'Defeat the Monthly Budget Boss.',
        isUnlocked: false,
      ),
      const HiddenAchievement(
        id: 'ghost_shopper',
        title: '👻 Ghost Shopper',
        icon: '👻',
        description: 'Zero discretionary spend for 3 days.',
        isUnlocked: true,
      ),
    ];

    final uid = _uid;
    if (uid == null) {
      return Stream.value(defaultAchievements);
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('achievements')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return defaultAchievements;
      }
      final raw = doc.data()!['list'] as List<dynamic>?;
      if (raw == null || raw.isEmpty) {
        return defaultAchievements;
      }
      return raw.map((e) => HiddenAchievement.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // 6. WEEKLY FINANCE ROAST (GENERATED STRICTLY FROM REAL USER DATA)
  // ---------------------------------------------------------------------------
  String generateWeeklyRoast({
    required List<Transaction> transactions,
    required String personalityMode,
  }) {
    if (transactions.isEmpty) {
      return 'Zero transactions detected this week! Either you are living like an ascetic monk, or you have not synced your bank notifications yet.';
    }

    // Tally real spending per category
    final Map<String, double> categorySpend = {};
    double totalSpent = 0;

    for (final tx in transactions) {
      if (tx.isDebit) {
        final cat = tx.category.trim().isNotEmpty ? tx.category : 'General Expenses';
        categorySpend[cat] = (categorySpend[cat] ?? 0) + tx.amount;
        totalSpent += tx.amount;
      }
    }

    if (totalSpent <= 0) {
      return 'Outstanding discipline this week! Zero net expense outflows recorded in your active ledger.';
    }

    // Find top spending category
    String topCat = 'General';
    double maxCatSpend = 0;
    categorySpend.forEach((cat, amt) {
      if (amt > maxCatSpend) {
        maxCatSpend = amt;
        topCat = cat;
      }
    });

    final formattedTotal = '₹${totalSpent.toStringAsFixed(0)}';
    final formattedTop = '₹${maxCatSpend.toStringAsFixed(0)}';

    switch (personalityMode.toLowerCase()) {
      case 'savage':
        return 'Bro... $formattedTop on $topCat out of $formattedTotal total? Are you personally sponsoring their corporate headquarters? Your Master Vault is crying in the corner right now.';
      case 'coach':
        return 'Listen up: You clocked $formattedTotal this week, with $formattedTop leaking into $topCat. Time to tighten the defense line and channel that surplus back into your emergency cushion!';
      case 'friendly':
        return 'Great tracking this week! You spent $formattedTotal in total, with $formattedTop on $topCat. As long as your daily runway stays green, you are cruising smoothly!';
      case 'calm':
      default:
        return 'Weekly Overview: Total outflow of $formattedTotal, with primary allocation of $formattedTop toward $topCat. Maintaining adherence to your daily quota keeps your long-term runway fully protected.';
    }
  }

  // ---------------------------------------------------------------------------
  // 7. PERSONALITY MODE PERSISTENCE
  // ---------------------------------------------------------------------------
  Future<void> setPersonalityMode(String mode) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('gamification')
          .doc('profile')
          .set({'personalityMode': mode}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving personality mode: $e');
    }
  }

  Stream<String> getPersonalityModeStream() {
    final uid = _uid;
    if (uid == null) return Stream.value('calm');
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('profile')
        .snapshots()
        .map((doc) => doc.data()?['personalityMode'] as String? ?? 'calm');
  }
}
