import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/jomo_karuta_order.dart';
import '../models/seichi.dart';

class SeichiService {
  SeichiService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<List<Seichi>> loadActiveSeichi(String eventId) async {
    if (eventId.isEmpty) {
      throw Exception('イベントIDが未取得のため、聖地を読み込めません。');
    }

    final data = await _client
        .from('event_contents')
        .select(
          'id, event_id, content_id, place_id, display_order, metadata, '
          'contents!inner(type, content_key, title, description, image_url, metadata, is_active), '
          'places!inner(name, latitude, longitude, radius_meters, description, icon, image_url, is_active)',
        )
        .eq('event_id', eventId)
        .eq('is_active', true)
        .eq('contents.is_active', true)
        .eq('places.is_active', true)
        .order('display_order');

    final list = List<Map<String, dynamic>>.from(data)
        .map(_mapEventContentToSeichi)
        .map(Seichi.fromMap)
        .where(
          (seichi) =>
              seichi.id.isNotEmpty &&
              seichi.latitude != 0 &&
              seichi.longitude != 0,
        )
        .toList();

    list.sort((a, b) {
      final aOrder = JomoKarutaOrder.indexOf(a.card);
      final bOrder = JomoKarutaOrder.indexOf(b.card);
      final bothKaruta = aOrder < JomoKarutaOrder.cards.length &&
          bOrder < JomoKarutaOrder.cards.length;

      if (bothKaruta) {
        final orderCompare = aOrder.compareTo(bOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
      }

      return a.card.compareTo(b.card);
    });

    return list;
  }

  Map<String, dynamic> _mapEventContentToSeichi(
    Map<String, dynamic> row,
  ) {
    final rawContent = row['contents'];
    final content = rawContent is Map
        ? Map<String, dynamic>.from(rawContent)
        : <String, dynamic>{};

    final rawPlace = row['places'];
    final place = rawPlace is Map
        ? Map<String, dynamic>.from(rawPlace)
        : <String, dynamic>{};

    final rawContentMetadata = content['metadata'];
    final contentMetadata = rawContentMetadata is Map
        ? Map<String, dynamic>.from(rawContentMetadata)
        : <String, dynamic>{};

    final contentKey = content['content_key']?.toString().trim() ?? '';
    final legacySeichiId =
        contentMetadata['legacy_seichi_id']?.toString().trim() ?? '';

    return <String, dynamic>{
      // During the compatibility phase, existing Jomo Karuta content keeps
      // its legacy seichi id so stamp caches and collection UI remain stable.
      // Generic content uses event_content_id as its stable runtime identity.
      'id': legacySeichiId.isNotEmpty ? legacySeichiId : row['id'],
      'place_id': row['place_id'],
      'content_id': row['content_id'],
      'event_content_id': row['id'],
      'card': contentMetadata['card']?.toString().trim().isNotEmpty == true
          ? contentMetadata['card'].toString().trim()
          : contentKey,
      'reading': contentMetadata['reading']?.toString() ?? '',
      'name': content['title']?.toString().trim().isNotEmpty == true
          ? content['title'].toString().trim()
          : place['name'],
      'latitude': place['latitude'],
      'longitude': place['longitude'],
      'stamp_radius_meters': place['radius_meters'],
      'description': content['description'] ?? place['description'],
      'icon': place['icon'] ?? '📍',
      'card_image_url': content['image_url'] ?? place['image_url'],
      'is_active': row['is_active'] == true &&
          content['is_active'] == true &&
          place['is_active'] == true,
    };
  }
}
