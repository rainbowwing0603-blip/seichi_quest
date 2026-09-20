import '../models/event.dart';

/// Supabaseに依存しない現在イベント選択ルール。
///
/// 優先順位は既存仕様を維持する。
/// 1. 保存済みイベント
/// 2. 上毛かるた
/// 3. 一覧の先頭
abstract final class EventSelectionPolicy {
  static Event select({
    required List<Event> events,
    String? savedEventId,
  }) {
    if (events.isEmpty) {
      throw Exception('有効なクエストがありません。');
    }

    if (savedEventId != null && savedEventId.isNotEmpty) {
      for (final event in events) {
        if (event.id == savedEventId) {
          return event;
        }
      }
    }

    for (final event in events) {
      if (event.slug == 'jomo-karuta-gunma') {
        return event;
      }
    }

    return events.first;
  }
}
