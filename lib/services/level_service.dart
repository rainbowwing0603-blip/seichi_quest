class LevelProgress {
  const LevelProgress({
    required this.totalXp,
    required this.level,
    required this.currentLevelXp,
    required this.nextLevelXp,
    required this.xpIntoLevel,
    required this.xpNeededForNextLevel,
    required this.progress,
  });

  final int totalXp;
  final int level;

  /// 現在のレベルに到達するために必要な累計XP。
  final int currentLevelXp;

  /// 次のレベルに到達するために必要な累計XP。
  final int nextLevelXp;

  /// 現在のレベルに到達してから獲得したXP。
  final int xpIntoLevel;

  /// 現在のレベルから次のレベルまでに必要なXP。
  final int xpNeededForNextLevel;

  /// 次のレベルまでの進捗率。0.0～1.0。
  final double progress;
}

class LevelService {
  const LevelService();

  /// 聖地1か所を初回獲得したときに付与するXP。
  static const int xpPerCollection = 100;

  /// Lv.1からLv.2になるために必要なXP。
  static const int firstLevelUpXp = 300;

  /// レベルが1上がるごとに増える必要XP。
  static const int levelUpXpIncrement = 100;

  int xpFromCollectedCount(int collectedCount) {
    if (collectedCount <= 0) {
      return 0;
    }

    return collectedCount * xpPerCollection;
  }

  int xpRequiredForLevel(int level) {
    if (level <= 1) {
      return 0;
    }

    final levelUps = level - 1;

    return levelUps * firstLevelUpXp +
        (levelUps * (levelUps - 1) ~/ 2) * levelUpXpIncrement;
  }

  int levelFromXp(int totalXp) {
    if (totalXp <= 0) {
      return 1;
    }

    var level = 1;

    while (totalXp >= xpRequiredForLevel(level + 1)) {
      level++;
    }

    return level;
  }

  LevelProgress progressFromXp(int totalXp) {
    final safeXp = totalXp < 0 ? 0 : totalXp;
    final level = levelFromXp(safeXp);

    final currentLevelXp = xpRequiredForLevel(level);
    final nextLevelXp = xpRequiredForLevel(level + 1);

    final xpIntoLevel = safeXp - currentLevelXp;
    final xpNeededForNextLevel = nextLevelXp - currentLevelXp;

    final progress = xpNeededForNextLevel <= 0
        ? 0.0
        : (xpIntoLevel / xpNeededForNextLevel).clamp(0.0, 1.0);

    return LevelProgress(
      totalXp: safeXp,
      level: level,
      currentLevelXp: currentLevelXp,
      nextLevelXp: nextLevelXp,
      xpIntoLevel: xpIntoLevel,
      xpNeededForNextLevel: xpNeededForNextLevel,
      progress: progress,
    );
  }
}
