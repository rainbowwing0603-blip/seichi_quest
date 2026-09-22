import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  String _debugStatus = '広告: 読み込み開始';

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
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    final banner = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          debugPrint('[ADS] banner loaded');
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _debugStatus = '広告: 読み込み成功';
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          if (!mounted) {
            return;
          }

          debugPrint(
            '[ADS] banner failed: code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
            _debugStatus =
                '広告失敗: code=${error.code}\n'
                '${error.domain}\n'
                '${error.message}';
          });
        },
      ),
    );

    try {
      banner.load();
    } catch (error) {
      banner.dispose();
      debugPrint('[ADS] banner exception: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _bannerAd = null;
        _isLoaded = false;
        _debugStatus = '広告例外: $error';
      });
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      if (kReleaseMode) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.center,
        child: Text(
          _debugStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      );
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}