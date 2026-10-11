import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/story_preview_access_policy.dart';

void main() {
  group('StoryPreviewAccessPolicy', () {
    final serverNow = DateTime.utc(2026, 10, 10, 12);

    test('grants exactly one hour from server time', () {
      expect(
        StoryPreviewAccessPolicy.expiresAt(serverNow),
        DateTime.utc(2026, 10, 10, 13),
      );
    });

    test('is active before expiry and expired at the exact boundary', () {
      final expiry = StoryPreviewAccessPolicy.expiresAt(serverNow);

      expect(
        StoryPreviewAccessPolicy.isActive(
          expiresAt: expiry,
          serverNow: serverNow.add(const Duration(minutes: 59)),
        ),
        isTrue,
      );
      expect(
        StoryPreviewAccessPolicy.isActive(
          expiresAt: expiry,
          serverNow: expiry,
        ),
        isFalse,
      );
    });

    test('no expiry is never considered unlocked', () {
      expect(
        StoryPreviewAccessPolicy.isActive(
          expiresAt: null,
          serverNow: serverNow,
        ),
        isFalse,
      );
    });
  });
}
