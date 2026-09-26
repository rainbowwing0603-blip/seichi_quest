import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/real_world_state.dart';
import 'package:seichi_quest/services/weather_safety_policy.dart';

void main() {
  RealWorldState state(WeatherCondition weather, {bool strongWind = false}) =>
      RealWorldState.fromLocalTime(
        DateTime(2026, 9, 26, 12),
        weather: weather,
        strongWindExpected: strongWind,
      );

  test('強風予報を優先して控えめな外出案内を出す', () {
    expect(
      WeatherSafetyPolicy.message(
        state(WeatherCondition.heavyRain, strongWind: true),
      ),
      contains('強い風'),
    );
  });

  test('雷雨・大雨で案内し、通常の雨や晴れでは出さない', () {
    expect(
      WeatherSafetyPolicy.message(state(WeatherCondition.thunderstorm)),
      contains('雷雨'),
    );
    expect(
      WeatherSafetyPolicy.message(state(WeatherCondition.heavyRain)),
      contains('雨が強い'),
    );
    expect(WeatherSafetyPolicy.message(state(WeatherCondition.rain)), isNull);
    expect(WeatherSafetyPolicy.message(state(WeatherCondition.clear)), isNull);
  });

  test('天気を取得できない場合は安全とみなさず確認先を案内する', () {
    expect(
      WeatherSafetyPolicy.message(null, unavailable: true),
      contains('SQ-WEATHER-01'),
    );
  });
}
