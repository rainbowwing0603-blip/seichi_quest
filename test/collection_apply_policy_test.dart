import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/models/achievement.dart';
import 'package:seichi_quest/models/seichi.dart';
import 'package:seichi_quest/services/achievement_service.dart';
import 'package:seichi_quest/services/collection_apply_policy.dart';

void main() {
  const policy = CollectionApplyPolicy();
  const achievementService = AchievementService();

  Seichi seichi(String id, String card) => Seichi(
        id: id,
        placeId: 'place-$id',
        card: card,
        reading: card,
        name: '聖地$id',
        latitude: 36,
        longitude: 139,
        stampRadiusMeters: 200,
        description: '',
        icon: '📍',
        isActive: true,
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
    final list = <Seichi>[seichi('1', 'あ'), seichi('2', 'い')];

    final result = policy.plan(
      currentEventId: 'event-a',
      collectedRows: <Map<String, dynamic>>[
        <String, dynamic>{'event_id': 'event-a', 'card': 'あ'},
        <String, dynamic>{'event_id': 'event-b', 'card': 'い'},
      ],
      seichiList: list,
      collectedIds: <String>{},
      eventAchievements: achievements,
      achievementService: achievementService,
    );

    expect(result.newlyCollectedSeichi.map((item) => item.id), <String>['1']);
    expect(result.newCollectedIds, <String>{'1'});
    expect(result.newlyUnlockedAchievements.map((item) => item.id), <String>['first']);
    expect(result.didCompleteQuest, isFalse);
  });

  test('既獲得は再獲得せず最後の札で完全制覇を判定する', () {
    final list = <Seichi>[seichi('1', 'あ'), seichi('2', 'い')];

    final result = policy.plan(
      currentEventId: 'event-a',
      collectedRows: <Map<String, dynamic>>[
        <String, dynamic>{'event_id': 'event-a', 'card': 'あ'},
        <String, dynamic>{'event_id': 'event-a', 'card': 'い'},
      ],
      seichiList: list,
      collectedIds: <String>{'1'},
      eventAchievements: achievements,
      achievementService: achievementService,
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
    final list = <Seichi>[seichi('1', 'あ')];

    final result = policy.plan(
      currentEventId: 'event-a',
      collectedRows: <Map<String, dynamic>>[
        <String, dynamic>{'event_id': 'event-a', 'card': 'い'},
      ],
      seichiList: list,
      collectedIds: <String>{},
      eventAchievements: achievements,
      achievementService: achievementService,
    );

    expect(result.newlyCollectedSeichi, isEmpty);
    expect(result.newCollectedIds, isEmpty);
    expect(result.newlyUnlockedAchievements, isEmpty);
    expect(result.didCompleteQuest, isFalse);
  });
}
