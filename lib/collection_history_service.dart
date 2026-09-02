import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 獲得履歴を「端末先行 + Supabase同期」で扱うサービス。
///
/// オフライン時は SharedPreferences に保留し、次回同期可能になった時点で
/// Supabase に upsert する。ネットワーク障害でスタンプ獲得そのものを
/// 失敗扱いにしないことを最優先にする。
class CollectionHistoryService {
  CollectionHistoryService({
    SupabaseClient? client,
    this._preferences,
  }) : _client = client ?? Supabase.instance.client;

  static const _queueKey = 'pending_collection_history_v1';
  static const _historyKey = 'collection_history_cache_v1';

  final SupabaseClient _client;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  /// 端末側に履歴を即時保存し、その後オンライン同期を試みる。
  ///
  /// 戻り値は「端末への保存が成功したか」。DB同期の成否には依存しない。
  Future<bool> recordCollection({
    required String seichiId,
    required DateTime collectedAt,
    double? latitude,
    double? longitude,
  }) async {
    final event = <String, dynamic>{
      'seichi_id': seichiId,
      'collected_at': collectedAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };

    final prefs = await _prefs;
    final cached = _readJsonList(prefs, _historyKey);

    // 端末上でも同じ札を二重記録しない。
    final exists = cached.any(
      (item) => item['seichi_id']?.toString() == seichiId,
    );

    if (!exists) {
      cached.add(event);
      await prefs.setString(_historyKey, jsonEncode(cached));
    }

    await _enqueueIfNeeded(event);
    await syncPending();
    return true;
  }

  /// 保留中の履歴をSupabaseへ同期する。
  /// ネットワーク障害・認証未確立などの場合はキューを保持したまま終了する。
  Future<void> syncPending() async {
    final prefs = await _prefs;
    final queue = _readJsonList(prefs, _queueKey);
    if (queue.isEmpty) {
      return;
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      // 認証がまだない場合は消さない。後のログイン/匿名認証後に再送する。
      return;
    }

    final remaining = <Map<String, dynamic>>[];

    for (final event in queue) {
      try {
        await _client.from('collection_history').upsert(
          {
            'user_id': user.id,
            'seichi_id': event['seichi_id'],
            'collected_at': event['collected_at'],
            'latitude': event['latitude'],
            'longitude': event['longitude'],
          },
          onConflict: 'user_id,seichi_id',
        );
      } catch (error) {
        debugPrint('[HISTORY] sync failed: $error');
        // 1件失敗しても後続を捨てない。次回起動・通信復旧時に再試行する。
        remaining.add(event);
      }
    }

    await prefs.setString(_queueKey, jsonEncode(remaining));
  }

  Future<void> _enqueueIfNeeded(Map<String, dynamic> event) async {
    final prefs = await _prefs;
    final queue = _readJsonList(prefs, _queueKey);

    final alreadyQueued = queue.any(
      (item) => item['seichi_id']?.toString() == event['seichi_id']?.toString(),
    );

    if (!alreadyQueued) {
      queue.add(event);
      await prefs.setString(_queueKey, jsonEncode(queue));
    }
  }

  /// DBと端末キャッシュを合わせた履歴を取得する。
  /// DBが取得できない場合でも、端末キャッシュを返す。
  Future<List<Map<String, dynamic>>> loadHistory() async {
    final prefs = await _prefs;
    final local = _readJsonList(prefs, _historyKey);

    final user = _client.auth.currentUser;
    if (user == null) {
      return local;
    }

    try {
      final data = await _client
          .from('collection_history')
          .select('seichi_id, collected_at, latitude, longitude')
          .eq('user_id', user.id)
          .order('collected_at', ascending: false);

      final remote = List<Map<String, dynamic>>.from(data);
      final merged = <String, Map<String, dynamic>>{};

      for (final item in local) {
        final id = item['seichi_id']?.toString();
        if (id != null && id.isNotEmpty) {
          merged[id] = item;
        }
      }

      for (final item in remote) {
        final id = item['seichi_id']?.toString();
        if (id != null && id.isNotEmpty) {
          merged[id] = item;
        }
      }

      final result = merged.values.toList()
        ..sort((a, b) {
          final aDate = DateTime.tryParse(a['collected_at']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['collected_at']?.toString() ?? '');
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

      await prefs.setString(_historyKey, jsonEncode(result));
      return result;
    } catch (_) {
      return local;
    }
  }

  List<Map<String, dynamic>> _readJsonList(
    SharedPreferences prefs,
    String key,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
