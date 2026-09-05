import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 物理地点への訪問をDBへ記録し、訪問時点で獲得対象になった札を返す。
///
/// イベントの有効期間判定はDBの `record_place_visit` RPCが担当する。
/// そのため、クライアント側でイベント期間を別途判定しない。
class PlaceCollectionService {
  PlaceCollectionService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// 指定された札の物理地点を訪問したことを記録する。
  ///
  /// RPCは、訪問時刻に有効なイベントに属する同一地点の札をすべて処理し、
  /// 今回新たに記録された履歴だけを返す。
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

    try {
      final data = await _client.rpc(
        'record_place_visit',
        params: {
          'p_seichi_id': seichiId,
          'p_collected_at': collectedAt.toUtc().toIso8601String(),
          'p_latitude': latitude,
          'p_longitude': longitude,
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
          .toList();
    } catch (error) {
      debugPrint('[PLACE_COLLECTION] record failed: $error');
      rethrow;
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
