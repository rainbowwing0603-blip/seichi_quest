import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class EventProgressSummary {
  const EventProgressSummary({
    required this.totalCount,
    required this.collectedCount,
  });

  final int totalCount;
  final int collectedCount;
}

class EventProgressService {
  EventProgressService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<EventProgressSummary> load(String eventId) async {
    if (eventId.isEmpty) {
      return const EventProgressSummary(totalCount: 0, collectedCount: 0);
    }

    final data = await _client.rpc(
      'get_event_progress_summary',
      params: {'p_event_id': eventId},
    );
    final rows = List<Map<String, dynamic>>.from(data as List);
    if (rows.isEmpty) {
      return const EventProgressSummary(totalCount: 0, collectedCount: 0);
    }

    final row = rows.first;
    return EventProgressSummary(
      totalCount: (row['total_count'] as num?)?.toInt() ?? 0,
      collectedCount: (row['collected_count'] as num?)?.toInt() ?? 0,
    );
  }
}
