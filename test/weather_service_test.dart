import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/real_world_state.dart';
import 'package:seichi_quest/services/weather_service.dart';

void main() {
  group('WeatherService WMO天気コード変換', () {
    test('晴天コードを晴れとして扱う', () {
      expect(
        WeatherService.weatherConditionFromWmoCode(0),
        WeatherCondition.clear,
      );
    });

    test('晴れ時々曇り系コードをpartlyCloudyとして扱う', () {
      expect(
        WeatherService.weatherConditionFromWmoCode(1),
        WeatherCondition.partlyCloudy,
      );
      expect(
        WeatherService.weatherConditionFromWmoCode(2),
        WeatherCondition.partlyCloudy,
      );
    });

    test('曇天コードを曇りとして扱う', () {
      expect(
        WeatherService.weatherConditionFromWmoCode(3),
        WeatherCondition.cloudy,
      );
    });

    test('霧コードを霧として扱う', () {
      expect(
        WeatherService.weatherConditionFromWmoCode(45),
        WeatherCondition.fog,
      );
      expect(
        WeatherService.weatherConditionFromWmoCode(48),
        WeatherCondition.fog,
      );
    });

    test('通常の雨コードを雨として扱う', () {
      for (final code in <int>[51, 53, 55, 56, 57, 61, 63, 66, 67, 80, 81]) {
        expect(
          WeatherService.weatherConditionFromWmoCode(code),
          WeatherCondition.rain,
          reason: 'WMO code $code',
        );
      }
    });

    test('強い雨コードを大雨として扱う', () {
      for (final code in <int>[65, 82]) {
        expect(
          WeatherService.weatherConditionFromWmoCode(code),
          WeatherCondition.heavyRain,
          reason: 'WMO code $code',
        );
      }
    });

    test('雪コードを雪として扱う', () {
      for (final code in <int>[71, 73, 75, 77, 85, 86]) {
        expect(
          WeatherService.weatherConditionFromWmoCode(code),
          WeatherCondition.snow,
          reason: 'WMO code $code',
        );
      }
    });

    test('雷雨コードを雷雨として扱う', () {
      for (final code in <int>[95, 96, 99]) {
        expect(
          WeatherService.weatherConditionFromWmoCode(code),
          WeatherCondition.thunderstorm,
          reason: 'WMO code $code',
        );
      }
    });

    test('未知のコードはunknownとして扱う', () {
      expect(
        WeatherService.weatherConditionFromWmoCode(999),
        WeatherCondition.unknown,
      );
    });
  });
}
