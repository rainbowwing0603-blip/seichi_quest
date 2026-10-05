import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_sdk_service.dart';
import 'ad_placement_policy.dart';

class InterstitialAdService {
  InterstitialAdService._();

  static final InterstitialAdService instance = InterstitialAdService._();

  static const bool _screenshotMode =
      bool.fromEnvironment('SCREENSHOT_MODE');

  static const Duration _productionStartupGracePeriod = Duration(minutes: 3);
  static const Duration _productionMinimumInterval = Duration(minutes: 15);
  static const Duration _productionStampGracePeriod = Duration(minutes: 2);
  static const Duration _productionMinimumScreenStay = Duration(seconds: 10);

  static const Duration _debugStartupGracePeriod = Duration.zero;
  static const Duration _debugMinimumInterval = Duration(seconds: 30);
  static const Duration _debugStampGracePeriod = Duration.zero;
  static const Duration _debugMinimumScreenStay = Duration(seconds: 5);

  static Duration get _startupGracePeriod =>
      kReleaseMode ? _productionStartupGracePeriod : _debugStartupGracePeriod;

  static Duration get _minimumInterval =>
      kReleaseMode ? _productionMinimumInterval : _debugMinimumInterval;

  static Duration get _stampGracePeriod =>
      kReleaseMode ? _productionStampGracePeriod : _debugStampGracePeriod;

  static Duration get minimumScreenStay =>
      kReleaseMode ? _productionMinimumScreenStay : _debugMinimumScreenStay;

  // Debug/ProfileではGoogle公式テスト広告、
  // Releaseでは聖地クエスト本番広告を使用する。
  static const String _androidTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  static const String _androidProductionInterstitialAdUnitId =
      'ca-app-pub-1391846841313915/4859337718';
  static const String _iosProductionInterstitialAdUnitId =
      String.fromEnvironment('ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID');

  final DateTime _sessionStartedAt = DateTime.now();

  InterstitialAd? _interstitialAd;
  DateTime? _lastShownAt;
  DateTime? _lastStampCollectedAt;

  bool _isLoading = false;
  bool _isShowing = false;

  bool get hasProductionAdUnitId {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    return _iosProductionInterstitialAdUnitId.isNotEmpty;
  }

  String? get _adUnitId {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (kReleaseMode) {
      final id = isIOS
          ? _iosProductionInterstitialAdUnitId
          : _androidProductionInterstitialAdUnitId;
      return id.isEmpty ? null : id;
    }

    return isIOS
        ? _iosTestInterstitialAdUnitId
        : _androidTestInterstitialAdUnitId;
  }

  void preload() {
    if (_screenshotMode) return;
    unawaited(_preloadWhenReady());
  }

  Future<void> _preloadWhenReady() async {
    if (_interstitialAd != null || _isLoading || _isShowing) {
      return;
    }

    final adsReady = await AdSdkService.instance.ready;
    if (!adsReady || _interstitialAd != null || _isLoading || _isShowing) {
      return;
    }

    final adUnitId = _adUnitId;

    if (adUnitId == null) {
      return;
    }

    _isLoading = true;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;

          if (_interstitialAd != null) {
            ad.dispose();
            return;
          }

          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _isLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  bool tryBeginRewardedAd() {
    if (_isShowing) return false;
    _isShowing = true;
    return true;
  }

  void finishRewardedAd({required bool shown}) {
    if (shown) _lastShownAt = DateTime.now();
    _isShowing = false;
  }

  void markStampCollected() {
    _lastStampCollectedAt = DateTime.now();
  }

  bool canShowNow({required Duration screenStay, DateTime? now}) {
    if (_screenshotMode) return false;

    final currentTime = now ?? DateTime.now();

    if (_isShowing || _interstitialAd == null) {
      return false;
    }

    return const AdPlacementPolicy().allowsInterstitialTiming(
      screenStay: screenStay,
      sessionAge: currentTime.difference(_sessionStartedAt),
      sinceLastShown: _lastShownAt == null
          ? null
          : currentTime.difference(_lastShownAt!),
      sinceLastStamp: _lastStampCollectedAt == null
          ? null
          : currentTime.difference(_lastStampCollectedAt!),
      minimumScreenStay: minimumScreenStay,
      startupGracePeriod: _startupGracePeriod,
      minimumInterval: _minimumInterval,
      stampGracePeriod: _stampGracePeriod,
    );
  }

  Future<bool> showIfEligible({
    required Duration screenStay,
    required Set<AdBlockingContext> blockingContexts,
  }) async {
    if (!const AdPlacementPolicy().allowsInterstitial(
      placement: AdPlacement.naturalExitInterstitial,
      blockingContexts: blockingContexts,
    )) {
      return false;
    }
    if (!canShowNow(screenStay: screenStay)) {
      preload();
      return false;
    }

    final ad = _interstitialAd;

    if (ad == null) {
      preload();
      return false;
    }

    _interstitialAd = null;
    _isShowing = true;

    final completion = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _lastShownAt = DateTime.now();
      },
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        _isShowing = false;

        if (!completion.isCompleted) {
          completion.complete(true);
        }

        preload();
      },
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        failedAd.dispose();
        _isShowing = false;

        if (!completion.isCompleted) {
          completion.complete(false);
        }

        preload();
      },
    );

    try {
      ad.show();
    } catch (_) {
      ad.dispose();
      _isShowing = false;

      if (!completion.isCompleted) {
        completion.complete(false);
      }

      preload();
    }

    return completion.future;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
