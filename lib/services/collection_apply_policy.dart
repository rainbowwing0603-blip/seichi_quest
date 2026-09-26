import '../models/achievement.dart';
import '../models/quest_item.dart';
import 'achievement_service.dart';

class CollectionApplyPlan {
  const CollectionApplyPlan({
    required this.newlyCollectedSeichi,
    required this.newCollectedIds,
    required this.newlyUnlockedAchievements,
    required this.didCompleteQuest,
  });

  final List<QuestItem> newlyCollectedSeichi;
  final Set<String> newCollectedIds;
  final List<Achievement> newlyUnlockedAchievements;
  final bool didCompleteQuest;
}

class CollectionApplyPolicy {
  const CollectionApplyPolicy({
    this.achievementService = const AchievementService(),
  });

  final AchievementService achievementService;

  CollectionApplyPlan plan({
    required String currentEventId,
    required List<Map<String, dynamic>> collectedRows,
    required List<QuestItem> resolvedItems,
    required Set<String> collectedIds,
    required int previousCollectedCount,
    required int totalCount,
    required List<Achievement> eventAchievements,
  }) {
    final collectedEventContentIds = collectedRows
        .where((row) => row['event_id']?.toString() == currentEventId)
        .map((row) => row['event_content_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final newlyCollectedSeichi = resolvedItems
        .where(
          (item) =>
              collectedEventContentIds.contains(item.id) &&
              !collectedIds.contains(item.id),
        )
        .toList(growable: false);

    final newCollectedIds = <String>{
      ...collectedIds,
      ...newlyCollectedSeichi.map((item) => item.id),
    };

    final newCollectedCount =
        previousCollectedCount + newlyCollectedSeichi.length;

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
          totalCount > 0 &&
          previousCollectedCount < totalCount &&
          newCollectedCount >= totalCount,
    );
  }
}
