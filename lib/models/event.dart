class Event {
  final String id;
  final String slug;
  final String name;
  final String description;
  final bool isActive;
  final String? iconUrl;
  final String? coverImageUrl;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? updatedAt;

  const Event({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.isActive,
    this.iconUrl,
    this.coverImageUrl,
    this.startAt,
    this.endAt,
    this.updatedAt,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      name: map['name']?.toString() ?? '名称未設定',
      description: map['description']?.toString() ?? '',
      isActive: map['is_active'] == true,
      iconUrl: _toNullableString(map['icon_url']),
      coverImageUrl: _toNullableString(
        map['cover_image_url'],
      ),
      startAt: _toDateTime(map['start_at']),
      endAt: _toDateTime(map['end_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }

  static String? _toNullableString(dynamic value) {
    final text = value?.toString();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    final text = value?.toString();

    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}