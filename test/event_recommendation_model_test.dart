import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/models/event_recommendation.dart';

void main() {
  group('EventRecommendation', () {
    test('parses aggregate fields and marks personalized recommendations', () {
      final recommendation = EventRecommendation.fromMap({
        'event_id': 'event-123',
        'participant_count': 12,
        'demographic_population': 80,
        'participation_rate': 15.0,
        'recommendation_basis': '30代',
      });

      expect(recommendation.eventId, 'event-123');
      expect(recommendation.participantCount, 12);
      expect(recommendation.demographicPopulation, 80);
      expect(recommendation.participationRate, 15.0);
      expect(recommendation.isPersonalized, isTrue);
      expect(recommendation.badgeText, '30代に人気');
    });

    test('uses safe defaults and identifies overall popularity fallback', () {
      final recommendation = EventRecommendation.fromMap({
        'event_id': 'event-456',
        'recommendation_basis': 'みんなに人気',
      });

      expect(recommendation.participantCount, 0);
      expect(recommendation.demographicPopulation, 0);
      expect(recommendation.participationRate, isNull);
      expect(recommendation.isPersonalized, isFalse);
      expect(recommendation.badgeText, 'みんなに人気');
    });
  });
}
