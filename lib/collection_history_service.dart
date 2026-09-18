import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/app_logger.dart';

/// 獲得履歴を「端末先行 + Supabase同期」で扱うサービス。
///
/// オフライン時は SharedPreferences に保留し、次回同期可能になった時点で
/// Supabase に upsert する。ネットワーク障害でスタンプ獲得そのものを
/// 失敗扱いにしないことを最優先にする。
class CollectionHistoryService {
  CollectionHistoryService({SupabaseClient? client, this._preferences})
    : _client = client ?? Supabase.instance.client;

  static const _placeVisitQueueKey = 'pending_place_visits_v1';
  static const _historyKey = 'collection_history_cache_v1';

  final SupabaseClient _client;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<String> _resolveUserScopedStringKey(
    SharedPreferences prefs,
    String baseKey,
    String userId,
  ) async {
    final scopedKey = '${baseKey}_$userId';

    if (prefs.containsKey(baseKey)) {
      final legacyValue = prefs.getString(baseKey);

      if (!prefs.containsKey(scopedKey) && legacyValue != null) {
        await prefs.setString(scopedKey, legacyValue);
      }

      await prefs.remove(baseKey);
    }

    return scopedKey;
  }

  bool _isPermanentServerRejection(Object error) {
    return error is PostgrestException && error.code == 'P0001';
  }

  /// 物理地点への訪問をサーバーへ記録し、新規獲得した履歴だけを返す。
  ///
  /// 通信・認証などでRPCに失敗した場合は、元の訪問時刻と位置情報、
  /// client_visit_id をそのまま保留キューへ保存する。
  Future<List<Map<String, dynamic>>> recordPlaceVisitAndCollect({
    required String placeId,
    required DateTime visitedAt,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    String source = 'gps',
    Map<String, dynamic> metadata = const {},
  }) async {
    final clientVisitId = _newUuidV4();

    final visit = <String, dynamic>{
      'place_id': placeId,
      'client_visit_id': clientVisitId,
      'visited_at': visitedAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'source': source,
      'metadata': metadata,
    };

    try {
      return await _callRecordPlaceVisitAndCollect(
        placeId: placeId,
        clientVisitId: clientVisitId,
        visitedAt: visitedAt,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        source: source,
        metadata: metadata,
      );
    } catch (error) {
      if (_isPermanentServerRejection(error)) {
        appDebugPrint(
          '[HISTORY] place visit rejected by server; not queued: $error',
        );
        return <Map<String, dynamic>>[];
      }

      appDebugPrint(
        '[HISTORY] place visit RPC failed; queued for retry: $error',
      );

      final user = _client.auth.currentUser;
      if (user == null) {
        appDebugPrint(
          '[HISTORY] place visit not queued because authenticated user is unavailable',
        );
        return <Map<String, dynamic>>[];
      }

      final prefs = await _prefs;
      final queueKey = await _resolveUserScopedStringKey(
        prefs,
        _placeVisitQueueKey,
        user.id,
      );
      final queue = _readJsonList(prefs, queueKey);

      final exists = queue.any((item) {
        if (item['place_id']?.toString() != placeId) {
          return false;
        }

        final pendingVisitedAt = DateTime.tryParse(
          item['visited_at']?.toString() ?? '',
        );

        if (pendingVisitedAt == null) {
          return false;
        }

        return visitedAt.toUtc().difference(pendingVisitedAt.toUtc()).abs() <
            const Duration(minutes: 10);
      });

      if (!exists) {
        queue.add(visit);
        await prefs.setString(queueKey, jsonEncode(queue));
        appDebugPrint('[HISTORY] pending place visit queued: count=');
      }

      return <Map<String, dynamic>>[];
    }
  }

  /// このユーザーの端末に残っている未同期の訪問件数を返す。
  Future<int> pendingPlaceVisitCount() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return 0;
    }

    final prefs = await _prefs;
    final queueKey = await _resolveUserScopedStringKey(
      prefs,
      _placeVisitQueueKey,
      user.id,
    );

    return _readJsonList(prefs, queueKey).length;
  }

  /// 保留中の物理地点訪問を、元の訪問情報のまま再送する。
  Future<List<Map<String, dynamic>>> syncPendingPlaceVisits() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return <Map<String, dynamic>>[];
    }

    final prefs = await _prefs;
    final queueKey = await _resolveUserScopedStringKey(
      prefs,
      _placeVisitQueueKey,
      user.id,
    );
    final queue = _readJsonList(prefs, queueKey);

    appDebugPrint('[HISTORY] pending place visit sync start: count=');

    if (queue.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final remaining = <Map<String, dynamic>>[];
    final collectedRows = <Map<String, dynamic>>[];

    for (final visit in queue) {
      try {
        final visitedAt = DateTime.tryParse(
          visit['visited_at']?.toString() ?? '',
        );

        final placeId = visit['place_id']?.toString();
        final clientVisitId = visit['client_visit_id']?.toString();
        final latitude = (visit['latitude'] as num?)?.toDouble();
        final longitude = (visit['longitude'] as num?)?.toDouble();
        final accuracyMeters = (visit['accuracy_meters'] as num?)?.toDouble();
        final source = visit['source']?.toString() ?? 'gps';

        final rawMetadata = visit['metadata'];
        final metadata = rawMetadata is Map
            ? Map<String, dynamic>.from(rawMetadata)
            : <String, dynamic>{};

        if (visitedAt == null ||
            placeId == null ||
            placeId.isEmpty ||
            clientVisitId == null ||
            clientVisitId.isEmpty ||
            latitude == null ||
            longitude == null) {
          appDebugPrint('[HISTORY] invalid pending place visit; kept in queue');
          remaining.add(visit);
          continue;
        }

        final result = await _callRecordPlaceVisitAndCollect(
          placeId: placeId,
          clientVisitId: clientVisitId,
          visitedAt: visitedAt,
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracyMeters,
          source: source,
          metadata: metadata,
        );

        collectedRows.addAll(result);
      } catch (error) {
        if (_isPermanentServerRejection(error)) {
          appDebugPrint(
            '[HISTORY] pending place visit rejected by server; dropped: $error',
          );
          continue;
        }

        appDebugPrint('[HISTORY] pending place visit sync failed: $error');
        remaining.add(visit);
      }
    }

    await prefs.setString(queueKey, jsonEncode(remaining));

    appDebugPrint(
      '[HISTORY] pending place visit sync complete: remaining=, collected=',
    );

    return collectedRows;
  }

  /// DBと端末キャッシュを合わせた履歴を取得する。
  /// DBが取得できない場合でも、端末キャッシュを返す。
  Future<List<Map<String, dynamic>>> loadHistory({
    required String eventId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return <Map<String, dynamic>>[];
    }

    final prefs = await _prefs;
    final historyKey = await _resolveUserScopedStringKey(
      prefs,
      _historyKey,
      user.id,
    );
    final allLocal = _readJsonList(prefs, historyKey);
    final local = allLocal
        .where((item) => item['event_id']?.toString() == eventId)
        .toList();

    try {
      final data = await _client
          .from('collection_history')
          .select('event_id, seichi_id, collected_at, latitude, longitude')
          .eq('user_id', user.id)
          .eq('event_id', eventId)
          .order('collected_at', ascending: false);

      final remote = List<Map<String, dynamic>>.from(data);
      final merged = <String, Map<String, dynamic>>{};

      for (final item in local) {
        final eventIdValue = item['event_id']?.toString();
        final id = item['seichi_id']?.toString();
        if (eventIdValue != null &&
            eventIdValue.isNotEmpty &&
            id != null &&
            id.isNotEmpty) {
          merged['$eventIdValue:$id'] = item;
        }
      }
      for (final item in remote) {
        final eventIdValue = item['event_id']?.toString();
        final id = item['seichi_id']?.toString();
        if (eventIdValue != null &&
            eventIdValue.isNotEmpty &&
            id != null &&
            id.isNotEmpty) {
          merged['$eventIdValue:$id'] = item;
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

      final updatedAllLocal = <String, Map<String, dynamic>>{};

      for (final item in allLocal) {
        final eventIdValue = item['event_id']?.toString();
        final id = item['seichi_id']?.toString();

        if (eventIdValue != null &&
            eventIdValue.isNotEmpty &&
            id != null &&
            id.isNotEmpty) {
          updatedAllLocal['$eventIdValue:$id'] = item;
        }
      }

      for (final item in result) {
        final eventIdValue = item['event_id']?.toString();
        final id = item['seichi_id']?.toString();

        if (eventIdValue != null &&
            eventIdValue.isNotEmpty &&
            id != null &&
            id.isNotEmpty) {
          updatedAllLocal['$eventIdValue:$id'] = item;
        }
      }

      final updatedCache = updatedAllLocal.values.toList()
        ..sort((a, b) {
          final aDate = DateTime.tryParse(a['collected_at']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['collected_at']?.toString() ?? '');

          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;

          return bDate.compareTo(aDate);
        });

      await prefs.setString(historyKey, jsonEncode(updatedCache));
      return result;
    } catch (_) {
      return local;
    }
  }

  /// 全イベントを対象に、コレクション画面表示用の獲得履歴を取得する。
  Future<List<Map<String, dynamic>>> loadCollectionDisplayHistory() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }

    final data = await _client.rpc('get_my_collection_history');

    return List<Map<String, dynamic>>.from(data);
  }

  /// 現在のユーザーが全イベントで獲得したスタンプの累計数を返す。
  ///
  /// 同じ聖地でも別イベントで獲得した場合は、
  /// それぞれ別の獲得実績として数える。
  Future<int> loadTotalCollectionCount() async {
    final history = await loadCollectionDisplayHistory();
    return history.length;
  }

  /// 指定イベントの獲得履歴をDBと端末からリセットする。
  ///
  /// DB側はSupabase RPCで現在のユーザー自身の履歴だけを削除し、
  /// 端末側では指定イベントのキャッシュと保留キューだけを削除する。
  Future<void> resetEventCollectionHistory({required String eventId}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('認証されたユーザーが必要です。');
    }

    await _client.rpc(
      'reset_event_collection_history',
      params: {'p_event_id': eventId},
    );

    final prefs = await _prefs;

    final historyKey = await _resolveUserScopedStringKey(
      prefs,
      _historyKey,
      user.id,
    );

    final allLocal = _readJsonList(prefs, historyKey);
    final remainingLocal = allLocal
        .where((item) => item['event_id']?.toString() != eventId)
        .toList();
    await prefs.setString(historyKey, jsonEncode(remainingLocal));
  }

  Future<List<Map<String, dynamic>>> _callRecordPlaceVisitAndCollect({
    required String placeId,
    required String clientVisitId,
    required DateTime visitedAt,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    String source = 'gps',
    Map<String, dynamic> metadata = const {},
  }) async {
    final result = await _client.rpc(
      'record_place_visit_and_collect',
      params: {
        'p_place_id': placeId,
        'p_client_visit_id': clientVisitId,
        'p_visited_at': visitedAt.toUtc().toIso8601String(),
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy_meters': accuracyMeters,
        'p_source': source,
        'p_metadata': metadata,
      },
    );

    if (result is! List) {
      return <Map<String, dynamic>>[];
    }

    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _newUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
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
