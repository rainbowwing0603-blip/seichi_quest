import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  static const String _adUnitId =
      'ca-app-pub-3940256099942544/9214589741';

  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    final bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed to load: $error');
        },
      ),
    );

    await bannerAd.load();
  }

  @override
  Widget build(BuildContext context) {
    final bannerAd = _bannerAd;
    if (!_isLoaded || bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: bannerAd.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: bannerAd),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
