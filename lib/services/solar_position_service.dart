import 'dart:math' as math;

class SolarPosition {
  const SolarPosition({
    required this.azimuthDegrees,
    required this.elevationDegrees,
  });

  final double azimuthDegrees;
  final double elevationDegrees;

  bool get isAboveHorizon => elevationDegrees > 0;
}

/// Lightweight solar-position approximation for visual effects.
///
/// Accuracy is intentionally more than sufficient for choosing the direction
/// and strength of sunlight on the map. No network request is required.
class SolarPositionService {
  const SolarPositionService();

  SolarPosition calculate({
    required DateTime time,
    required double latitude,
    required double longitude,
  }) {
    final utc = time.toUtc();
    final dayOfYear = int.parse(
      '${utc.year}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}',
    );
    final startOfYear = DateTime.utc(utc.year, 1, 1);
    final dayIndex =
        DateTime.utc(utc.year, utc.month, utc.day).difference(startOfYear).inDays + 1;
    final hour = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;

    final gamma =
        2.0 * math.pi / 365.0 * (dayIndex - 1 + (hour - 12.0) / 24.0);
    final equationOfTime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));
    final declination =
        0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final utcMinutes =
        utc.hour * 60.0 + utc.minute + utc.second / 60.0;
    var trueSolarMinutes =
        (utcMinutes + equationOfTime + 4.0 * longitude) % 1440.0;
    if (trueSolarMinutes < 0) trueSolarMinutes += 1440.0;

    var hourAngleDegrees = trueSolarMinutes / 4.0 - 180.0;
    if (hourAngleDegrees < -180.0) hourAngleDegrees += 360.0;

    final latitudeRad = latitude * math.pi / 180.0;
    final hourAngleRad = hourAngleDegrees * math.pi / 180.0;
    final cosZenith = (math.sin(latitudeRad) * math.sin(declination) +
            math.cos(latitudeRad) *
                math.cos(declination) *
                math.cos(hourAngleRad))
        .clamp(-1.0, 1.0);
    final zenith = math.acos(cosZenith);
    final elevation = 90.0 - zenith * 180.0 / math.pi;

    final azimuthRad = math.atan2(
      math.sin(hourAngleRad),
      math.cos(hourAngleRad) * math.sin(latitudeRad) -
          math.tan(declination) * math.cos(latitudeRad),
    );
    final azimuth = (azimuthRad * 180.0 / math.pi + 180.0) % 360.0;

    return SolarPosition(
      azimuthDegrees: azimuth,
      elevationDegrees: elevation,
    );
  }
}
