import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/widgets/weather_safety_banner.dart';

void main() {
  testWidgets('狭い画面と大きい文字でも案内を読んで詳細を開ける', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.6),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: Align(
              alignment: Alignment.topCenter,
              child: WeatherSafetyBanner(
                message: '強い風が見込まれます。無理な外出は控え、安全を優先してください。',
                onOpenDetails: () => opened = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('強い風'), findsOneWidget);
    await tester.tap(find.text('気象庁の防災情報を確認する'));
    expect(opened, isTrue);
  });
}
