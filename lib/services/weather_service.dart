import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/real_world_state.dart';

class WeatherService {
  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  Future<RealWorldState> fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,weather_code,is_day,wind_speed_10m',
        'hourly': 'wind_speed_10m',
        'forecast_hours': '12',
        'wind_speed_unit': 'ms',
        'timezone': 'auto',
      },
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw WeatherServiceException(
        'Weather API returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const WeatherServiceException('Weather API response is invalid.');
    }

    final current = decoded['current'];

    if (current is! Map<String, dynamic>) {
      throw const WeatherServiceException(
        'Weather API current data is missing.',
      );
    }

    final temperatureValue = current['temperature_2m'];
    final weatherCodeValue = current['weather_code'];
    final timeValue = current['time'];

    if (temperatureValue is! num ||
        weatherCodeValue is! num ||
        timeValue is! String) {
      throw const WeatherServiceException(
        'Weather API current data is incomplete.',
      );
    }

    final observedAt = DateTime.tryParse(timeValue);

    if (observedAt == null) {
      throw const WeatherServiceException('Weather API time is invalid.');
    }

    final hourly = decoded['hourly'];
    final hourlyWind = hourly is Map<String, dynamic>
        ? hourly['wind_speed_10m']
        : null;
    final strongWindExpected = (current['wind_speed_10m'] is num &&
            (current['wind_speed_10m'] as num) >= 15) ||
        (hourlyWind is List &&
            hourlyWind.any((value) => value is num && value >= 15));

    return RealWorldState.fromLocalTime(
      observedAt,
      weather: weatherConditionFromWmoCode(weatherCodeValue.toInt()),
      temperatureCelsius: temperatureValue.toDouble(),
      strongWindExpected: strongWindExpected,
      utcOffsetSeconds: decoded['utc_offset_seconds'] is num
          ? (decoded['utc_offset_seconds'] as num).toInt()
          : null,
    );
  }

  static WeatherCondition weatherConditionFromWmoCode(int code) {
    if (code == 0) {
      return WeatherCondition.clear;
    }

    if (code == 1 || code == 2) {
      return WeatherCondition.partlyCloudy;
    }

    if (code == 3) {
      return WeatherCondition.cloudy;
    }

    if (code == 45 || code == 48) {
      return WeatherCondition.fog;
    }

    if (code == 51 ||
        code == 53 ||
        code == 55 ||
        code == 56 ||
        code == 57 ||
        code == 61 ||
        code == 63 ||
        code == 80 ||
        code == 81) {
      return WeatherCondition.rain;
    }

    if (code == 65 || code == 82) {
      return WeatherCondition.heavyRain;
    }

    if (code == 66 || code == 67) {
      return WeatherCondition.rain;
    }

    if (code == 71 ||
        code == 73 ||
        code == 75 ||
        code == 77 ||
        code == 85 ||
        code == 86) {
      return WeatherCondition.snow;
    }

    if (code == 95 || code == 96 || code == 99) {
      return WeatherCondition.thunderstorm;
    }

    return WeatherCondition.unknown;
  }
}

class WeatherServiceException implements Exception {
  final String message;

  const WeatherServiceException(this.message);

  @override
  String toString() => 'WeatherServiceException: $message';
}
