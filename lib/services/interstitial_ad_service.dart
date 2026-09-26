import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_sdk_service.dart';

class InterstitialAdService {
  InterstitialAdService._();

  static final InterstitialAdService instance = InterstitialAdService._();

  static const Duration _productionStartupGracePeriod = Duration(minutes: 10);
  static const Duration _productionMinimumInterval = Duration(minutes: 30);
  static const Duration _productionStampGracePeriod = Duration(minutes: 5);
  static const Duration _productionMinimumScreenStay = Duration(seconds: 15);

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
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static const String _productionInterstitialAdUnitId =
      'ca-app-pub-1391846841313915/4859337718';

  final DateTime _sessionStartedAt = DateTime.now();

  InterstitialAd? _interstitialAd;
  DateTime? _lastShownAt;
  DateTime? _lastStampCollectedAt;

  bool _isLoading = false;
  bool _isShowing = false;

  bool get hasProductionAdUnitId => true;

  String? get _adUnitId {
    if (kReleaseMode) {
      return _productionInterstitialAdUnitId;
    }

    return _testInterstitialAdUnitId;
  }

  void preload() {
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

  void markStampCollected() {
    _lastStampCollectedAt = DateTime.now();
  }

  bool canShowNow({required Duration screenStay, DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    if (_isShowing || _interstitialAd == null) {
      return false;
    }

    if (screenStay < minimumScreenStay) {
      return false;
    }

    if (currentTime.difference(_sessionStartedAt) < _startupGracePeriod) {
      return false;
    }

    final lastShownAt = _lastShownAt;

    if (lastShownAt != null &&
        currentTime.difference(lastShownAt) < _minimumInterval) {
      return false;
    }

    final lastStampCollectedAt = _lastStampCollectedAt;

    if (lastStampCollectedAt != null &&
        currentTime.difference(lastStampCollectedAt) < _stampGracePeriod) {
      return false;
    }

    return true;
  }

  Future<bool> showIfEligible({required Duration screenStay}) async {
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
