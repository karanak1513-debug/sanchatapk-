enum PetStage {
  newborn,
  growing,
  smartSaver,
  vaultBeast,
  wealthGuardian,
}

class SavingPet {
  final String name;
  final PetStage stage;
  final int xp;
  final int level;
  final int streakDays;
  final DateTime? lastFedDate;

  const SavingPet({
    this.name = 'Kuber',
    this.stage = PetStage.newborn,
    this.xp = 50,
    this.level = 1,
    this.streakDays = 1,
    this.lastFedDate,
  });

  String get stageName {
    switch (stage) {
      case PetStage.newborn:
        return 'Newborn 🐣';
      case PetStage.growing:
        return 'Growing 🐥';
      case PetStage.smartSaver:
        return 'Smart Saver 🦊';
      case PetStage.vaultBeast:
        return 'Vault Beast 🐲';
      case PetStage.wealthGuardian:
        return 'Wealth Guardian 👑';
    }
  }

  String get stageAvatar {
    switch (stage) {
      case PetStage.newborn:
        return '🐣';
      case PetStage.growing:
        return '🐥';
      case PetStage.smartSaver:
        return '🦊';
      case PetStage.vaultBeast:
        return '🐲';
      case PetStage.wealthGuardian:
        return '👑';
    }
  }

  int get nextLevelXp => level * 200;

  double get progressToNextLevel {
    final needed = nextLevelXp;
    if (needed <= 0) return 1.0;
    return (xp % needed) / needed;
  }

  factory SavingPet.fromMap(Map<String, dynamic> data) {
    PetStage stage = PetStage.newborn;
    final stageStr = data['stage'] as String? ?? 'newborn';
    if (stageStr == 'growing') stage = PetStage.growing;
    if (stageStr == 'smartSaver') stage = PetStage.smartSaver;
    if (stageStr == 'vaultBeast') stage = PetStage.vaultBeast;
    if (stageStr == 'wealthGuardian') stage = PetStage.wealthGuardian;

    return SavingPet(
      name: data['name'] as String? ?? 'Kuber',
      stage: stage,
      xp: data['xp'] as int? ?? 50,
      level: data['level'] as int? ?? 1,
      streakDays: data['streakDays'] as int? ?? 1,
      lastFedDate: data['lastFedDate'] != null
          ? DateTime.tryParse(data['lastFedDate'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'stage': stage.name,
      'xp': xp,
      'level': level,
      'streakDays': streakDays,
      'lastFedDate': lastFedDate?.toIso8601String(),
    };
  }
}

class SavingStreak {
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastCheckinDate;
  final bool isShieldActive;

  const SavingStreak({
    this.currentStreak = 1,
    this.bestStreak = 1,
    this.lastCheckinDate,
    this.isShieldActive = false,
  });

  int get nextMilestone {
    if (currentStreak < 3) return 3;
    if (currentStreak < 7) return 7;
    if (currentStreak < 14) return 14;
    if (currentStreak < 30) return 30;
    return 100;
  }

  factory SavingStreak.fromMap(Map<String, dynamic> data) {
    return SavingStreak(
      currentStreak: data['currentStreak'] as int? ?? 1,
      bestStreak: data['bestStreak'] as int? ?? 1,
      lastCheckinDate: data['lastCheckinDate'] != null
          ? DateTime.tryParse(data['lastCheckinDate'].toString())
          : null,
      isShieldActive: data['isShieldActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lastCheckinDate': lastCheckinDate?.toIso8601String(),
      'isShieldActive': isShieldActive,
    };
  }
}

class BudgetBoss {
  final String monthKey;
  final String name;
  final double maxBudget;
  final double remainingBudget;
  final bool isDefeated;

  const BudgetBoss({
    required this.monthKey,
    this.name = 'The Impulse Golem 👹',
    this.maxBudget = 30000.0,
    this.remainingBudget = 21500.0,
    this.isDefeated = false,
  });

  double get hpPercent {
    if (maxBudget <= 0) return 0.0;
    return (remainingBudget / maxBudget).clamp(0.0, 1.0);
  }

  String get bossStatus {
    if (isDefeated || remainingBudget <= 0) {
      return 'DEFEATED! Budget Safeguarded 🏆';
    }
    if (hpPercent > 0.5) {
      return 'BOSS WEAKENED — Healthy Runway ⚔️';
    }
    return 'BOSS ENRAGED — High Burn Rate ⚠️';
  }

  factory BudgetBoss.fromMap(Map<String, dynamic> data) {
    return BudgetBoss(
      monthKey: data['monthKey'] as String? ?? '2026-10',
      name: data['name'] as String? ?? 'The Impulse Golem 👹',
      maxBudget: (data['maxBudget'] as num?)?.toDouble() ?? 30000.0,
      remainingBudget: (data['remainingBudget'] as num?)?.toDouble() ?? 21500.0,
      isDefeated: data['isDefeated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'monthKey': monthKey,
      'name': name,
      'maxBudget': maxBudget,
      'remainingBudget': remainingBudget,
      'isDefeated': isDefeated,
    };
  }
}

class MoneyChallenge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int targetDays;
  final int currentDays;
  final int rewardXp;
  final bool isJoined;
  final bool isCompleted;

  const MoneyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.targetDays,
    this.currentDays = 0,
    required this.rewardXp,
    this.isJoined = false,
    this.isCompleted = false,
  });

  factory MoneyChallenge.fromMap(Map<String, dynamic> data) {
    return MoneyChallenge(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      icon: data['icon'] as String? ?? '🎯',
      targetDays: data['targetDays'] as int? ?? 7,
      currentDays: data['currentDays'] as int? ?? 0,
      rewardXp: data['rewardXp'] as int? ?? 150,
      isJoined: data['isJoined'] as bool? ?? false,
      isCompleted: data['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'targetDays': targetDays,
      'currentDays': currentDays,
      'rewardXp': rewardXp,
      'isJoined': isJoined,
      'isCompleted': isCompleted,
    };
  }
}

class HiddenAchievement {
  final String id;
  final String title;
  final String icon;
  final String description;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const HiddenAchievement({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  factory HiddenAchievement.fromMap(Map<String, dynamic> data) {
    return HiddenAchievement(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      icon: data['icon'] as String? ?? '🏆',
      description: data['description'] as String? ?? '',
      isUnlocked: data['isUnlocked'] as bool? ?? false,
      unlockedAt: data['unlockedAt'] != null
          ? DateTime.tryParse(data['unlockedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'description': description,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }
}

class WealthUniverseTier {
  final int level;
  final String worldName;
  final String icon;
  final String description;

  const WealthUniverseTier({
    required this.level,
    required this.worldName,
    required this.icon,
    required this.description,
  });

  static WealthUniverseTier fromLevel(int lvl) {
    if (lvl <= 10) {
      return const WealthUniverseTier(
        level: 10,
        worldName: 'Starter Village',
        icon: '🌱',
        description: 'Planting initial discipline seeds and establishing on-device tracking.',
      );
    } else if (lvl <= 25) {
      return const WealthUniverseTier(
        level: 25,
        worldName: 'Money City',
        icon: '🏙️',
        description: 'Navigating daily cash flows and active multi-vault allocations.',
      );
    } else if (lvl <= 50) {
      return const WealthUniverseTier(
        level: 50,
        worldName: 'Wealth Kingdom',
        icon: '🏰',
        description: 'Building fortified emergency buffers and multi-month safe runways.',
      );
    } else if (lvl <= 75) {
      return const WealthUniverseTier(
        level: 75,
        worldName: 'Finance Galaxy',
        icon: '🌌',
        description: 'Expanding compounding discipline across long-range target horizons.',
      );
    } else if (lvl < 100) {
      return const WealthUniverseTier(
        level: 99,
        worldName: 'Cosmic Wealth Realm',
        icon: '🪐',
        description: 'Achieving complete financial calm with zero impulse vulnerability.',
      );
    } else {
      return const WealthUniverseTier(
        level: 100,
        worldName: 'Wealth God',
        icon: '👑',
        description: 'Permanent mastery over life capital and sovereign financial peace.',
      );
    }
  }
}
