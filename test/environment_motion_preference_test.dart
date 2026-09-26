import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/real_world_state.dart';
import 'package:seichi_quest/widgets/season_effect_overlay.dart';
import 'package:seichi_quest/widgets/weather_effect_overlay.dart';

void main() {
  testWidgets('season and weather effects respect reduced animation setting',
      (tester) async {
    Widget app({required bool reduceMotion}) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: const Scaffold(
              body: Stack(
                children: [
                  SeasonEffectOverlay(
                    season: Season.spring,
                    dayPhase: DayPhase.daytime,
                    weather: WeatherCondition.clear,
                  ),
                  WeatherEffectOverlay(
                    weather: WeatherCondition.clear,
                    dayPhase: DayPhase.daytime,
                  ),
                ],
              ),
            ),
          ),
        );

    Finder effectsIn(Type type) => find.descendant(
          of: find.byType(type),
          matching: find.byType(CustomPaint),
        );

    await tester.pumpWidget(app(reduceMotion: false));
    expect(effectsIn(SeasonEffectOverlay), findsOneWidget);
    expect(effectsIn(WeatherEffectOverlay), findsOneWidget);

    await tester.pumpWidget(app(reduceMotion: true));
    expect(effectsIn(SeasonEffectOverlay), findsNothing);
    expect(effectsIn(WeatherEffectOverlay), findsNothing);

    await tester.pumpWidget(app(reduceMotion: false));
    expect(effectsIn(SeasonEffectOverlay), findsOneWidget);
    expect(effectsIn(WeatherEffectOverlay), findsOneWidget);
  });
}
