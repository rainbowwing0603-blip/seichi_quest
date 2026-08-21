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
  });

  factory Seichi.fromMap(Map<String, dynamic> map) {
    return Seichi(
      id: map['id']?.toString() ?? '',
      card: map['card']?.toString() ?? '',
      reading: map['reading']?.toString() ?? '',
      name: map['name']?.toString() ?? '未設定',
      latitude: _doubleValue(map['latitude']),
      longitude: _doubleValue(map['longitude']),
      stampRadiusMeters: _intValue(map['stamp_radius_meters'], 200),
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '📍',
    );
  }

  static double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _intValue(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
