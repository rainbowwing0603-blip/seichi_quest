enum Season { spring, summer, autumn, winter }

enum DayPhase { morning, daytime, evening, night }

enum WeatherCondition {
  unknown,
  clear,
  partlyCloudy,
  cloudy,
  rain,
  heavyRain,
  snow,
  fog,
  thunderstorm,
}

class RealWorldState {
  final Season season;
  final DayPhase dayPhase;
  final WeatherCondition weather;
  final double? temperatureCelsius;
  final DateTime observedAt;

  const RealWorldState({
    required this.season,
    required this.dayPhase,
    required this.weather,
    required this.temperatureCelsius,
    required this.observedAt,
  });

  factory RealWorldState.fromLocalTime(
    DateTime localTime, {
    WeatherCondition weather = WeatherCondition.unknown,
    double? temperatureCelsius,
  }) {
    return RealWorldState(
      season: seasonFromMonth(localTime.month),
      dayPhase: dayPhaseFromHour(localTime.hour),
      weather: weather,
      temperatureCelsius: temperatureCelsius,
      observedAt: localTime,
    );
  }

  static Season seasonFromMonth(int month) {
    if (month >= 3 && month <= 5) {
      return Season.spring;
    }

    if (month >= 6 && month <= 8) {
      return Season.summer;
    }

    if (month >= 9 && month <= 11) {
      return Season.autumn;
    }

    return Season.winter;
  }

  static DayPhase dayPhaseFromHour(int hour) {
    if (hour >= 5 && hour < 10) {
      return DayPhase.morning;
    }

    if (hour >= 10 && hour < 17) {
      return DayPhase.daytime;
    }

    if (hour >= 17 && hour < 19) {
      return DayPhase.evening;
    }

    return DayPhase.night;
  }
}
