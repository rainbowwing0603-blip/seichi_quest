class Seichi {
  final String id;
  final String? placeId;
  final String? contentId;
  final String? eventContentId;
  final String card;
  final String reading;
  final String name;
  final double latitude;
  final double longitude;
  final int stampRadiusMeters;
  final String description;
  final String icon;
  final String? cardImageUrl;
  final bool isActive;

  const Seichi({
    required this.id,
    required this.placeId,
    this.contentId,
    this.eventContentId,
    required this.card,
    required this.reading,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.stampRadiusMeters,
    required this.description,
    required this.icon,
    this.cardImageUrl,
    required this.isActive,
  });

  factory Seichi.fromMap(Map<String, dynamic> map) {
    return Seichi(
      id: map['id']?.toString() ?? '',
      placeId: _toNullableString(map['place_id']),
      contentId: _toNullableString(map['content_id']),
      eventContentId: _toNullableString(map['event_content_id']),
      card: map['card']?.toString() ?? '',
      reading: map['reading']?.toString() ?? '',
      name: map['name']?.toString() ?? '名称未設定',
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      stampRadiusMeters: _toInt(
        map['stamp_radius_meters'],
        fallback: 200,
      ),
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '📍',
      cardImageUrl: _toNullableString(
        map['card_image_url'],
      ),
      isActive: map['is_active'] == true,
    );
  }

  static String? _toNullableString(
    dynamic value,
  ) {
    final text =
        value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  static int _toInt(
    dynamic value, {
    required int fallback,
  }) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }
}
