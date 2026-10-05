enum AdPlacement {
  mapBanner,
  collectionInline,
  rankingInline,
  announcementsInline,
  eventExploreInline,
  naturalExitInterstitial,
}

enum AdBlockingContext {
  startup,
  onboarding,
  startupAnnouncement,
  gpsCriticalFlow,
  nearDestination,
  stampCollection,
  permissionOrErrorDialog,
}

class AdPlacementPolicy {
  const AdPlacementPolicy();

  static const int maximumBannerHeightDp = 50;

  bool allowsBanner({
    required AdPlacement placement,
    required int heightDp,
  }) {
    return placement == AdPlacement.mapBanner &&
        heightDp > 0 &&
        heightDp <= maximumBannerHeightDp;
  }

  bool allowsInline({
    required AdPlacement placement,
    required Set<AdBlockingContext> blockingContexts,
  }) {
    if (blockingContexts.isNotEmpty) {
      return false;
    }

    return placement == AdPlacement.collectionInline ||
        placement == AdPlacement.rankingInline ||
        placement == AdPlacement.announcementsInline ||
        placement == AdPlacement.eventExploreInline;
  }

  bool allowsInterstitialTiming({
    required Duration screenStay,
    required Duration sessionAge,
    required Duration? sinceLastShown,
    required Duration? sinceLastStamp,
    required Duration minimumScreenStay,
    required Duration startupGracePeriod,
    required Duration minimumInterval,
    required Duration stampGracePeriod,
  }) {
    return screenStay >= minimumScreenStay &&
        sessionAge >= startupGracePeriod &&
        (sinceLastShown == null || sinceLastShown >= minimumInterval) &&
        (sinceLastStamp == null || sinceLastStamp >= stampGracePeriod);
  }

  bool allowsInterstitial({
    required AdPlacement placement,
    required Set<AdBlockingContext> blockingContexts,
  }) {
    return placement == AdPlacement.naturalExitInterstitial &&
        blockingContexts.isEmpty;
  }
}
