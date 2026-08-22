import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// オンライン進行機能のDBアクセスをまとめるサービス。
///
/// 端末内スタンプ処理を壊さず、ログイン済みの場合だけオンラインへ同期します。
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

  /// 1札をオンラインへ同期します。
  /// DB側のトリガーが統計・ランキング・実績・クエストを更新します。
  Future<void> syncStamp(String seichiId) async {
    final id = userId;
    if (id == null) return;

    await _client.from('user_stamps').upsert({
      'user_id': id,
      'seichi_id': seichiId,
      'collected_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// 端末側で既に取得済みの札をまとめて同期します。
  Future<void> syncStamps(Iterable<String> seichiIds) async {
    final id = userId;
    if (id == null) return;

    final ids = seichiIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('user_stamps').upsert(
      ids
          .map((seichiId) => {
                'user_id': id,
                'seichi_id': seichiId,
                'collected_at': now,
              })
          .toList(),
      onConflict: 'user_id,seichi_id',
    );
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

  Future<Map<String, dynamic>?> fetchMyStats() async {
    final id = userId;
    if (id == null) return null;

    final row = await _client
        .from('user_stats')
        .select('collected_count, quest_count, achievement_count, updated_at')
        .eq('user_id', id)
        .maybeSingle();

    return row;
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 50}) async {
    final safeLimit = limit.clamp(1, 100);
    final rows = await _client
        .from('leaderboard_scores')
        .select('user_id, score, collected_count, updated_at')
        .order('score', ascending: false)
        .limit(safeLimit);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchMyQuests() async {
    final id = userId;
    if (id == null) return <Map<String, dynamic>>[];

    final rows = await _client
        .from('user_quests')
        .select('quest_id, progress, completed_at, updated_at')
        .eq('user_id', id)
        .order('updated_at', ascending: false);

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

  Future<Set<String>> fetchMyAchievementIds() async {
    final id = userId;
    if (id == null) return <String>{};

    final rows = await _client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', id);

    return rows
        .map((row) => row['achievement_id']?.toString())
        .whereType<String>()
        .toSet();
  }

  Future<void> close() async {
    // SupabaseClient はアプリ全体で共有するため、ここでは破棄しません。
  }
}
