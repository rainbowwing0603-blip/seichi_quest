import '../models/seichi.dart';

class CollectionProgressPolicy {
  const CollectionProgressPolicy();

  int validCollectedCount({
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
