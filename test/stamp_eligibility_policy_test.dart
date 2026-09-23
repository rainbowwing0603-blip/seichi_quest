import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/stamp_eligibility_policy.dart';

void main() {
  group('StampEligibilityPolicy', () {
    test('uses half the stamp radius when it is stricter than 30m', () {
      expect(
        StampEligibilityPolicy.requiredAccuracyMeters(200),
        100,
      );
    });

    test('never requires accuracy better than the existing 30m floor', () {
      expect(
        StampEligibilityPolicy.requiredAccuracyMeters(40),
        30,
      );
    });

    test('accepts accuracy exactly on the threshold', () {
      expect(
        StampEligibilityPolicy.hasSufficientAccuracy(
          accuracyMeters: 100,
          stampRadiusMeters: 200,
        ),
        isTrue,
      );
    });

    test('rejects accuracy worse than the threshold', () {
      expect(
        StampEligibilityPolicy.hasSufficientAccuracy(
          accuracyMeters: 100.1,
          stampRadiusMeters: 200,
        ),
        isFalse,
      );
    });

    test('accepts movement exactly at 100m/s', () {
      expect(
        StampEligibilityPolicy.isPlausibleMovement(
          movedDistanceMeters: 1000,
          elapsedSeconds: 10,
        ),
        isTrue,
      );
    });

    test('rejects movement faster than 100m/s', () {
      expect(
        StampEligibilityPolicy.isPlausibleMovement(
          movedDistanceMeters: 1001,
          elapsedSeconds: 10,
        ),
        isFalse,
      );
    });

    test('does not reject timestamps with no positive elapsed time', () {
      expect(
        StampEligibilityPolicy.isPlausibleMovement(
          movedDistanceMeters: 5000,
          elapsedSeconds: 0,
        ),
        isTrue,
      );
    });

    test('stamp radius remains inclusive', () {
      expect(
        StampEligibilityPolicy.isWithinStampRadius(
          distanceMeters: 200,
          stampRadiusMeters: 200,
        ),
        isTrue,
      );
      expect(
        StampEligibilityPolicy.isWithinStampRadius(
          distanceMeters: 200.1,
          stampRadiusMeters: 200,
        ),
        isFalse,
      );
    });
  });
}
