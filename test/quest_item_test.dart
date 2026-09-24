import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/quest_item.dart';

void main() {
  test('generic quest item does not require karuta-specific fields', () {
    const item = QuestItem(
      id: 'event-content-1',
      eventContentId: 'event-content-1',
      contentId: 'content-1',
      placeId: 'place-1',
      contentKey: 'shop-a',
      title: 'コラボ店舗A',
      latitude: 36.0,
      longitude: 139.0,
      radiusMeters: 200,
      description: '店舗コラボ',
      icon: '📍',
      displayOrder: 1,
      isActive: true,
    );

    expect(item.contentKey, 'shop-a');
    expect(item.legacyCard, isNull);
    expect(item.legacyReading, isNull);
  });

  test('legacy karuta metadata is optional compatibility information', () {
    const item = QuestItem(
      id: 'event-content-1',
      eventContentId: 'event-content-1',
      contentId: 'content-1',
      placeId: 'place-1',
      contentKey: 'あ',
      title: '鬼押出し園',
      latitude: 36.0,
      longitude: 139.0,
      radiusMeters: 200,
      description: '説明',
      icon: '🌋',
      displayOrder: 1,
      isActive: true,
      contentMetadata: {
        'card': 'あ',
        'reading': 'あ',
      },
    );

    expect(item.legacyCard, 'あ');
    expect(item.legacyReading, 'あ');
  });
}
