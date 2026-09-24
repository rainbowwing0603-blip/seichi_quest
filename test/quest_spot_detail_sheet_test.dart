import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/quest_item.dart';
import 'package:seichi_quest/widgets/quest_spot_detail_sheet.dart';

void main() {
  const item = QuestItem(
    id: 'event-content-1',
    eventContentId: 'event-content-1',
    contentId: 'content-1',
    placeId: 'place-1',
    contentKey: 'け',
    title: '群馬県庁本庁舎',
    latitude: 36.391,
    longitude: 139.060,
    radiusMeters: 150,
    description: 'テスト',
    icon: '🏢',
    displayOrder: 1,
    isActive: true,
    contentMetadata: <String, dynamic>{
      'card': 'け',
      'reading': 'け',
    },
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
    expect(find.text('スポットの物語'), findsOneWidget);
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
