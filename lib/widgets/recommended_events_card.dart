import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/event_recommendation.dart';
import '../services/app_logger.dart';
import '../services/event_recommendation_service.dart';
import 'event_recommendation_section.dart';

class RecommendedEventsCard extends StatefulWidget {
  const RecommendedEventsCard({
    super.key,
    this.onEventTap,
  });

  final ValueChanged<Event>? onEventTap;

  @override
  State<RecommendedEventsCard> createState() => _RecommendedEventsCardState();
}

class _RecommendedEventsCardState extends State<RecommendedEventsCard> {
  bool _loading = true;
  List<EventRecommendation> _recommendations =
      const <EventRecommendation>[];
  List<Event> _events = const <Event>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = EventRecommendationService();
      final recommendations = await service.load(limit: 5);

      if (!mounted) {
        return;
      }

      if (recommendations.isEmpty) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final events =
          await service.loadEventsForRecommendations(recommendations);

      if (!mounted) {
        return;
      }

      setState(() {
        _recommendations = recommendations;
        _events = events;
        _loading = false;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[RECOMMENDATION] event card load failed: $error');
      appDebugPrint('[RECOMMENDATION] event card stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _recommendations = const <EventRecommendation>[];
        _events = const <Event>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _recommendations.isEmpty || _events.isEmpty) {
      return const SizedBox.shrink();
    }

    return EventRecommendationSection(
      events: _events,
      recommendations: _recommendations,
      onEventTap: (event) {
        widget.onEventTap?.call(event);
      },
    );
  }
}
