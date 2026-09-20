class EventSwitchCoordinator {
  const EventSwitchCoordinator();

  Future<void> run({
    required Future<void> Function() loadEventAchievements,
    required Future<void> Function() startCollectionSync,
    required Future<void> Function() loadSeichi,
    required Future<void> Function() applyPendingRows,
    required Future<void> Function() mergeCloudHistory,
    required Future<void> Function() loadManualNextDestination,
    required Future<void> Function() loadRecommendedRoute,
    required Future<void> Function() loadMyEventRank,
    required Future<void> Function() activateEvent,
  }) async {
    await loadEventAchievements();
    await startCollectionSync();
    await loadSeichi();
    await applyPendingRows();
    await mergeCloudHistory();

    await Future.wait<void>([
      loadManualNextDestination(),
      loadRecommendedRoute(),
      loadMyEventRank(),
    ]);

    await activateEvent();
  }
}
