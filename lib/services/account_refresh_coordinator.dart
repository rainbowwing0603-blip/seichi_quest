class AccountRefreshCoordinator {
  const AccountRefreshCoordinator();

  Future<void> run({
    required Future<void> Function() ensureCloudUser,
    required Future<void> Function() resetDestinationState,
    required Future<void> Function() loadDisplayName,
    required Future<void> Function() loadEventAchievements,
    required Future<void> Function() startCollectionSync,
    required Future<void> Function() applyPendingRows,
    required Future<void> Function() mergeCloudHistory,
    required Future<void> Function() loadManualNextDestination,
    required Future<void> Function() loadRecommendedRoute,
    required Future<void> Function() loadMyEventRank,
    required Future<void> Function() finish,
  }) async {
    await ensureCloudUser();
    await resetDestinationState();

    final displayNameFuture = loadDisplayName();

    await loadEventAchievements();
    await startCollectionSync();
    await applyPendingRows();
    await mergeCloudHistory();

    await Future.wait<void>([
      displayNameFuture,
      loadManualNextDestination(),
      loadRecommendedRoute(),
      loadMyEventRank(),
    ]);

    await finish();
  }
}
