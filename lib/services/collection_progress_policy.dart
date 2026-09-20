import '../models/quest_destination.dart';

class CollectionProgressPolicy {
  const CollectionProgressPolicy();

  int validCollectedCount<T extends QuestDestination>({
    required Iterable<T> destinations,
    required Set<String> collectedIds,
  }) {
    if (destinations.isEmpty) {
      return 0;
    }

    final validIds = destinations.map((destination) => destination.id).toSet();
    return collectedIds.where(validIds.contains).length;
  }

  int validCollectedCountForLegacy<T extends QuestDestination>({
    required Iterable<T> seichiList,
    required Set<String> collectedIds,
  }) {
    return validCollectedCount(
      destinations: seichiList,
      collectedIds: collectedIds,
    );
  }
}
