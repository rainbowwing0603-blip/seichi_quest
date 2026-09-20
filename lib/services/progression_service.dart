import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/achievement.dart';

class ProgressionService {
  ProgressionService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<List<Achievement>> loadEventAchievements(String eventId) async {
    if (eventId.isEmpty) {
      throw Exception('イベントIDが未取得のため、チャレンジを読み込めません。');
    }

    final data = await _client
        .from('event_achievements')
        .select(
          'sort_order, achievements('
          'id, title, description, icon, required_count'
          ')',
        )
        .eq('event_id', eventId)
        .order('sort_order');

    final rows = List<Map<String, dynamic>>.from(data);
    final achievements = <Achievement>[];

    for (final row in rows) {
      final raw = row['achievements'];

      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final id = raw['id']?.toString() ?? '';

      if (id.isEmpty) {
        continue;
      }

      final requiredCount = raw['required_count'] is int
          ? raw['required_count'] as int
          : int.tryParse(raw['required_count']?.toString() ?? '') ?? 0;

      achievements.add(
        Achievement(
          id: id,
          title: raw['title']?.toString() ?? '',
          description: raw['description']?.toString() ?? '',
          icon: raw['icon']?.toString() ?? '',
          requiredCount: requiredCount,
        ),
      );
    }

    return achievements;
  }

  Future<int?> loadMyEventRank(String eventId) async {
    if (eventId.isEmpty) {
      return null;
    }

    final data = await _client.rpc(
      'get_my_event_rank',
      params: {'p_event_id': eventId},
    );

    final rows = List<Map<String, dynamic>>.from(data as List);

    return rows.isEmpty ? null : (rows.first['rank'] as num?)?.toInt();
  }
}
