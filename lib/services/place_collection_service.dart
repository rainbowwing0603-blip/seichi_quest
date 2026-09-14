import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 物理地点への訪問をDBへ記録し、訪問時点で獲得対象になった札を返す。
///
/// イベントの有効期間判定はDBの `record_place_visit` RPCが担当する。
/// そのため、クライアント側でイベント期間を別途判定しない。
class PlaceCollectionService {
  PlaceCollectionService({
    SupabaseClient? client,
    SharedPreferences? preferences,
  })  : _client = client ?? Supabase.instance.client,
        _preferences = preferences;

  static const _pendingVisitKey = 'pending_place_visits_v1';

  final SupabaseClient _client;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  /// 物理地点への訪問を記録する。
  ///
  /// オンラインなら即時にRPCを実行する。
  /// オフライン等でRPCに失敗した場合は、訪問時刻を保持したまま端末キューへ保存する。
  /// キュー保存時は空リストを返す。通信復旧後に [syncPending] で再送する。
  Future<List<PlaceCollectionResult>> recordPlaceVisit({
    required String seichiId,
    required DateTime collectedAt,
    double? latitude,
    double? longitude,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('認証されたユーザーが必要です。');
    }

    final visit = <String, dynamic>{
      'seichi_id': seichiId,
      'collected_at': collectedAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };

    try {
      return await _recordPlaceVisitRpc(visit);
    } catch (error) {
      debugPrint('[PLACE_COLLECTION] record failed, queued: $error');
      await _enqueueVisit(visit);
      return <PlaceCollectionResult>[];
    }
  }

  /// 保留中の物理地点訪問を同期する。
  ///
  /// 訪問時刻はキューへ保存した元の時刻をそのままRPCへ渡す。
  /// そのため、後から開始したイベントが過去の訪問を遡って獲得することはない。
  Future<void> syncPending() async {
    final prefs = await _prefs;
    final queue = _readJsonList(prefs, _pendingVisitKey);
    if (queue.isEmpty) {
      return;
    }

    if (_client.auth.currentUser == null) {
      return;
    }

    final remaining = <Map<String, dynamic>>[];

    for (final visit in queue) {
      try {
        await _recordPlaceVisitRpc(visit);
      } catch (error) {
        debugPrint('[PLACE_COLLECTION] pending sync failed: $error');
        remaining.add(visit);
      }
    }

    await prefs.setString(_pendingVisitKey, jsonEncode(remaining));
  }

  Future<List<PlaceCollectionResult>> _recordPlaceVisitRpc(
    Map<String, dynamic> visit,
  ) async {
    final data = await _client.rpc(
      'record_place_visit',
      params: {
        'p_seichi_id': visit['seichi_id'],
        'p_collected_at': visit['collected_at'],
        'p_latitude': visit['latitude'],
        'p_longitude': visit['longitude'],
      },
    );

    if (data is! List) {
      return <PlaceCollectionResult>[];
    }

    return data
        .whereType<Map>()
        .map(
          (row) => PlaceCollectionResult.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((result) => result.eventId.isNotEmpty && result.seichiId.isNotEmpty)
        .toList();
  }

  Future<void> _enqueueVisit(Map<String, dynamic> visit) async {
    final prefs = await _prefs;
    final queue = _readJsonList(prefs, _pendingVisitKey);

    final alreadyQueued = queue.any(
      (item) =>
          item['seichi_id']?.toString() == visit['seichi_id']?.toString() &&
          item['collected_at']?.toString() == visit['collected_at']?.toString(),
    );

    if (!alreadyQueued) {
      queue.add(visit);
      await prefs.setString(_pendingVisitKey, jsonEncode(queue));
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

/// 物理地点訪問によって新たに獲得された1件の履歴。
class PlaceCollectionResult {
  const PlaceCollectionResult({
    required this.eventId,
    required this.seichiId,
    required this.placeId,
    required this.collectedAt,
    required this.eventName,
    required this.card,
    required this.seichiName,
  });

  final String eventId;
  final String seichiId;
  final String placeId;
  final DateTime collectedAt;
  final String eventName;
  final String card;
  final String seichiName;

  factory PlaceCollectionResult.fromMap(Map<String, dynamic> map) {
    return PlaceCollectionResult(
      eventId: map['event_id']?.toString() ?? '',
      seichiId: map['seichi_id']?.toString() ?? '',
      placeId: map['place_id']?.toString() ?? '',
      collectedAt: DateTime.tryParse(
            map['collected_at']?.toString() ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      eventName: map['event_name']?.toString() ?? '',
      card: map['card']?.toString() ?? '',
      seichiName: map['seichi_name']?.toString() ?? '',
    );
  }
}
