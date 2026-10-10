class EventRecommendation {
  const EventRecommendation({
    required this.eventId,
    required this.participantCount,
    required this.demographicPopulation,
    required this.participationRate,
    required this.recommendationBasis,
  });

  final String eventId;
  final int participantCount;
  final int demographicPopulation;
  final double? participationRate;
  final String recommendationBasis;

  bool get isPersonalized => recommendationBasis != 'みんなに人気';

  String get badgeText =>
      isPersonalized ? '$recommendationBasisに人気' : recommendationBasis;

  factory EventRecommendation.fromMap(Map<String, dynamic> map) {
    return EventRecommendation(
      eventId: map['event_id']?.toString() ?? '',
      participantCount: (map['participant_count'] as num?)?.toInt() ?? 0,
      demographicPopulation:
          (map['demographic_population'] as num?)?.toInt() ?? 0,
      participationRate:
          (map['participation_rate'] as num?)?.toDouble(),
      recommendationBasis:
          map['recommendation_basis']?.toString() ?? 'みんなに人気',
    );
  }
}
