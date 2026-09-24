import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/quest_item_mapper.dart';

void main() {
  const mapper = QuestItemMapper();

  test('店舗コラボをかるた固有情報なしでQuestItemへ変換できる', () {
    final item = mapper.fromEventContentRow({
      'id': 'event-content-shop',
      'content_id': 'content-shop',
      'place_id': 'place-shop',
      'display_order': 7,
      'metadata': {'campaign': 'autumn'},
      'is_active': true,
      'contents': {
        'content_key': 'shop-a',
        'title': 'コラボ店舗A',
        'description': '対象商品を販売する店舗です。',
        'image_url': null,
        'metadata': <String, dynamic>{},
        'is_active': true,
        'content_blocks': [
          {
            'block_type': 'image',
            'role': 'hero',
            'media_path': 'https://example.com/hero.jpg',
            'display_order': 10,
            'is_active': true,
          },
        ],
      },
      'places': {
        'name': '店舗A',
        'latitude': 36.25,
        'longitude': 139.10,
        'radius_meters': 150,
        'description': '店舗説明',
        'icon': '🏪',
        'image_url': null,
        'is_active': true,
      },
    });

    expect(item.id, 'event-content-shop');
    expect(item.eventContentId, 'event-content-shop');
    expect(item.contentId, 'content-shop');
    expect(item.placeId, 'place-shop');
    expect(item.contentKey, 'shop-a');
    expect(item.title, 'コラボ店舗A');
    expect(item.radiusMeters, 150);
    expect(item.displayOrder, 7);
    expect(item.legacyCard, isNull);
    expect(item.legacyReading, isNull);
  });

  test('picture_cardがなくても画像なしのQuestItemとして成立する', () {
    final item = mapper.fromEventContentRow({
      'id': 'event-content-no-image',
      'content_id': 'content-no-image',
      'place_id': 'place-no-image',
      'display_order': 1,
      'metadata': <String, dynamic>{},
      'is_active': true,
      'contents': {
        'content_key': 'spot-a',
        'title': '画像なしスポット',
        'description': '',
        'image_url': null,
        'metadata': <String, dynamic>{},
        'is_active': true,
        'content_blocks': const [],
      },
      'places': {
        'name': 'スポットA',
        'latitude': 36.0,
        'longitude': 139.0,
        'radius_meters': 200,
        'description': '',
        'icon': null,
        'image_url': null,
        'is_active': true,
      },
    });

    expect(item.primaryImageUrl, isNull);
    expect(item.icon, '📍');
    expect(item.title, '画像なしスポット');
    expect(item.isActive, isTrue);
  });

  test('上毛かるたではかるた表示情報とpicture_cardを維持する', () {
    final item = mapper.fromEventContentRow({
      'id': 'event-content-karuta',
      'content_id': 'content-karuta',
      'place_id': 'place-karuta',
      'display_order': 3,
      'metadata': <String, dynamic>{},
      'is_active': true,
      'contents': {
        'content_key': 'あ',
        'title': '鬼押出し園',
        'description': '説明',
        'image_url': 'https://example.com/fallback.jpg',
        'metadata': {
          'card': 'あ',
          'reading': 'あさまのいたずら おにのおしだし',
        },
        'is_active': true,
        'content_blocks': [
          {
            'block_type': 'image',
            'role': 'picture_card',
            'media_path': 'https://example.com/card-late.jpg',
            'display_order': 30,
            'is_active': true,
          },
          {
            'block_type': 'image',
            'role': 'picture_card',
            'media_path': 'https://example.com/card-first.jpg',
            'display_order': 10,
            'is_active': true,
          },
        ],
      },
      'places': {
        'name': '鬼押出し園',
        'latitude': 36.45,
        'longitude': 138.53,
        'radius_meters': 200,
        'description': '',
        'icon': '📍',
        'image_url': null,
        'is_active': true,
      },
    });

    expect(item.id, 'event-content-karuta');
    expect(item.eventContentId, 'event-content-karuta');
    expect(item.legacyCard, 'あ');
    expect(item.legacyReading, 'あさまのいたずら おにのおしだし');
    expect(item.primaryImageUrl, 'https://example.com/card-first.jpg');
  });
}
