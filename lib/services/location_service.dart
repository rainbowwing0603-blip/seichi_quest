import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationStartFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationStartResult {
  const LocationStartResult._({
    this.position,
    this.failure,
    this.error,
  });

  const LocationStartResult.success(Position position)
      : this._(position: position);

  const LocationStartResult.failed(
    LocationStartFailure failure, {
    Object? error,
  }) : this._(failure: failure, error: error);

  final Position? position;
  final LocationStartFailure? failure;
  final Object? error;

  bool get isSuccess => position != null;
}

/// Geolocatorとの直接通信をMap画面から分離する。
///
/// UI文言、再試行導線、天気更新、スタンプ判定は呼び出し側に残し、
/// このクラスは位置情報サービス・権限・現在地・位置ストリームだけを担当する。
class LocationService {
  const LocationService();

  static const LocationSettings currentPositionSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
  );

  static const LocationSettings streamSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  Future<LocationStartResult> getInitialPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return const LocationStartResult.failed(
          LocationStartFailure.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationStartResult.failed(
          LocationStartFailure.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationStartResult.failed(
          LocationStartFailure.permissionDeniedForever,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: currentPositionSettings,
      );

      return LocationStartResult.success(position);
    } catch (error) {
      return LocationStartResult.failed(
        LocationStartFailure.unavailable,
        error: error,
      );
    }
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: streamSettings,
    );
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
