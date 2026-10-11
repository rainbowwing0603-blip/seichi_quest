import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/interstitial_ad_service.dart';

void main() {
  test('rewarded ad lock blocks overlapping full-screen ads', () {
    final service = InterstitialAdService.instance;
    service.finishRewardedAd(shown: false);

    expect(service.tryBeginRewardedAd(), isTrue);
    expect(service.tryBeginRewardedAd(), isFalse);

    service.finishRewardedAd(shown: false);
    expect(service.tryBeginRewardedAd(), isTrue);
    service.finishRewardedAd(shown: false);
  });
}
