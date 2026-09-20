import 'package:geolocator/geolocator.dart';

class WeatherRefreshPolicy {
  const WeatherRefreshPolicy({
    this.refreshInterval = const Duration(minutes: 15),
    this.refreshDistanceMeters = 5000.0,
  });

  final Duration refreshInterval;
  final double refreshDistanceMeters;

  bool shouldFetch({
    required bool force,
    required DateTime now,
    required DateTime? lastFetchAt,
    required Position? lastPosition,
    required Position currentPosition,
    required double Function(Position from, Position to) distanceBetween,
  }) {
    if (force || lastFetchAt == null || lastPosition == null) {
      return true;
    }

    if (now.difference(lastFetchAt) >= refreshInterval) {
      return true;
    }

    return distanceBetween(lastPosition, currentPosition) >=
        refreshDistanceMeters;
  }
}
