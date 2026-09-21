import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/quest_item.dart';
import 'quest_item_mapper.dart';

class QuestItemService {
  QuestItemService({
    supabase.SupabaseClient? client,
    this.mapper = const QuestItemMapper(),
  }) : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;
  final QuestItemMapper mapper;

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

    final items = List<Map<String, dynamic>>.from(data)
        .map(mapper.fromEventContentRow)
        .where(
          (item) =>
              item.id.isNotEmpty &&
              item.contentId.isNotEmpty &&
              item.placeId.isNotEmpty &&
              item.latitude != 0 &&
              item.longitude != 0,
        )
        .toList();

    items.sort((a, b) {
      final byDisplayOrder = a.displayOrder.compareTo(b.displayOrder);
      if (byDisplayOrder != 0) {
        return byDisplayOrder;
      }
      return a.eventContentId.compareTo(b.eventContentId);
    });

    return List<QuestItem>.unmodifiable(items);
  }
}
