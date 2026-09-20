import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/quest_item.dart';

class QuestItemService {
  QuestItemService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<List<QuestItem>> loadActiveItems(String eventId) async {
    if (eventId.isEmpty) {
      throw Exception('イベントIDが未取得のため、コンテンツを読み込めません。');
    }

    final data = await _client
        .from('event_contents')
        .select(
          'id, event_id, content_id, place_id, display_order, metadata, is_active, '
          'contents!inner(type, content_key, title, description, image_url, metadata, is_active, content_blocks(block_type, role, media_path, display_order, is_active)), '
          'places!inner(name, latitude, longitude, radius_meters, description, icon, image_url, is_active)',
        )
        .eq('event_id', eventId)
        .eq('is_active', true)
        .eq('contents.is_active', true)
        .eq('places.is_active', true)
        .order('display_order');

    return List<Map<String, dynamic>>.from(data)
        .map(_mapRow)
        .where(
          (item) =>
              item.id.isNotEmpty &&
              item.contentId.isNotEmpty &&
              item.placeId.isNotEmpty &&
              item.latitude != 0 &&
              item.longitude != 0,
        )
        .toList(growable: false);
  }

  QuestItem _mapRow(Map<String, dynamic> row) {
    final content = _map(row['contents']);
    final place = _map(row['places']);
    final contentMetadata = _map(content['metadata']);
    final eventContentMetadata = _map(row['metadata']);

    final eventContentId = row['id']?.toString().trim() ?? '';
    final legacySeichiId =
        contentMetadata['legacy_seichi_id']?.toString().trim() ?? '';

    return QuestItem(
      id: legacySeichiId.isNotEmpty ? legacySeichiId : eventContentId,
      eventContentId: eventContentId,
      contentId: row['content_id']?.toString().trim() ?? '',
      placeId: row['place_id']?.toString().trim() ?? '',
      contentKey: content['content_key']?.toString().trim() ?? '',
      title: _firstNonEmpty(
        content['title'],
        place['name'],
      ).isNotEmpty
          ? _firstNonEmpty(content['title'], place['name'])
          : '名称未設定',
      latitude: _toDouble(place['latitude']),
      longitude: _toDouble(place['longitude']),
      radiusMeters: _toInt(place['radius_meters'], fallback: 200),
      description: _firstNonEmpty(
        content['description'],
        place['description'],
      ),
      icon: _firstNonEmptyOr(place['icon'], '📍'),
      primaryImageUrl: _firstActiveImageForRole(
            content['content_blocks'],
            'picture_card',
          ) ??
          _nullableString(content['image_url']) ??
          _nullableString(place['image_url']),
      displayOrder: _toInt(row['display_order'], fallback: 0),
      isActive: row['is_active'] == true &&
          content['is_active'] == true &&
          place['is_active'] == true,
      contentMetadata: contentMetadata,
      eventContentMetadata: eventContentMetadata,
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  String? _firstActiveImageForRole(dynamic rawBlocks, String role) {
    if (rawBlocks is! List) {
      return null;
    }

    final candidates = rawBlocks
        .whereType<Map>()
        .where(
          (block) =>
              block['is_active'] == true &&
              block['block_type']?.toString() == 'image' &&
              block['role']?.toString() == role,
        )
        .toList(growable: false)
      ..sort(
        (a, b) => ((a['display_order'] as num?)?.toInt() ?? 0)
            .compareTo((b['display_order'] as num?)?.toInt() ?? 0),
      );

    for (final block in candidates) {
      final mediaPath = _nullableString(block['media_path']);
      if (mediaPath != null) {
        return mediaPath;
      }
    }

    return null;
  }

  String _firstNonEmpty(
    dynamic first, [
    dynamic second,
  ]) {
    return _nullableString(first) ?? _nullableString(second) ?? '';
  }

  String _firstNonEmptyOr(
    dynamic first,
    String fallback,
  ) {
    return _nullableString(first) ?? fallback;
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
