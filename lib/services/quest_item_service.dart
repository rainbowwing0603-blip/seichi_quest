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
  Future<List<QuestItem>> loadActiveItemsForRegion({
    required String eventId,
    required String regionCode,
  }) async {
    if (eventId.isEmpty || regionCode.isEmpty) {
      throw Exception('イベントまたは地域が未取得のため、コンテンツを読み込めません。');
    }

    final data = await _client.rpc(
      'get_event_contents_by_region',
      params: {
        'p_event_id': eventId,
        'p_region_code': regionCode,
      },
    );

    final rows = List<Map<String, dynamic>>.from(data as List);
    return _mapRpcRows(rows);
  }

  Future<List<QuestItem>> loadActiveItemsByIds({
    required String eventId,
    required Iterable<String> eventContentIds,
  }) async {
    final ids = eventContentIds.where((id) => id.isNotEmpty).toSet().toList();
    if (eventId.isEmpty || ids.isEmpty) return const [];

    final data = await _client.rpc(
      'get_event_contents_by_ids',
      params: {
        'p_event_id': eventId,
        'p_event_content_ids': ids,
      },
    );
    final rows = List<Map<String, dynamic>>.from(data as List);
    return List<QuestItem>.unmodifiable(
      rows.map(_questItemFromRpcRow).where(_isValidRpcItem),
    );
  }

  Future<List<QuestItem>> loadActiveItemsPage({
    required String eventId,
    int offset = 0,
    int limit = 100,
    String collectionState = 'all',
  }) async {
    if (eventId.isEmpty) {
      throw Exception('イベントIDが未取得のため、コンテンツを読み込めません。');
    }

    final data = await _client.rpc(
      'get_event_contents_page',
      params: {
        'p_event_id': eventId,
        'p_offset': offset,
        'p_limit': limit,
        'p_collection_state': collectionState,
      },
    );

    final rows = List<Map<String, dynamic>>.from(data as List);
    return List<QuestItem>.unmodifiable(
      rows.map(_questItemFromRpcRow).where(_isValidRpcItem),
    );
  }

  Future<List<QuestItem>> loadActiveItemsInBounds({
    required String eventId,
    required double south,
    required double west,
    required double north,
    required double east,
    int limit = 400,
  }) async {
    if (eventId.isEmpty) {
      throw Exception('イベントIDが未取得のため、表示範囲を読み込めません。');
    }

    final data = await _client.rpc(
      'get_event_contents_in_bounds',
      params: {
        'p_event_id': eventId,
        'p_south': south,
        'p_west': west,
        'p_north': north,
        'p_east': east,
        'p_limit': limit,
      },
    );

    final rows = List<Map<String, dynamic>>.from(data as List);
    return _mapRpcRows(rows);
  }

  Future<List<QuestItem>> loadActiveItemsNearby({
    required String eventId,
    required double latitude,
    required double longitude,
    double radiusMeters = 50000,
    int limit = 250,
  }) async {
    final data = await _client.rpc(
      'get_event_contents_nearby',
      params: {
        'p_event_id': eventId,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_meters': radiusMeters,
        'p_limit': limit,
      },
    );

    final rows = List<Map<String, dynamic>>.from(data as List);
    return List<QuestItem>.unmodifiable(rows.map(_questItemFromRpcRow).where(_isValidRpcItem));
  }

  List<QuestItem> _mapRpcRows(List<Map<String, dynamic>> rows) {
    return List<QuestItem>.unmodifiable(
      rows.map(_questItemFromRpcRow).where(_isValidRpcItem),
    );
  }

  QuestItem _questItemFromRpcRow(Map<String, dynamic> row) {
    final eventContentId = row['event_content_id']?.toString() ?? '';
    return QuestItem(
      id: eventContentId,
      eventContentId: eventContentId,
      contentId: row['content_id']?.toString() ?? '',
      placeId: row['place_id']?.toString() ?? '',
      contentKey: row['content_key']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
      radiusMeters: (row['stamp_radius_meters'] as num?)?.toInt() ?? 200,
      description: row['description']?.toString() ?? '',
      icon: row['icon']?.toString() ?? '📍',
      primaryImageUrl: row['image_url']?.toString(),
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
      isActive: true,
      eventContentMetadata: {
        'prefecture': row['prefecture'],
        'city': row['city'],
        if (row['distance_meters'] != null)
          'distance_meters': (row['distance_meters'] as num).toDouble(),
      },
    );
  }

  bool _isValidRpcItem(QuestItem item) =>
      item.id.isNotEmpty &&
      item.contentId.isNotEmpty &&
      item.placeId.isNotEmpty &&
      item.latitude != 0 &&
      item.longitude != 0;

}
