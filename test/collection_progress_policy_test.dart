import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/models/seichi.dart';
import 'package:seichi_quest/services/collection_progress_policy.dart';

void main() {
  const policy = CollectionProgressPolicy();

  Seichi seichi(String id) => Seichi(
        id: id,
        placeId: 'place-$id',
        card: id,
        reading: id,
        name: id,
        latitude: 36,
        longitude: 139,
        stampRadiusMeters: 200,
        description: '',
        icon: '📍',
        isActive: true,
      );

  test('現在の聖地一覧に存在する獲得IDだけを数える', () {
    final count = policy.validCollectedCount(
      seichiList: <Seichi>[seichi('1'), seichi('2')],
      collectedIds: <String>{'1', 'old-event-id'},
    );

    expect(count, 1);
  });

  test('聖地一覧が空なら0件', () {
    final count = policy.validCollectedCount(
      seichiList: <Seichi>[],
      collectedIds: <String>{'1'},
    );

    expect(count, 0);
  });
}
