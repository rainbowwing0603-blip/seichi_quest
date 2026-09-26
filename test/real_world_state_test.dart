import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/real_world_state.dart';

void main() {
  test('local time advances without replacing the weather observation', () {
    final observedAt = DateTime(2026, 11, 30, 16, 45);
    final original = RealWorldState.fromLocalTime(
      observedAt,
      weather: WeatherCondition.rain,
      temperatureCelsius: 19,
      strongWindExpected: true,
    );

    final updated = original.atLocalTime(DateTime(2026, 12, 1, 19));

    expect(updated.season, Season.winter);
    expect(updated.dayPhase, DayPhase.night);
    expect(updated.weather, WeatherCondition.rain);
    expect(updated.temperatureCelsius, 19);
    expect(updated.strongWindExpected, isTrue);
    expect(updated.observedAt, observedAt);
  });

  test('weather location time zone determines the displayed phase', () {
    final observedAt = DateTime(2026, 9, 26, 19);
    final state = RealWorldState.fromLocalTime(
      observedAt,
      weather: WeatherCondition.rain,
      utcOffsetSeconds: 9 * 3600,
    );
    final updated = state.atCurrentTime(DateTime.utc(2026, 9, 26, 10, 17));

    expect(updated.dayPhase, DayPhase.night);
    expect(updated.season, Season.autumn);
    expect(updated.observedAt, observedAt);
    expect(updated.utcOffsetSeconds, 9 * 3600);
  });
}
