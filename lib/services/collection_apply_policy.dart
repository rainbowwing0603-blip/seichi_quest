import '../models/achievement.dart';
import '../models/seichi.dart';
import 'achievement_service.dart';

class CollectionApplyPlan {
  const CollectionApplyPlan({
    required this.newlyCollectedSeichi,
    required this.newCollectedIds,
    required this.newlyUnlockedAchievements,
    required this.didCompleteQuest,
  });

  final List<Seichi> newlyCollectedSeichi;
  final Set<String> newCollectedIds;
  final List<Achievement> newlyUnlockedAchievements;
  final bool didCompleteQuest;
}

class CollectionApplyPolicy {
  const CollectionApplyPolicy();

  CollectionApplyPlan plan({
    required String currentEventId,
    required List<Map<String, dynamic>> collectedRows,
    required List<Seichi> seichiList,
    required Set<String> collectedIds,
    required List<Achievement> eventAchievements,
    required AchievementService achievementService,
  }) {
    final previousCollectedCount = _validCollectedCount(
      seichiList: seichiList,
      collectedIds: collectedIds,
    );

    final collectedCards = collectedRows
        .where((row) => row['event_id']?.toString() == currentEventId)
        .map((row) => row['card']?.toString())
        .whereType<String>()
        .where((card) => card.isNotEmpty)
        .toSet();

    final newlyCollectedSeichi = seichiList
        .where(
          (item) =>
              collectedCards.contains(item.card) &&
              !collectedIds.contains(item.id),
        )
        .toList(growable: false);

    final newCollectedIds = <String>{
      ...collectedIds,
      ...newlyCollectedSeichi.map((item) => item.id),
    };

    final newCollectedCount = _validCollectedCount(
      seichiList: seichiList,
      collectedIds: newCollectedIds,
    );

    final previousAchievements = achievementService.getUnlockedAchievements(
      eventAchievements,
      previousCollectedCount,
    );
    final newAchievements = achievementService.getUnlockedAchievements(
      eventAchievements,
      newCollectedCount,
    );

    final newlyUnlockedAchievements = newAchievements
        .where(
          (achievement) => !previousAchievements.any(
            (previous) => previous.id == achievement.id,
          ),
        )
        .toList(growable: false);

    return CollectionApplyPlan(
      newlyCollectedSeichi: newlyCollectedSeichi,
      newCollectedIds: newCollectedIds,
      newlyUnlockedAchievements: newlyUnlockedAchievements,
      didCompleteQuest:
          seichiList.isNotEmpty &&
          previousCollectedCount < seichiList.length &&
          newCollectedCount >= seichiList.length,
    );
  }

  int _validCollectedCount({
    required List<Seichi> seichiList,
    required Set<String> collectedIds,
  }) {
    if (seichiList.isEmpty) {
      return 0;
    }

    final validIds = seichiList.map((seichi) => seichi.id).toSet();
    return collectedIds.where(validIds.contains).length;
  }
}
