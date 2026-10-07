import 'package:supabase_flutter/supabase_flutter.dart';

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
}
