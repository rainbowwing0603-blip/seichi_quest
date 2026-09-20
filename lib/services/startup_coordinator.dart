class StartupSyncResult {
  const StartupSyncResult({
    required this.pendingCollectedRows,
  });

  final List<Map<String, dynamic>> pendingCollectedRows;
}

class StartupCoordinator {
  const StartupCoordinator();

  Future<StartupSyncResult> run({
    required Future<void> Function() ensureCloudUser,
    required Future<void> Function() loadDisplayName,
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
    required Future<void> Function() loadMyEventRank,
    required Future<void> Function() loadLevelProgress,
  }) async {
    await ensureCloudUser();
    await loadDisplayName();
    await loadCurrentEvent();
    await loadEventAchievements();

    final pendingCollectedRows = await startCollectionSync();

    await loadSeichi();
    await applyCollectedRows(pendingCollectedRows);
    await mergeCloudCollectionHistory();
    await loadManualNextDestination();
    await loadRecommendedRoute();
    restoreRecommendedRouteDestination();
    await loadMyEventRank();
    await loadLevelProgress();

    return StartupSyncResult(
      pendingCollectedRows: pendingCollectedRows,
    );
  }
}
