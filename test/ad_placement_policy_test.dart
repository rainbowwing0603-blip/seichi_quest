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
}
