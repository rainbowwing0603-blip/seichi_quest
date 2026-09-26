import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/event.dart';
import 'app_logger.dart';
import 'event_selection_policy.dart';

class EventSelection {
  const EventSelection({
    required this.events,
    required this.currentEvent,
    required this.needsPreferenceSave,
  });

  final List<Event> events;
  final Event currentEvent;
  final bool needsPreferenceSave;
}

/// イベント一覧・現在イベント設定・参加状態のSupabaseアクセスをまとめる。
///
/// 画面固有の読み込み順序やUI状態は扱わない。
class EventService {
  EventService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<EventSelection> loadCurrentEvent() async {
    final user = _client.auth.currentUser;

    final data = await _client
        .from('events')
        .select(
          'id, slug, name, description, prefecture, is_active, '
          'icon_url, cover_image_url, start_at, end_at, updated_at',
        )
        .eq('is_active', true)
        .order('created_at');

    final events = List<Map<String, dynamic>>.from(data)
        .map(Event.fromMap)
        .toList(growable: false);

    if (events.isEmpty) {
      throw Exception('有効なクエストがありません。');
    }

    String? savedEventId;

    if (user != null) {
      try {
        final preference = await _client
            .from('user_event_preferences')
            .select('current_event_id')
            .eq('user_id', user.id)
            .maybeSingle();

        savedEventId = preference?['current_event_id']?.toString();
      } catch (error) {
        appDebugPrint('[EVENT] preference load failed: $error');
      }
    }

    final currentEvent = EventSelectionPolicy.select(
      events: events,
      savedEventId: savedEventId,
    );

    if (currentEvent.id.isEmpty) {
      throw Exception('現在のイベントIDが取得できません。');
    }

    appDebugPrint(
      '[EVENT] current event restored: '
      'id=${currentEvent.id}, name=${currentEvent.name}',
    );

    return EventSelection(
      events: events,
      currentEvent: currentEvent,
      needsPreferenceSave: user != null && savedEventId != currentEvent.id,
    );
  }

  Future<void> completeCurrentEventSelection(EventSelection selection) async {
    if (selection.needsPreferenceSave) {
      await saveCurrentEventPreference(selection.currentEvent.id);
    }
    await ensureParticipation(selection.currentEvent.id);
  }

  Future<void> activateEvent(String eventId) async {
    if (eventId.isEmpty) {
      throw Exception('選択したイベントのIDが取得できません。');
    }

    await saveCurrentEventPreference(eventId);
    await ensureParticipation(eventId);
  }

  Future<void> saveCurrentEventPreference(String eventId) async {
    final user = _client.auth.currentUser;

    if (user == null || eventId.isEmpty) {
      return;
    }

    try {
      await _client.from('user_event_preferences').upsert({
        'user_id': user.id,
        'current_event_id': eventId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');

      appDebugPrint('[EVENT] preference saved: eventId=$eventId');
    } catch (error) {
      appDebugPrint('[EVENT] preference save failed: $error');
      rethrow;
    }
  }

  Future<void> ensureParticipation(String eventId) async {
    final user = _client.auth.currentUser;

    if (user == null || eventId.isEmpty) {
      return;
    }

    try {
      final existing = await _client
          .from('user_event_participations')
          .select('is_active')
          .eq('user_id', user.id)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existing == null) {
        final now = DateTime.now().toUtc().toIso8601String();

        await _client.from('user_event_participations').insert({
          'user_id': user.id,
          'event_id': eventId,
          'joined_at': now,
          'is_active': true,
          'left_at': null,
          'updated_at': now,
        });

        appDebugPrint('[EVENT] participation created: eventId=$eventId');
        return;
      }

      if (existing['is_active'] == true) {
        return;
      }

      await _client
          .from('user_event_participations')
          .update({
            'is_active': true,
            'left_at': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('event_id', eventId);

      appDebugPrint('[EVENT] participation reactivated: eventId=$eventId');
    } catch (error) {
      appDebugPrint('[EVENT] participation ensure failed: $error');
      rethrow;
    }
  }
}
