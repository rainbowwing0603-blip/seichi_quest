class RegionalMapProgress {
  const RegionalMapProgress({
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.collectedCount,
    required this.totalCount,
    required this.completionPercent,
  });

  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final int collectedCount;
  final int totalCount;
  final double completionPercent;

  factory RegionalMapProgress.fromMap(Map<String, dynamic> map) {
    return RegionalMapProgress(
      code: map['region_code']?.toString() ?? '',
      name: map['region_name']?.toString() ?? '',
      latitude: (map['center_latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['center_longitude'] as num?)?.toDouble() ?? 0,
      collectedCount: (map['collected_count'] as num?)?.toInt() ?? 0,
      totalCount: (map['total_count'] as num?)?.toInt() ?? 0,
      completionPercent: (map['completion_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}
