class Seichi {
  final String id;
  final String card;
  final String reading;
  final String name;
  final double latitude;
  final double longitude;
  final int stampRadiusMeters;
  final String description;
  final String icon;
  final bool isActive;

  const Seichi({
    required this.id,
    required this.card,
    required this.reading,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.stampRadiusMeters,
    required this.description,
    required this.icon,
    required this.isActive,
  });

  factory Seichi.fromMap(Map<String, dynamic> map) {
    return Seichi(
      id: map['id']?.toString() ?? '',
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
      isActive: map['is_active'] == true,
    );
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
