import '../collection_history_service.dart';
import 'stamp_cache_service.dart';

class CollectionSyncResult {
  const CollectionSyncResult({
    required this.pendingCollectedRows,
    required this.collectedIds,
  });

  final List<Map<String, dynamic>> pendingCollectedRows;
  final Set<String> collectedIds;
}

/// 起動・イベント切替・アカウント切替で共通する
/// 「端末キャッシュ → pending同期 → クラウド履歴統合」をまとめる。
///
/// 獲得演出やランキング更新などのUI副作用は呼び出し側に残す。
class CollectionSyncService {
  const CollectionSyncService({
    required CollectionHistoryService historyService,
    required StampCacheService stampCacheService,
  })  : _historyService = historyService,
        _stampCacheService = stampCacheService;

  final CollectionHistoryService _historyService;
  final StampCacheService _stampCacheService;

  Future<CollectionSyncResult> synchronize({
    required String userId,
    required String eventId,
  }) async {
    final localIds = await _stampCacheService.load(
      userId: userId,
      eventId: eventId,
    );

    final pendingCollectedRows =
        await _historyService.syncPendingPlaceVisits();

    final collectedIds = <String>{...localIds};

    try {
      final history = await _historyService.loadHistory(eventId: eventId);

      for (final item in history) {
        final id = item['seichi_id']?.toString();
        if (id != null && id.isNotEmpty) {
          collectedIds.add(id);
        }
      }

      await _stampCacheService.save(
        userId: userId,
        eventId: eventId,
        collectedIds: collectedIds,
      );
    } catch (_) {
      // クラウド履歴取得失敗時は、既存の端末キャッシュを維持する。
    }

    return CollectionSyncResult(
      pendingCollectedRows: pendingCollectedRows,
      collectedIds: collectedIds,
    );
  }
}
