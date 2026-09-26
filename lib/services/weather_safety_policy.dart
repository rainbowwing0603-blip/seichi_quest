import '../models/real_world_state.dart';

/// 現在の天気・風速予報から外出前の控えめな案内だけを作る。
/// 台風・警報の発表有無は、このデータでは判定しない。
abstract final class WeatherSafetyPolicy {
  static String? message(RealWorldState? state) {
    if (state == null) return null;

    if (state.strongWindExpected) {
      return '強い風が見込まれます。無理な外出は控え、安全を優先してください。';
    }
    if (state.weather == WeatherCondition.thunderstorm) {
      return '雷雨のようです。無理に出かけず、安全な場所でお過ごしください。';
    }
    if (state.weather == WeatherCondition.heavyRain) {
      return '雨が強いようです。外出は無理せず、安全を優先してください。';
    }
    return null;
  }
}
