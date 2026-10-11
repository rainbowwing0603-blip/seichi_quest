import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_sdk_service.dart';
import 'interstitial_ad_service.dart';

/// Shows a user-initiated rewarded ad. A true result means the SDK delivered
/// the reward callback, not merely that the ad was dismissed.
class StoryRewardedAdService {
  StoryRewardedAdService._();

  static final StoryRewardedAdService instance = StoryRewardedAdService._();

  static const String _androidTestAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTestAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  static const String _androidProductionAdUnitId =
      String.fromEnvironment('ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID');
  static const String _iosProductionAdUnitId =
      String.fromEnvironment('ADMOB_IOS_STORY_REWARDED_AD_UNIT_ID');

  String? get _adUnitId {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    if (kReleaseMode) {
      final id = isIOS
          ? _iosProductionAdUnitId
          : _androidProductionAdUnitId;
      return id.trim().isEmpty ? null : id.trim();
    }
    return isIOS ? _iosTestAdUnitId : _androidTestAdUnitId;
  }

  bool get hasProductionAdUnitId => _adUnitId != null;

  Future<bool> showForStoryUnlock({
    required bool Function() canPresent,
  }) async {
    final adUnitId = _adUnitId;
    if (adUnitId == null) return false;

    final adsReady = await AdSdkService.instance.ready;
    if (!adsReady) return false;

    RewardedAd? ad;
    var acquiredInterstitialLock = false;
    var shown = false;

    try {
      final loaded = Completer<RewardedAd>();
      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (value) {
            if (loaded.isCompleted) {
              value.dispose();
            } else {
              loaded.complete(value);
            }
          },
          onAdFailedToLoad: (error) {
            if (!loaded.isCompleted) loaded.completeError(error);
          },
        ),
      );

      try {
        ad = await loaded.future.timeout(const Duration(seconds: 20));
      } on TimeoutException {
        // Dispose a late load instead of presenting it after the user has moved on.
        unawaited(loaded.future.then((value) => value.dispose(), onError: (Object _) {}));
        return false;
      }

      if (!canPresent()) return false;
      acquiredInterstitialLock =
          InterstitialAdService.instance.tryBeginRewardedAd();
      if (!acquiredInterstitialLock) return false;

      final completion = Completer<bool>();
      var rewardEarned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdShowedFullScreenContent: (_) => shown = true,
        onAdDismissedFullScreenContent: (_) {
          if (!completion.isCompleted) completion.complete(rewardEarned);
        },
        onAdFailedToShowFullScreenContent: (_, _) {
          if (!completion.isCompleted) completion.complete(false);
        },
      );

      try {
        ad.show(onUserEarnedReward: (_, _) => rewardEarned = true);
      } catch (_) {
        if (!completion.isCompleted) completion.complete(false);
      }
      return await completion.future;
    } catch (_) {
      return false;
    } finally {
      ad?.dispose();
      if (acquiredInterstitialLock) {
        InterstitialAdService.instance.finishRewardedAd(shown: shown);
      }
    }
  }

}
