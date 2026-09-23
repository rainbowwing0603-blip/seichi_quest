import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/9214589741';

  static const String _productionBannerAdUnitId =
      'ca-app-pub-1391846841313915/2597290432';

  static String get _bannerAdUnitId =>
      kReleaseMode
          ? _productionBannerAdUnitId
          : _testBannerAdUnitId;

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

    final width = availableWidth.floor();
    final adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (!mounted || _lastRequestedWidth != availableWidth) {
      return;
    }

    // 現行の50dpバナーより高くなるAdaptive Bannerは採用しない。
    final adSize = adaptiveSize != null &&
            adaptiveSize.height <= _maxBannerHeight
        ? adaptiveSize
        : AdSize.banner;

    debugPrint(
      '[ADS] banner size selected: '
      '${adSize.width}x${adSize.height} '
      '(adaptive=${adaptiveSize?.width}x${adaptiveSize?.height})',
    );

    final banner = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || _lastRequestedWidth != availableWidth) {
            ad.dispose();
            return;
          }

          debugPrint('[ADS] banner loaded');
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

          debugPrint(
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
      debugPrint('[ADS] banner exception: $error');
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
