import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/jomo_karuta_order.dart';
import '../models/seichi.dart';

class SeichiService {
  SeichiService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<List<Seichi>> loadActiveSeichi(String eventId) async {
    if (eventId.isEmpty) {
      throw Exception('イベントIDが未取得のため、聖地を読み込めません。');
    }

    final data = await _client
        .from('seichi')
        .select(
          'id, card, reading, name, latitude, longitude, '
          'stamp_radius_meters, description, icon, card_image_url, is_active, place_id',
        )
        .eq('is_active', true)
        .eq('event_id', eventId);

    final list = List<Map<String, dynamic>>.from(data)
        .map(Seichi.fromMap)
        .where(
          (seichi) =>
              seichi.id.isNotEmpty &&
              seichi.latitude != 0 &&
              seichi.longitude != 0,
        )
        .toList();

    list.sort((a, b) {
      final orderCompare = JomoKarutaOrder.indexOf(a.card)
          .compareTo(JomoKarutaOrder.indexOf(b.card));

      if (orderCompare != 0) {
        return orderCompare;
      }

      return a.card.compareTo(b.card);
    });

    return list;
  }
}
