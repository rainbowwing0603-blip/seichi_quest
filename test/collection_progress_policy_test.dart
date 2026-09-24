import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/models/quest_item.dart';
import 'package:seichi_quest/services/collection_progress_policy.dart';

void main() {
  const policy = CollectionProgressPolicy();

  QuestItem item(String id) => QuestItem(
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
        icon: '📍',
        displayOrder: 0,
      isActive: true,
      );

  test('現在の聖地一覧に存在する獲得IDだけを数える', () {
    final count = policy.validCollectedCount(
      seichiList: <QuestItem>[item('1'), item('2')],
      collectedIds: <String>{'1', 'old-event-id'},
    );

    expect(count, 1);
  });

  test('聖地一覧が空なら0件', () {
    final count = policy.validCollectedCount(
      seichiList: <QuestItem>[],
      collectedIds: <String>{'1'},
    );

    expect(count, 0);
  });
}
