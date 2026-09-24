import '../models/quest_item.dart';

class QuestItemMapper {
  const QuestItemMapper();

  QuestItem fromEventContentRow(Map<String, dynamic> row) {
    final content = _map(row['contents']);
    final place = _map(row['places']);
    final contentMetadata = _map(content['metadata']);
    final eventContentMetadata = _map(row['metadata']);

    final eventContentId = _string(row['id']);
    final title = _firstNonEmpty(content['title'], place['name']);

    return QuestItem(
      id: eventContentId,
      eventContentId: eventContentId,
      contentId: _string(row['content_id']),
      placeId: _string(row['place_id']),
      contentKey: _string(content['content_key']),
      title: title.isNotEmpty ? title : '名称未設定',
      latitude: _toDouble(place['latitude']),
      longitude: _toDouble(place['longitude']),
      radiusMeters: _toInt(place['radius_meters'], fallback: 200),
      description: _firstNonEmpty(
        content['description'],
        place['description'],
      ),
      icon: _nullableString(place['icon']) ?? '📍',
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

  String _firstNonEmpty(dynamic first, [dynamic second]) {
    return _nullableString(first) ?? _nullableString(second) ?? '';
  }

  String _string(dynamic value) => value?.toString().trim() ?? '';

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
