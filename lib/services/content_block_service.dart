import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_block.dart';

class ContentBlockService {
  ContentBlockService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ContentBlock>> loadForEventContent({
    required String eventId,
    required String contentKey,
  }) async {
    final normalizedEventId = eventId.trim();
    final normalizedContentKey = contentKey.trim();

    if (normalizedEventId.isEmpty || normalizedContentKey.isEmpty) {
      return const <ContentBlock>[];
    }

    final rows = await _client
        .from('event_contents')
        .select('content_id, contents!inner(content_key)')
        .eq('event_id', normalizedEventId)
        .eq('is_active', true)
        .eq('contents.content_key', normalizedContentKey)
        .limit(2);

    if (rows.isEmpty) {
      return const <ContentBlock>[];
    }

    if (rows.length != 1) {
      throw StateError(
        'Expected exactly one active event content for '
        'event=$normalizedEventId, contentKey=$normalizedContentKey, '
        'but found ${rows.length}.',
      );
    }

    final contentId = rows.first['content_id']?.toString().trim() ?? '';

    if (contentId.isEmpty) {
      throw StateError(
        'Resolved event content has no content_id for '
        'event=$normalizedEventId, contentKey=$normalizedContentKey.',
      );
    }

    return loadForContent(contentId);
  }

  Future<List<ContentBlock>> loadForContent(String contentId) async {
    final normalizedContentId = contentId.trim();

    if (normalizedContentId.isEmpty) {
      return const <ContentBlock>[];
    }

    final data = await _client
        .from('content_blocks')
        .select(
          'id, content_id, block_type, role, title, body, '
          'media_path, alt_text, link_url, display_order, metadata',
        )
        .eq('content_id', normalizedContentId)
        .eq('is_active', true)
        .order('display_order')
        .order('id');

    return (data as List<dynamic>)
        .map(
          (row) => ContentBlock.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }
}
