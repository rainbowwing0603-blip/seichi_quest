class StartupCriticalResult {
  const StartupCriticalResult({
    required this.pendingCollectedRows,
  });

  final List<Map<String, dynamic>> pendingCollectedRows;
}

class StartupCoordinator {
  const StartupCoordinator();

  Future<StartupCriticalResult> runCritical({
    required Future<void> Function() ensureCloudUser,
    required Future<void> Function() loadCurrentEvent,
    required Future<List<Map<String, dynamic>>> Function() startCollectionSync,
    required Future<void> Function() loadSeichi,
  }) async {
    await ensureCloudUser();
    await loadCurrentEvent();

    final pendingCollectedRows = await startCollectionSync();
    await loadSeichi();

    return StartupCriticalResult(
      pendingCollectedRows: pendingCollectedRows,
    );
  }

  Future<void> runPostRender({
    required List<Map<String, dynamic>> pendingCollectedRows,
    required Future<void> Function() loadEventAchievements,
    required Future<void> Function(List<Map<String, dynamic>> rows)
        applyCollectedRows,
    required Future<void> Function() mergeCloudCollectionHistory,
    required Future<void> Function() loadManualNextDestination,
    required Future<void> Function() loadRecommendedRoute,
    required void Function() restoreRecommendedRouteDestination,
  }) async {
    await applyCollectedRows(pendingCollectedRows);
    await mergeCloudCollectionHistory();
    await loadManualNextDestination();
    await loadRecommendedRoute();
    restoreRecommendedRouteDestination();

    await loadEventAchievements();
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
