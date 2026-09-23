import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seichi_quest/services/destination_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DestinationPersistenceService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('手動NEXTをユーザー・イベント単位で保存できる', () async {
      final service = DestinationPersistenceService();

      await service.saveManualDestination(
        userId: 'user-a',
        eventId: 'event-a',
        seichiId: 'seichi-1',
      );

      expect(
        await service.loadManualDestination(
          userId: 'user-a',
          eventId: 'event-a',
        ),
        'seichi-1',
      );
      expect(
        await service.loadManualDestination(
          userId: 'user-a',
          eventId: 'event-b',
        ),
        isNull,
      );
    });

    test('空の手動NEXTは保存済み値を削除する', () async {
      final service = DestinationPersistenceService();

      await service.saveManualDestination(
        userId: 'user-a',
        eventId: 'event-a',
        seichiId: 'seichi-1',
      );
      await service.saveManualDestination(
        userId: 'user-a',
        eventId: 'event-a',
      );

      expect(
        await service.loadManualDestination(
          userId: 'user-a',
          eventId: 'event-a',
        ),
        isNull,
      );
    });

    test('おすすめルートの順序を維持して保存できる', () async {
      final service = DestinationPersistenceService();

      await service.saveRecommendedRoute(
        userId: 'user-a',
        eventId: 'event-a',
        seichiIds: const ['s3', 's1', 's2'],
      );

      expect(
        await service.loadRecommendedRoute(
          userId: 'user-a',
          eventId: 'event-a',
        ),
        ['s3', 's1', 's2'],
      );
    });

    test('空ルートは保存済みルートを削除する', () async {
      final service = DestinationPersistenceService();

      await service.saveRecommendedRoute(
        userId: 'user-a',
        eventId: 'event-a',
        seichiIds: const ['s1'],
      );
      await service.saveRecommendedRoute(
        userId: 'user-a',
        eventId: 'event-a',
        seichiIds: const <String>[],
      );

      expect(
        await service.loadRecommendedRoute(
          userId: 'user-a',
          eventId: 'event-a',
        ),
        isNull,
      );
    });
  });
}
