import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/models/seichi.dart';
import 'package:seichi_quest/services/recommended_route_policy.dart';

void main() {
  Seichi seichi(String id) {
    return Seichi(
      id: id,
      placeId: null,
      card: id,
      reading: id,
      name: id,
      latitude: 36,
      longitude: 139,
      stampRadiusMeters: 200,
      description: '',
      icon: '',
      isActive: true,
    );
  }

  group('RecommendedRoutePolicy', () {
    test('開始時に獲得済み聖地を除外し先頭をNEXTにする', () {
      final result = RecommendedRoutePolicy.start(
        route: [seichi('a'), seichi('b'), seichi('c')],
        collectedIds: {'a'},
      );

      expect(result.route.map((item) => item.id), ['b', 'c']);
      expect(result.manualNextSeichiId, 'b');
    });

    test('開始候補がすべて獲得済みなら空ルートになる', () {
      final result = RecommendedRoutePolicy.start(
        route: [seichi('a')],
        collectedIds: {'a'},
      );

      expect(result.route, isEmpty);
      expect(result.manualNextSeichiId, isNull);
    });

    test('獲得後はルートから獲得済みを除外して次へ進む', () {
      final result = RecommendedRoutePolicy.advanceAfterCollection(
        activeRoute: [seichi('a'), seichi('b'), seichi('c')],
        manualNextSeichiId: 'a',
        collectedIds: {'a'},
        newlyCollectedIds: {'a'},
      );

      expect(result.route.map((item) => item.id), ['b', 'c']);
      expect(result.manualNextSeichiId, 'b');
    });

    test('ルート終了時は獲得した手動NEXTを解除する', () {
      final result = RecommendedRoutePolicy.advanceAfterCollection(
        activeRoute: [seichi('a')],
        manualNextSeichiId: 'a',
        collectedIds: {'a'},
        newlyCollectedIds: {'a'},
      );

      expect(result.route, isEmpty);
      expect(result.manualNextSeichiId, isNull);
    });

    test('ルートなしで別の聖地を獲得しても手動NEXTを維持する', () {
      final result = RecommendedRoutePolicy.advanceAfterCollection(
        activeRoute: const <Seichi>[],
        manualNextSeichiId: 'b',
        collectedIds: {'a'},
        newlyCollectedIds: {'a'},
      );

      expect(result.route, isEmpty);
      expect(result.manualNextSeichiId, 'b');
    });
  });
}
