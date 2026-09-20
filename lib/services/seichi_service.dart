import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/quest_item.dart';
import '../models/seichi.dart';
import 'quest_item_service.dart';

class SeichiService {
  SeichiService({
    supabase.SupabaseClient? client,
    QuestItemService? questItemService,
  }) : _questItemService =
           questItemService ?? QuestItemService(client: client);

  final QuestItemService _questItemService;

  Future<List<Seichi>> loadActiveSeichi(String eventId) async {
    final items = await _questItemService.loadActiveItems(eventId);
    return items.map(_toLegacySeichi).toList(growable: false);
  }

  Seichi _toLegacySeichi(QuestItem item) {
    return Seichi(
      id: item.id,
      placeId: item.placeId,
      contentId: item.contentId,
      eventContentId: item.eventContentId,
      card: item.legacyCard ?? item.contentKey,
      reading: item.legacyReading ?? '',
      name: item.title,
      latitude: item.latitude,
      longitude: item.longitude,
      stampRadiusMeters: item.radiusMeters,
      description: item.description,
      icon: item.icon,
      cardImageUrl: item.primaryImageUrl,
      isActive: item.isActive,
    );
  }
}
