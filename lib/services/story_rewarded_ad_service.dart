import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_sdk_service.dart';
import 'interstitial_ad_service.dart';

class StoryRewardedAdService {
  static final instance = StoryRewardedAdService();
  static const _androidId = String.fromEnvironment('ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID');
  static const _iosId = String.fromEnvironment('ADMOB_IOS_STORY_REWARDED_AD_UNIT_ID');
  static const _screenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

  String? get adUnitId {
    if (_screenshotMode || kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
         defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!kReleaseMode) {
      return ios ? 'ca-app-pub-3940256099942544/1712485313'
                 : 'ca-app-pub-3940256099942544/5224354917';
    }
    final id = ios ? _iosId : _androidId;
    return id.isEmpty ? null : id;
  }

  bool _busy = false;
  bool get available => adUnitId != null;

  Future<bool> show({required bool Function() canPresent}) async {
    final id = adUnitId;
    if (_busy || id == null) return false;
    _busy = true;
    RewardedAd? ad;
    var acquired = false;
    var shown = false;
    try {
      if (!await AdSdkService.instance.ready.timeout(const Duration(seconds: 20))) return false;
      final loaded = Completer<RewardedAd>();
      RewardedAd.load(
        adUnitId: id,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (value) {
            if (loaded.isCompleted) { value.dispose(); } else { loaded.complete(value); }
          },
          onAdFailedToLoad: (error) {
            if (!loaded.isCompleted) loaded.completeError(error);
          },
        ),
      );
      try {
        ad = await loaded.future.timeout(const Duration(seconds: 20));
      } on TimeoutException {
        // Dispose a late load rather than leaking an ad or presenting unexpectedly.
        unawaited(loaded.future.then((value) => value.dispose(), onError: (Object _) {}));
        return false;
      }
      if (!canPresent()) return false;
      acquired = InterstitialAdService.instance.tryBeginRewardedAd();
      if (!acquired) return false;
      final completed = Completer<bool>();
      var earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) { shown = true; },
        onAdDismissedFullScreenContent: (_) {
          if (!completed.isCompleted) completed.complete(earned);
        },
        onAdFailedToShowFullScreenContent: (_, _) {
          if (!completed.isCompleted) completed.complete(false);
        },
      );
      ad.show(onUserEarnedReward: (_, _) { earned = true; });
      return await completed.future;
    } catch (_) {
      return false;
    } finally {
      ad?.dispose();
      if (acquired) InterstitialAdService.instance.finishRewardedAd(shown: shown);
      _busy = false;
    }
  }
}
