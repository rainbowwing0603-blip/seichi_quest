import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/location_integrity_policy.dart';
import 'package:seichi_quest/services/stamp_eligibility_policy.dart';

void main() {
  group('LocationIntegrityPolicy', () {
    test('allows normal locations in release-like builds', () {
      expect(
        LocationIntegrityPolicy.shouldRejectMockLocation(
          isMocked: false,
          isDebugBuild: false,
        ),
        isFalse,
      );
    });

    test('rejects mocked locations in release-like builds', () {
      expect(
        LocationIntegrityPolicy.shouldRejectMockLocation(
          isMocked: true,
          isDebugBuild: false,
        ),
        isTrue,
      );
    });

    test('allows mocked locations in debug builds for emulator testing', () {
      expect(
        LocationIntegrityPolicy.shouldRejectMockLocation(
          isMocked: true,
          isDebugBuild: true,
        ),
        isFalse,
      );
    });
  });

  group('implausible movement release behavior', () {
    test('movement threshold is independent from mock-location debug bypass', () {
      expect(
        StampEligibilityPolicy.isPlausibleMovement(
          movedDistanceMeters: 5000,
          elapsedSeconds: 10,
        ),
        isFalse,
      );
    });
  });
}
