import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/event_recommendation.dart';
import 'quest_ui.dart';

class EventRecommendationSection extends StatelessWidget {
  const EventRecommendationSection({
    super.key,
    required this.events,
    required this.recommendations,
    this.onEventTap,
  });

  final List<Event> events;
  final List<EventRecommendation> recommendations;
  final ValueChanged<Event>? onEventTap;

  @override
  Widget build(BuildContext context) {
    final eventsById = <String, Event>{
      for (final event in events) event.id: event,
    };

    final items = recommendations
        .map(
          (recommendation) => (
            event: eventsById[recommendation.eventId],
            recommendation: recommendation,
          ),
        )
        .where((item) => item.event != null)
        .take(3)
        .toList(growable: false);

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final basis = items.first.recommendation;

    return QuestGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 14),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: QuestUiTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT QUEST',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.primary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'あなたへのおすすめ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            basis.isPersonalized
                ? '${basis.recommendationBasis}の参加実績から、未参加のクエストを選びました。'
                : '参加者の多い未参加クエストから選びました。',
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: QuestUiTokens.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < items.length; index++) ...[
            _RecommendationTile(
              rank: index + 1,
              event: items[index].event!,
              recommendation: items[index].recommendation,
              onTap: () => onEventTap?.call(items[index].event!),
            ),
            if (index != items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.rank,
    required this.event,
    required this.recommendation,
    required this.onTap,
  });

  final int rank;
  final Event event;
  final EventRecommendation recommendation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = recommendation.participationRate;

    return Material(
      color: QuestUiTokens.primary.withValues(alpha: 0.035),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (event.iconUrl != null || event.coverImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    event.iconUrl ?? event.coverImageUrl!,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallbackIcon(),
                  ),
                )
              else
                _fallbackIcon(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rate != null
                          ? '${recommendation.badgeText} ・ 参加率 ${rate.toStringAsFixed(1)}%'
                          : '${recommendation.badgeText} ・ 参加者 ${recommendation.participantCount}人',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: QuestUiTokens.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: QuestUiTokens.primaryGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.explore_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
