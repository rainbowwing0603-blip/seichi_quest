import 'dart:async';

class SecondaryRefreshCoordinator {
  const SecondaryRefreshCoordinator();

  Future<void> refreshAfterCollection({
    required Future<void> Function() loadCollectionEventNames,
    required Future<void> Function() loadMyEventRank,
    required Future<void> Function() loadLevelProgress,
  }) async {
    await Future.wait<void>([
      loadCollectionEventNames(),
      loadMyEventRank(),
      loadLevelProgress(),
    ]);
  }

  Future<void> refreshProfileAndRank({
    required Future<void> Function() loadDisplayName,
    required Future<void> Function() loadMyEventRank,
  }) async {
    await Future.wait<void>([
      loadDisplayName(),
      loadMyEventRank(),
    ]);
  }
}
