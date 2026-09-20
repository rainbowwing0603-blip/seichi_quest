/// スタンプ獲得に使うGPS品質ルールをUIから分離した純粋ロジック。
///
/// 距離計算そのものは呼び出し側で行い、このクラスは既存の閾値だけを管理する。
/// そのためFlutterや位置情報プラグインなしで単体テストできる。
abstract final class StampEligibilityPolicy {
  static const double maxPlausibleSpeedMps = 100.0;
  static const double minimumAllowedAccuracyMeters = 30.0;
  static const double radiusAccuracyRatio = 0.5;

  static double requiredAccuracyMeters(int stampRadiusMeters) {
    final radiusBased = stampRadiusMeters * radiusAccuracyRatio;
    return radiusBased > minimumAllowedAccuracyMeters
        ? radiusBased
        : minimumAllowedAccuracyMeters;
  }

  static bool hasSufficientAccuracy({
    required double accuracyMeters,
    required int stampRadiusMeters,
  }) {
    return accuracyMeters <= requiredAccuracyMeters(stampRadiusMeters);
  }

  static bool isPlausibleMovement({
    required double movedDistanceMeters,
    required double elapsedSeconds,
  }) {
    if (elapsedSeconds <= 0) {
      return true;
    }

    return movedDistanceMeters / elapsedSeconds <= maxPlausibleSpeedMps;
  }

  static bool isWithinStampRadius({
    required double distanceMeters,
    required int stampRadiusMeters,
  }) {
    return distanceMeters <= stampRadiusMeters;
  }
}
