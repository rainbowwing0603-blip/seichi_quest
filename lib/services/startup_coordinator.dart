class StartupCoordinator {
  const StartupCoordinator();

  Future<void> runCritical({
    required Future<void> Function() ensureCloudUser,
    required Future<void> Function() loadCurrentEvent,
    required Future<void> Function() loadEventAchievements,
    required Future<List<Map<String, dynamic>>> Function() startCollectionSync,
    required Future<void> Function() loadSeichi,
    required Future<void> Function(List<Map<String, dynamic>> rows)
        applyCollectedRows,
    required Future<void> Function() mergeCloudCollectionHistory,
    required Future<void> Function() loadManualNextDestination,
    required Future<void> Function() loadRecommendedRoute,
    required void Function() restoreRecommendedRouteDestination,
  }) async {
    await ensureCloudUser();
    await loadCurrentEvent();
    await loadEventAchievements();

    final pendingCollectedRows = await startCollectionSync();

    await loadSeichi();
    await applyCollectedRows(pendingCollectedRows);
    await mergeCloudCollectionHistory();
    await loadManualNextDestination();
    await loadRecommendedRoute();
    restoreRecommendedRouteDestination();
  }

  Future<void> runDeferred({
    required Future<void> Function() loadDisplayName,
    required Future<void> Function() loadMyEventRank,
    required Future<void> Function() loadLevelProgress,
  }) async {
    await Future.wait<void>([
      loadDisplayName(),
      loadMyEventRank(),
      loadLevelProgress(),
    ]);
  }
}
