import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/models/achievement.dart';
import 'package:seichi_quest/models/quest_item.dart';
import 'package:seichi_quest/services/collection_apply_policy.dart';

void main() {
  const policy = CollectionApplyPolicy();

  QuestItem seichi(String id, String card) => QuestItem(
        id: id,
        eventContentId: id,
        contentId: 'content-$id',
        placeId: 'place-$id',
        contentKey: card,
        title: '聖地$id',
        latitude: 36,
        longitude: 139,
        radiusMeters: 200,
        description: '',
        icon: '📍',
        displayOrder: int.parse(id),
        isActive: true,
        contentMetadata: <String, dynamic>{
          'card': card,
          'reading': card,
        },
      );

  const achievements = <Achievement>[
    Achievement(
      id: 'first',
      title: '最初',
      description: '',
      icon: '🌱',
      requiredCount: 1,
    ),
    Achievement(
      id: 'complete',
      title: '制覇',
      description: '',
      icon: '👑',
      requiredCount: 2,
    ),
  ];

  test('現在イベントの新規獲得だけを反映する', () {
    final list = <QuestItem>[seichi('1', 'あ'), seichi('2', 'い')];

    final result = policy.plan(
      currentEventId: 'event-a',
      collectedRows: <Map<String, dynamic>>[
        <String, dynamic>{'event_id': 'event-a', 'event_content_id': '1'},
        <String, dynamic>{'event_id': 'event-b', 'event_content_id': '2'},
      ],
      seichiList: list,
      collectedIds: <String>{},
      eventAchievements: achievements,
    );

    expect(result.newlyCollectedSeichi.map((item) => item.id), <String>['1']);
    expect(result.newCollectedIds, <String>{'1'});
    expect(result.newlyUnlockedAchievements.map((item) => item.id), <String>['first']);
    expect(result.didCompleteQuest, isFalse);
  });

  test('既獲得は再獲得せず最後の札で完全制覇を判定する', () {
    final list = <QuestItem>[seichi('1', 'あ'), seichi('2', 'い')];

    final result = policy.plan(
      currentEventId: 'event-a',
      collectedRows: <Map<String, dynamic>>[
        <String, dynamic>{'event_id': 'event-a', 'event_content_id': '1'},
        <String, dynamic>{'event_id': 'event-a', 'event_content_id': '2'},
      ],
      seichiList: list,
      collectedIds: <String>{'1'},
      eventAchievements: achievements,
    );

    expect(result.newlyCollectedSeichi.map((item) => item.id), <String>['2']);
    expect(result.newCollectedIds, <String>{'1', '2'});
    expect(
      result.newlyUnlockedAchievements.map((item) => item.id),
      <String>['complete'],
    );
    expect(result.didCompleteQuest, isTrue);
  });

  test('対象カードがなければ状態を変えない', () {
    final list = <QuestItem>[seichi('1', 'あ')];

    final result = policy.plan(
      currentEventId: 'event-a',
      collectedRows: <Map<String, dynamic>>[
        <String, dynamic>{'event_id': 'event-a', 'event_content_id': '2'},
      ],
      seichiList: list,
      collectedIds: <String>{},
      eventAchievements: achievements,
    );

    expect(result.newlyCollectedSeichi, isEmpty);
    expect(result.newCollectedIds, isEmpty);
    expect(result.newlyUnlockedAchievements, isEmpty);
    expect(result.didCompleteQuest, isFalse);
  });
}
