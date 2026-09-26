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
}
