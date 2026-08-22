import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// オンライン進行機能のDBアクセスをまとめるサービス。
///
/// 現在の端末内スタンプ処理を置き換えず、将来の同期・ランキング・
/// クエスト・実績機能を安全に追加するための薄い層です。
class OnlineProgressService {
  OnlineProgressService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  String? get userId => _client.auth.currentUser?.id;
  bool get isSignedIn => userId != null;

  Future<void> ensureProfile({String? displayName}) async {
    final id = userId;
    if (id == null) return;

    await _client.from('user_profiles').upsert({
      'id': id,
      if (displayName != null) 'display_name': displayName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> syncStamp(String seichiId) async {
    final id = userId;
    if (id == null) return;

    await _client.from('user_stamps').upsert({
      'user_id': id,
      'seichi_id': seichiId,
      'collected_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Set<String>> fetchCollectedStampIds() async {
    final id = userId;
    if (id == null) return <String>{};

    final rows = await _client
        .from('user_stamps')
        .select('seichi_id')
        .eq('user_id', id);

    return rows
        .map((row) => row['seichi_id']?.toString())
        .whereType<String>()
        .toSet();
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 50}) async {
    final rows = await _client
        .from('leaderboard_scores')
        .select('user_id, score, collected_count, updated_at')
        .order('score', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchActiveQuests() async {
    final rows = await _client
        .from('quests')
        .select()
        .eq('is_active', true)
        .order('id');

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchAchievements() async {
    final rows = await _client
        .from('achievements')
        .select()
        .eq('is_active', true)
        .order('required_count');

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> close() async {
    // SupabaseClient はアプリ全体で共有するため、ここでは破棄しません。
  }
}
