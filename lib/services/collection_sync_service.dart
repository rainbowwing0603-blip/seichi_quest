import '../collection_history_service.dart';
import 'stamp_cache_service.dart';

class CollectionSyncStartResult {
  const CollectionSyncStartResult({
    required this.pendingCollectedRows,
    required this.localCollectedIds,
  });

  final List<Map<String, dynamic>> pendingCollectedRows;
  final Set<String> localCollectedIds;
}

/// コレクション同期のデータ処理をまとめる。
///
/// UI側の獲得演出を壊さないため、pending同期とクラウド履歴統合は
/// 明示的に2段階で実行する。呼び出し側は pending の獲得反映後に
/// [mergeCloudHistory] を呼ぶ。
class CollectionSyncService {
  const CollectionSyncService({
    required this._historyService,
    required this._stampCacheService,
  });

  final CollectionHistoryService _historyService;
  final StampCacheService _stampCacheService;

  Future<CollectionSyncStartResult> start({
    required String userId,
    required String eventId,
  }) async {
    final localCollectedIds = await _stampCacheService.load(
      userId: userId,
      eventId: eventId,
    );

    final pendingCollectedRows =
        await _historyService.syncPendingPlaceVisits();

    return CollectionSyncStartResult(
      pendingCollectedRows: pendingCollectedRows,
      localCollectedIds: localCollectedIds,
    );
  }

  Future<Set<String>> mergeCloudHistory({
    required String userId,
    required String eventId,
    required Iterable<String> collectedIds,
  }) async {
    try {
      final history = await _historyService.loadHistory(eventId: eventId);
      final cloudIds = <String>{};

      for (final item in history) {
        final id = item['event_content_id']?.toString();
        if (id != null && id.isNotEmpty) {
          cloudIds.add(id);
        }
      }

      // クラウド履歴が取得できた場合は、event_contents.id を正とする。
      // これにより旧 seichi.id が端末キャッシュに残っていても、
      // 既存の獲得履歴を失わず新IDへ収束できる。
      await _stampCacheService.save(
        userId: userId,
        eventId: eventId,
        collectedIds: cloudIds,
      );

      return cloudIds;
    } catch (_) {
      // クラウド履歴取得失敗時だけ既存の端末キャッシュを維持する。
      return <String>{...collectedIds};
    }
  }
}
