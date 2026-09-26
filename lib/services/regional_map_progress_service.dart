import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/regional_map_progress.dart';

class RegionalMapProgressService {
  RegionalMapProgressService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<List<RegionalMapProgress>> load(String eventId) async {
    if (eventId.isEmpty) return const [];

    final data = await _client.rpc(
      'get_event_regional_map_progress',
      params: {'p_event_id': eventId},
    );

    return List<Map<String, dynamic>>.from(data as List)
        .map(RegionalMapProgress.fromMap)
        .where((item) => item.code.isNotEmpty && item.totalCount > 0)
        .toList(growable: false);
  }
}
