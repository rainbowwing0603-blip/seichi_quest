import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_sdk_service.dart';
import '../services/app_logger.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  static const int _maxBannerHeight = 50;

  BannerAd? _bannerAd;
  bool _isLoaded = false;
  double? _lastRequestedWidth;

  // Debug/ProfileではGoogle公式テスト広告、
  // Releaseでは聖地クエスト本番広告を使用する。
  static const String _androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  static const String _androidProductionBannerAdUnitId =
      'ca-app-pub-1391846841313915/2597290432';
  static const String _iosProductionBannerAdUnitId =
      String.fromEnvironment('ADMOB_IOS_BANNER_AD_UNIT_ID');

  static String? get _bannerAdUnitId {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (kReleaseMode) {
      final id = isIOS
          ? _iosProductionBannerAdUnitId
          : _androidProductionBannerAdUnitId;
      return id.isEmpty ? null : id;
    }

    return isIOS ? _iosTestBannerAdUnitId : _androidTestBannerAdUnitId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final availableWidth = MediaQuery.sizeOf(context).width;
    if (availableWidth <= 0) {
      return;
    }

    if (_lastRequestedWidth != null &&
        (_lastRequestedWidth! - availableWidth).abs() < 1) {
      return;
    }

    _lastRequestedWidth = availableWidth;
    _loadBanner(availableWidth);
  }

  Future<void> _loadBanner(double availableWidth) async {
    _disposeCurrentBanner();

    final adsReady = await AdSdkService.instance.ready;
    if (!adsReady || !mounted || _lastRequestedWidth != availableWidth) {
      return;
    }

    final width = availableWidth.floor();
    final adaptiveSize =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);

    if (!mounted || _lastRequestedWidth != availableWidth) {
      return;
    }

    // 現行の50dpバナーより高くなるAdaptive Bannerは採用しない。
    final adSize = adaptiveSize != null &&
            adaptiveSize.height <= _maxBannerHeight
        ? adaptiveSize
        : AdSize.banner;

    appDebugPrint(
      '[ADS] banner size selected: '
      '${adSize.width}x${adSize.height} '
      '(adaptive=${adaptiveSize?.width}x${adaptiveSize?.height})',
    );

    final adUnitId = _bannerAdUnitId;
    if (adUnitId == null) {
      appDebugPrint('[ADS] banner disabled: iOS production ad unit is not configured');
      return;
    }

    final banner = BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || _lastRequestedWidth != availableWidth) {
            ad.dispose();
            return;
          }

          appDebugPrint('[ADS] banner loaded');
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          if (!mounted || _lastRequestedWidth != availableWidth) {
            return;
          }

          appDebugPrint(
            '[ADS] banner failed: code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );

    try {
      banner.load();
    } catch (error) {
      banner.dispose();
      appDebugPrint('[ADS] banner exception: $error');
      if (!mounted || _lastRequestedWidth != availableWidth) {
        return;
      }
      setState(() {
        _bannerAd = null;
        _isLoaded = false;
      });
    }
  }

  void _disposeCurrentBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const screenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');
    if (screenshotMode) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
