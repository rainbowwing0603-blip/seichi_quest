import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:seichi_quest/services/weather_refresh_policy.dart';

void main() {
  Position position({
    double latitude = 36,
    double longitude = 139,
  }) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  const policy = WeatherRefreshPolicy();
  final now = DateTime(2026, 9, 20, 12);

  group('WeatherRefreshPolicy', () {
    test('force指定なら必ず取得する', () {
      expect(
        policy.shouldFetch(
          force: true,
          now: now,
          lastFetchAt: now,
          lastPosition: position(),
          currentPosition: position(),
          distanceBetween: (_, _) => 0,
        ),
        isTrue,
      );
    });

    test('初回取得なら取得する', () {
      expect(
        policy.shouldFetch(
          force: false,
          now: now,
          lastFetchAt: null,
          lastPosition: null,
          currentPosition: position(),
          distanceBetween: (_, _) => 0,
        ),
        isTrue,
      );
    });

    test('15分経過したら取得する', () {
      expect(
        policy.shouldFetch(
          force: false,
          now: now,
          lastFetchAt: now.subtract(const Duration(minutes: 15)),
          lastPosition: position(),
          currentPosition: position(),
          distanceBetween: (_, _) => 0,
        ),
        isTrue,
      );
    });

    test('5km以上移動したら取得する', () {
      expect(
        policy.shouldFetch(
          force: false,
          now: now,
          lastFetchAt: now.subtract(const Duration(minutes: 1)),
          lastPosition: position(),
          currentPosition: position(),
          distanceBetween: (_, _) => 5000,
        ),
        isTrue,
      );
    });

    test('短時間かつ5km未満なら取得しない', () {
      expect(
        policy.shouldFetch(
          force: false,
          now: now,
          lastFetchAt: now.subtract(const Duration(minutes: 1)),
          lastPosition: position(),
          currentPosition: position(),
          distanceBetween: (_, _) => 4999.9,
        ),
        isFalse,
      );
    });
  });
}
