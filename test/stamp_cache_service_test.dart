import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seichi_quest/services/stamp_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StampCacheService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('ユーザー・イベント単位で保存と読み込みができる', () async {
      final service = StampCacheService();

      await service.save(
        userId: 'user-a',
        eventId: 'event-a',
        collectedIds: const ['s1', 's2'],
      );

      final loaded = await service.load(
        userId: 'user-a',
        eventId: 'event-a',
      );

      expect(loaded, {'s1', 's2'});
    });

    test('別ユーザー・別イベントのキャッシュを混在させない', () async {
      final service = StampCacheService();

      await service.save(
        userId: 'user-a',
        eventId: 'event-a',
        collectedIds: const ['s1'],
      );
      await service.save(
        userId: 'user-b',
        eventId: 'event-a',
        collectedIds: const ['s2'],
      );

      expect(
        await service.load(userId: 'user-a', eventId: 'event-a'),
        {'s1'},
      );
      expect(
        await service.load(userId: 'user-b', eventId: 'event-a'),
        {'s2'},
      );
      expect(
        await service.load(userId: 'user-a', eventId: 'event-b'),
        isEmpty,
      );
    });

    test('旧イベント別キャッシュをユーザー別キーへ移行する', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'collected_seichi_ids_event-a': <String>['legacy'],
        'collected_seichi_ids_v2_user-a_event-a': <String>['current'],
      });

      final service = StampCacheService();

      final loaded = await service.load(
        userId: 'user-a',
        eventId: 'event-a',
      );

      expect(loaded, {'legacy', 'current'});

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.containsKey('collected_seichi_ids_event-a'),
        isFalse,
      );
    });

    test('旧グローバルキャッシュを現在イベントへ移行する', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'collected_seichi_ids': <String>['legacy-global'],
      });

      final service = StampCacheService();

      final loaded = await service.load(
        userId: 'user-a',
        eventId: 'event-a',
      );

      expect(loaded, {'legacy-global'});

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('collected_seichi_ids'), isFalse);
    });
  });
}
