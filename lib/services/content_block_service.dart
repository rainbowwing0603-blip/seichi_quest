import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_block.dart';

class ContentBlockService {
  ContentBlockService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
