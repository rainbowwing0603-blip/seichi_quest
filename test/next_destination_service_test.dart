import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:seichi_quest/models/seichi.dart';
import 'package:seichi_quest/services/next_destination_service.dart';

void main() {
  const service = NextDestinationService();

  Position createPosition({
    required double latitude,
    required double longitude,
  }) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  Seichi createSeichi({
    required String id,
    required double latitude,
    required double longitude,
  }) {
    return Seichi(
      id: id,
      placeId: null,
      card: id,
      reading: id,
      name: id,
      latitude: latitude,
      longitude: longitude,
      stampRadiusMeters: 200,
      description: '',
      icon: '📍',
      isActive: true,
    );
  }

  group('NextDestinationService', () {
    test('位置情報がない場合は目的地なし', () {
      final result = service.findNextDestination(
        position: null,
        seichiList: [createSeichi(id: 'a', latitude: 36.0, longitude: 139.0)],
        collectedIds: const <String>{},
      );

      expect(result.seichi, isNull);
      expect(result.distance, isNull);
    });

    test('聖地がない場合は目的地なし', () {
      final result = service.findNextDestination(
        position: createPosition(latitude: 36.0, longitude: 139.0),
        seichiList: const <Seichi>[],
        collectedIds: const <String>{},
      );

      expect(result.seichi, isNull);
      expect(result.distance, isNull);
    });

    test('最寄りの未獲得聖地を選ぶ', () {
      final position = createPosition(latitude: 36.0, longitude: 139.0);

      final result = service.findNextDestination(
        position: position,
        seichiList: [
          createSeichi(id: 'far', latitude: 36.10, longitude: 139.0),
          createSeichi(id: 'near', latitude: 36.01, longitude: 139.0),
        ],
        collectedIds: const <String>{},
      );

      expect(result.seichi?.id, 'near');
      expect(result.distance, isNotNull);
      expect(result.distance!, greaterThan(0));
    });

    test('獲得済み聖地を除外して次に近い未獲得聖地を選ぶ', () {
      final position = createPosition(latitude: 36.0, longitude: 139.0);

      final result = service.findNextDestination(
        position: position,
        seichiList: [
          createSeichi(
            id: 'collected-near',
            latitude: 36.001,
            longitude: 139.0,
          ),
          createSeichi(id: 'uncollected', latitude: 36.02, longitude: 139.0),
        ],
        collectedIds: const {'collected-near'},
      );

      expect(result.seichi?.id, 'uncollected');
      expect(result.distance, isNotNull);
    });

    test('未獲得の手動NEXTは距離に関係なく優先する', () {
      final position = createPosition(latitude: 36.0, longitude: 139.0);

      final result = service.findNextDestination(
        position: position,
        seichiList: [
          createSeichi(id: 'near', latitude: 36.001, longitude: 139.0),
          createSeichi(id: 'manual', latitude: 36.10, longitude: 139.0),
        ],
        collectedIds: const <String>{},
        manualNextSeichiId: 'manual',
      );

      expect(result.seichi?.id, 'manual');
      expect(result.distance, isNotNull);
    });

    test('手動NEXTが獲得済みなら最寄り未獲得へフォールバックする', () {
      final position = createPosition(latitude: 36.0, longitude: 139.0);

      final result = service.findNextDestination(
        position: position,
        seichiList: [
          createSeichi(id: 'manual', latitude: 36.10, longitude: 139.0),
          createSeichi(id: 'nearest', latitude: 36.01, longitude: 139.0),
        ],
        collectedIds: const {'manual'},
        manualNextSeichiId: 'manual',
      );

      expect(result.seichi?.id, 'nearest');
      expect(result.distance, isNotNull);
    });

    test('存在しない手動NEXTなら最寄り未獲得へフォールバックする', () {
      final position = createPosition(latitude: 36.0, longitude: 139.0);

      final result = service.findNextDestination(
        position: position,
        seichiList: [
          createSeichi(id: 'far', latitude: 36.10, longitude: 139.0),
          createSeichi(id: 'nearest', latitude: 36.01, longitude: 139.0),
        ],
        collectedIds: const <String>{},
        manualNextSeichiId: 'missing',
      );

      expect(result.seichi?.id, 'nearest');
      expect(result.distance, isNotNull);
    });

    test('すべて獲得済みなら目的地なし', () {
      final result = service.findNextDestination(
        position: createPosition(latitude: 36.0, longitude: 139.0),
        seichiList: [
          createSeichi(id: 'a', latitude: 36.01, longitude: 139.0),
          createSeichi(id: 'b', latitude: 36.02, longitude: 139.0),
        ],
        collectedIds: const {'a', 'b'},
      );

      expect(result.seichi, isNull);
      expect(result.distance, isNull);
    });
  });
}
