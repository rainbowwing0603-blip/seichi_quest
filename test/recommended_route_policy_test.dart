import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/models/quest_item.dart';
import 'package:seichi_quest/services/recommended_route_policy.dart';

void main() {
  QuestItem item(String id) {
    return QuestItem(
      id: id,
      eventContentId: id,
      contentId: 'content-$id',
      placeId: 'place-$id',
      contentKey: id,
      title: id,
      
      latitude: 36,
      longitude: 139,
      radiusMeters: 200,
      description: '',
      icon: '',
      displayOrder: 0,
      isActive: true,
    );
  }

  group('RecommendedRoutePolicy', () {
    test('開始時に獲得済み聖地を除外し先頭をNEXTにする', () {
      final result = RecommendedRoutePolicy.start(
        route: [item('a'), item('b'), item('c')],
        collectedIds: {'a'},
      );

      expect(result.route.map((item) => item.id), ['b', 'c']);
      expect(result.manualNextSeichiId, 'b');
    });

    test('開始候補がすべて獲得済みなら空ルートになる', () {
      final result = RecommendedRoutePolicy.start(
        route: [item('a')],
        collectedIds: {'a'},
      );

      expect(result.route, isEmpty);
      expect(result.manualNextSeichiId, isNull);
    });

    test('獲得後はルートから獲得済みを除外して次へ進む', () {
      final result = RecommendedRoutePolicy.advanceAfterCollection(
        activeRoute: [item('a'), item('b'), item('c')],
        manualNextSeichiId: 'a',
        collectedIds: {'a'},
        newlyCollectedIds: {'a'},
      );

      expect(result.route.map((item) => item.id), ['b', 'c']);
      expect(result.manualNextSeichiId, 'b');
    });

    test('ルート終了時は獲得した手動NEXTを解除する', () {
      final result = RecommendedRoutePolicy.advanceAfterCollection(
        activeRoute: [item('a')],
        manualNextSeichiId: 'a',
        collectedIds: {'a'},
        newlyCollectedIds: {'a'},
      );

      expect(result.route, isEmpty);
      expect(result.manualNextSeichiId, isNull);
    });

    test('ルートなしで別の聖地を獲得しても手動NEXTを維持する', () {
      final result = RecommendedRoutePolicy.advanceAfterCollection(
        activeRoute: const <QuestItem>[],
        manualNextSeichiId: 'b',
        collectedIds: {'a'},
        newlyCollectedIds: {'a'},
      );

      expect(result.route, isEmpty);
      expect(result.manualNextSeichiId, 'b');
    });
  });
}
