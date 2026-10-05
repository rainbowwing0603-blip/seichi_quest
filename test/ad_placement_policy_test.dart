import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/ad_placement_policy.dart';

void main() {
  const policy = AdPlacementPolicy();

  group('AdPlacementPolicy banner', () {
    test('allows current-height map banner', () {
      expect(
        policy.allowsBanner(
          placement: AdPlacement.mapBanner,
          heightDp: 50,
        ),
        isTrue,
      );
    });

    test('rejects banner taller than current 50dp', () {
      expect(
        policy.allowsBanner(
          placement: AdPlacement.mapBanner,
          heightDp: 51,
        ),
        isFalse,
      );
    });
  });

  group('AdPlacementPolicy inline', () {
    test('allows browse-screen inline placement', () {
      expect(
        policy.allowsInline(
          placement: AdPlacement.announcementsInline,
          blockingContexts: const {},
        ),
        isTrue,
      );
    });

    test('blocks inline ad during startup announcement', () {
      expect(
        policy.allowsInline(
          placement: AdPlacement.announcementsInline,
          blockingContexts: const {
            AdBlockingContext.startupAnnouncement,
          },
        ),
        isFalse,
      );
    });
  });

  group('AdPlacementPolicy interstitial', () {
    test('allows only natural exit without blocking context', () {
      expect(
        policy.allowsInterstitial(
          placement: AdPlacement.naturalExitInterstitial,
          blockingContexts: const {},
        ),
        isTrue,
      );
    });

    test('blocks interstitial during stamp collection', () {
      expect(
        policy.allowsInterstitial(
          placement: AdPlacement.naturalExitInterstitial,
          blockingContexts: const {
            AdBlockingContext.stampCollection,
          },
        ),
        isFalse,
      );
    });
  });
  group('production interstitial timing boundaries', () {
    bool eligible({
      Duration screenStay = const Duration(seconds: 10),
      Duration sessionAge = const Duration(minutes: 3),
      Duration? sinceLastShown,
      Duration? sinceLastStamp,
    }) => policy.allowsInterstitialTiming(
      screenStay: screenStay,
      sessionAge: sessionAge,
      sinceLastShown: sinceLastShown,
      sinceLastStamp: sinceLastStamp,
      minimumScreenStay: const Duration(seconds: 10),
      startupGracePeriod: const Duration(minutes: 3),
      minimumInterval: const Duration(minutes: 15),
      stampGracePeriod: const Duration(minutes: 2),
    );

    test('first ad allowed at startup and screen-stay boundaries', () {
      expect(eligible(), isTrue);
      expect(eligible(sessionAge: const Duration(seconds: 179)), isFalse);
      expect(eligible(screenStay: const Duration(seconds: 9)), isFalse);
    });

    test('repeated ads wait 15 minutes independently of session age', () {
      expect(eligible(sinceLastShown: const Duration(seconds: 899)), isFalse);
      expect(eligible(sinceLastShown: const Duration(minutes: 15)), isTrue);
    });

    test('stamp cooldown blocks an otherwise eligible ad', () {
      expect(eligible(sinceLastStamp: const Duration(seconds: 119)), isFalse);
      expect(eligible(sinceLastStamp: const Duration(minutes: 2)), isTrue);
    });

    test('every protected context blocks a natural exit', () {
      for (final context in AdBlockingContext.values) {
        expect(policy.allowsInterstitial(
          placement: AdPlacement.naturalExitInterstitial,
          blockingContexts: {context},
        ), isFalse, reason: context.name);
      }
    });
  });

}
