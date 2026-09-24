import 'quest_destination.dart';

class QuestItem implements QuestDestination {
  @override
  final String id;
  final String eventContentId;
  final String contentId;
  final String placeId;
  final String contentKey;
  final String title;
  @override
  final double latitude;
  @override
  final double longitude;
  final int radiusMeters;
  final String description;
  final String icon;
  final String? primaryImageUrl;
  final int displayOrder;
  final bool isActive;
  final Map<String, dynamic> contentMetadata;
  final Map<String, dynamic> eventContentMetadata;

  const QuestItem({
    required this.id,
    required this.eventContentId,
    required this.contentId,
    required this.placeId,
    required this.contentKey,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.description,
    required this.icon,
    this.primaryImageUrl,
    required this.displayOrder,
    required this.isActive,
    this.contentMetadata = const <String, dynamic>{},
    this.eventContentMetadata = const <String, dynamic>{},
  });

  // Transitional presentation alias. The shared UI uses title/radiusMeters;
  // legacy metadata remains data-only compatibility until its migration ends.
  String get name => title;
  int get stampRadiusMeters => radiusMeters;

}
