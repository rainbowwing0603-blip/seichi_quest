import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import '../models/event_recommendation.dart';
import 'app_logger.dart';

class EventRecommendationService {
  EventRecommendationService({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<EventRecommendation>> load({int limit = 5}) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return const <EventRecommendation>[];
    }

    try {
      final data = await _client.rpc(
        'get_event_recommendations',
        params: {'p_limit': limit},
      );

      final rows = List<Map<String, dynamic>>.from(data as List);

      return rows
          .map(EventRecommendation.fromMap)
          .where((recommendation) => recommendation.eventId.isNotEmpty)
          .toList(growable: false);
    } catch (error, stackTrace) {
      appDebugPrint('[RECOMMENDATION] load failed: $error');
      appDebugPrint('[RECOMMENDATION] stackTrace: $stackTrace');
      return const <EventRecommendation>[];
    }
  }
  Future<List<Event>> loadEventsForRecommendations(
    List<EventRecommendation> recommendations,
  ) async {
    final ids = recommendations
        .map((item) => item.eventId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (ids.isEmpty) {
      return const <Event>[];
    }

    try {
      final data = await _client
          .from('events')
          .select(
            'id, slug, name, description, prefecture, is_active, '
            'icon_url, cover_image_url, start_at, end_at, updated_at, '
            'item_label_singular, item_label_plural, theme_primary_hex, '
            'theme_primary_deep_hex, theme_accent_hex',
          )
          .inFilter('id', ids);

      return List<Map<String, dynamic>>.from(data)
          .map(Event.fromMap)
          .toList(growable: false);
    } catch (error, stackTrace) {
      appDebugPrint('[RECOMMENDATION] event load failed: $error');
      appDebugPrint('[RECOMMENDATION] event load stackTrace: $stackTrace');
      return const <Event>[];
    }
  }

}
