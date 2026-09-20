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
          'stamp_radius_meters, description, icon, card_image_url, is_active, '
          'place_id, '
          'event_contents!inner(id, content_id, event_id, place_id, is_active, contents!inner(content_key))',
        )
        .eq('is_active', true)
        .eq('event_id', eventId)
        .eq('event_contents.event_id', eventId)
        .eq('event_contents.is_active', true);

    final list = List<Map<String, dynamic>>.from(data)
        .map(_attachGenericContentIdentity)
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

  Map<String, dynamic> _attachGenericContentIdentity(
    Map<String, dynamic> row,
  ) {
    final rawEventContents = row['event_contents'];
    final eventContents = rawEventContents is List
        ? rawEventContents.whereType<Map>().where((eventContent) {
            final rawContent = eventContent['contents'];
            final content = rawContent is Map ? rawContent : null;
            return content?['content_key']?.toString() == row['card']?.toString();
          }).toList(growable: false)
        : const <Map>[];

    if (eventContents.length != 1) {
      throw StateError(
        'Expected exactly one event_content for legacy seichi '
        'id=${row['id']}, card=${row['card']}, '
        'but found ${eventContents.length}.',
      );
    }

    final eventContent = eventContents.single;

    return <String, dynamic>{
      ...row,
      'content_id': eventContent['content_id'],
      'event_content_id': eventContent['id'],
    };
  }

}
