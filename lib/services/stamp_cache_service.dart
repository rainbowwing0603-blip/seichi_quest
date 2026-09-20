import 'package:shared_preferences/shared_preferences.dart';

/// ユーザー・イベント単位のスタンプ端末キャッシュを管理する。
///
/// クラウド履歴やスタンプ獲得判定は扱わず、SharedPreferences上の
/// 互換移行・読み込み・保存だけを担当する。
class StampCacheService {
  StampCacheService({this.preferences});

  final SharedPreferences? preferences;

  String storageKey({
    required String userId,
    required String eventId,
  }) {
    return 'collected_seichi_ids_v2_${userId}_$eventId';
  }

  Future<SharedPreferences> _prefs() async {
    return preferences ?? await SharedPreferences.getInstance();
  }

  Future<void> migrateLegacyCache({
    required String userId,
    required String currentEventId,
  }) async {
    const legacyGlobalKey = 'collected_seichi_ids';
    const legacyEventPrefix = 'collected_seichi_ids_';
    const scopedPrefix = 'collected_seichi_ids_v2_';

    final preferences = await _prefs();
    final keys = preferences.getKeys().toList();

    for (final key in keys) {
      if (!key.startsWith(legacyEventPrefix) || key.startsWith(scopedPrefix)) {
        continue;
      }

      final eventId = key.substring(legacyEventPrefix.length);

      if (eventId.isEmpty) {
        continue;
      }

      final legacyIds = preferences.getStringList(key);
      final scopedKey = storageKey(userId: userId, eventId: eventId);
      final scopedIds = preferences.getStringList(scopedKey) ?? <String>[];

      final mergedIds = <String>{...scopedIds, ...?legacyIds}.toList();

      await preferences.setStringList(scopedKey, mergedIds);
      await preferences.remove(key);
    }

    final legacyGlobalIds = preferences.getStringList(legacyGlobalKey);

    if (legacyGlobalIds != null) {
      final scopedKey = storageKey(
        userId: userId,
        eventId: currentEventId,
      );
      final scopedIds = preferences.getStringList(scopedKey) ?? <String>[];

      final mergedIds = <String>{...scopedIds, ...legacyGlobalIds}.toList();

      await preferences.setStringList(scopedKey, mergedIds);
      await preferences.remove(legacyGlobalKey);
    }
  }

  Future<Set<String>> load({
    required String userId,
    required String eventId,
  }) async {
    final preferences = await _prefs();

    await migrateLegacyCache(
      userId: userId,
      currentEventId: eventId,
    );

    final savedIds = preferences.getStringList(
      storageKey(userId: userId, eventId: eventId),
    );

    return <String>{...?savedIds};
  }

  Future<void> save({
    required String userId,
    required String eventId,
    required Iterable<String> collectedIds,
  }) async {
    final preferences = await _prefs();
    await preferences.setStringList(
      storageKey(userId: userId, eventId: eventId),
      collectedIds.toList(growable: false),
    );
  }
}
