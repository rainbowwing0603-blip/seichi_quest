class QuestItem {
  final String id;
  final String eventContentId;
  final String contentId;
  final String placeId;
  final String contentKey;
  final String title;
  final double latitude;
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

  String? get legacySeichiId =>
      _nullableString(contentMetadata['legacy_seichi_id']);

  String? get legacyCard => _nullableString(contentMetadata['card']);

  String? get legacyReading => _nullableString(contentMetadata['reading']);

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
