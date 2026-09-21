import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/seichi.dart';
import 'package:seichi_quest/widgets/quest_spot_detail_sheet.dart';

void main() {
  const item = Seichi(
    id: 'spot-1',
    placeId: 'place-1',
    card: 'け',
    reading: 'け',
    name: '群馬県庁本庁舎',
    latitude: 36.391,
    longitude: 139.060,
    stampRadiusMeters: 150,
    description: 'テスト',
    icon: '🏢',
    isActive: true,
  );

  testWidgets('shared spot detail exposes an explicit close action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuestSpotDetailSheet(item: item, collected: true),
        ),
      ),
    );

    expect(find.byTooltip('閉じる'), findsOneWidget);
    expect(find.text('SPOT DETAIL 2.0'), findsOneWidget);
    expect(find.text('札の物語'), findsOneWidget);
  });

  testWidgets('uncollected detail explains the unlock and can expose NEXT action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestSpotDetailSheet(
            item: item,
            collected: false,
            onSetNextDestination: () {},
          ),
        ),
      ),
    );

    expect(find.text('獲得すると物語が解放'), findsOneWidget);
    expect(find.text('次の目的地にする'), findsOneWidget);
  });
}
