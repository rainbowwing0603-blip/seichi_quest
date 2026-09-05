import '../models/achievement.dart';

class AchievementService {
  const AchievementService();

  /// 現在の獲得数から、解除済みの実績を返す。
  List<Achievement> getUnlockedAchievements(
    List<Achievement> achievements,
    int collectedCount,
  ) {
    final count = collectedCount.clamp(0, 44);

    return achievements
        .where((achievement) => count >= achievement.requiredCount)
        .toList(growable: false);
  }

  /// 現在の獲得数から、まだ解除していない次の実績を返す。
  Achievement? getNextAchievement(
    List<Achievement> achievements,
    int collectedCount,
  ) {
    final count = collectedCount.clamp(0, 44);

    for (final achievement in achievements) {
      if (count < achievement.requiredCount) {
        return achievement;
      }
    }

    return null;
  }

  /// 指定した実績の進捗率を0.0～1.0で返す。
  double getProgress(
    Achievement achievement,
    int collectedCount,
  ) {
    final count = collectedCount.clamp(0, achievement.requiredCount);

    if (achievement.requiredCount <= 0) {
      return 1.0;
    }

    return count / achievement.requiredCount;
  }

  /// 指定した実績が解除済みか判定する。
  bool isUnlocked(
    Achievement achievement,
    int collectedCount,
  ) {
    return collectedCount >= achievement.requiredCount;
  }
}