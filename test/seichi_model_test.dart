import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/seichi.dart';

void main() {
  test('generic content identity is parsed without changing legacy fields', () {
    final seichi = Seichi.fromMap({
      'id': 'seichi-1',
      'place_id': 'place-1',
      'content_id': 'content-1',
      'event_content_id': 'event-content-1',
      'card': 'あ',
      'reading': '読み',
      'name': '名称',
      'latitude': 36.0,
      'longitude': 139.0,
      'stamp_radius_meters': 200,
      'description': '説明',
      'icon': '📍',
      'card_image_url': 'https://example.com/card.png',
      'is_active': true,
    });

    expect(seichi.id, 'seichi-1');
    expect(seichi.placeId, 'place-1');
    expect(seichi.contentId, 'content-1');
    expect(seichi.eventContentId, 'event-content-1');
    expect(seichi.card, 'あ');
    expect(seichi.reading, '読み');
  });

  test('generic content identity stays nullable for legacy rows', () {
    final seichi = Seichi.fromMap({
      'id': 'legacy-1',
      'place_id': 'place-1',
      'card': 'い',
      'latitude': 36.0,
      'longitude': 139.0,
      'is_active': true,
    });

    expect(seichi.contentId, isNull);
    expect(seichi.eventContentId, isNull);
  });
}
