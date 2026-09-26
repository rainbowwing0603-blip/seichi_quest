class Event {
  final String id;
  final String slug;
  final String name;
  final String description;
  final String? prefecture;
  final bool isActive;
  final String? iconUrl;
  final String? coverImageUrl;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? updatedAt;
  final String itemLabelSingular;
  final String itemLabelPlural;
  final String? themePrimaryHex;
  final String? themePrimaryDeepHex;
  final String? themeAccentHex;

  const Event({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    this.prefecture,
    required this.isActive,
    this.iconUrl,
    this.coverImageUrl,
    this.startAt,
    this.endAt,
    this.updatedAt,
    this.itemLabelSingular = 'スポット',
    this.itemLabelPlural = 'スポット',
    this.themePrimaryHex,
    this.themePrimaryDeepHex,
    this.themeAccentHex,
  });

  String eventStatusText({DateTime? now}) {
    final current = now ?? DateTime.now();

    final localStartAt = startAt?.toLocal();
    final localEndAt = endAt?.toLocal();

    if (localStartAt != null &&
        current.isBefore(localStartAt)) {
      return '開催前';
    }

    if (localEndAt != null &&
        current.isAfter(localEndAt)) {
      return '終了';
    }

    return '開催中';
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      name: map['name']?.toString() ?? '名称未設定',
      description: map['description']?.toString() ?? '',
      prefecture: _toNullableString(
        map['prefecture'],
      ),
      isActive: map['is_active'] == true,
      iconUrl: _toNullableString(map['icon_url']),
      coverImageUrl: _toNullableString(
        map['cover_image_url'],
      ),
      startAt: _toDateTime(map['start_at']),
      endAt: _toDateTime(map['end_at']),
      updatedAt: _toDateTime(map['updated_at']),
      itemLabelSingular: _toNullableString(map['item_label_singular']) ?? 'スポット',
      itemLabelPlural: _toNullableString(map['item_label_plural']) ?? 'スポット',
      themePrimaryHex: _toNullableString(map['theme_primary_hex']),
      themePrimaryDeepHex: _toNullableString(map['theme_primary_deep_hex']),
      themeAccentHex: _toNullableString(map['theme_accent_hex']),
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
