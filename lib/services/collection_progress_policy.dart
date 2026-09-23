import '../models/quest_destination.dart';

class CollectionProgressPolicy {
  const CollectionProgressPolicy();

  int validCollectedCount<T extends QuestDestination>({
    required Iterable<T> seichiList,
    required Set<String> collectedIds,
  }) {
    if (seichiList.isEmpty) {
      return 0;
    }

    final validIds = seichiList.map((destination) => destination.id).toSet();
    return collectedIds.where(validIds.contains).length;
  }
}
