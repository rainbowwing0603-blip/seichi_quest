import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/quest_item.dart';
import '../services/achievement_service.dart';
import 'quest_ui.dart';

class QuestPage extends StatelessWidget {
  const QuestPage({
    super.key,
    required this.nextSeichi,
    required this.nextDistance,
    required this.collectedCount,
    required this.total,
    required this.onShowDestination,
    required this.onExploreEvents,
    required this.eventAchievements,
  });

  final QuestItem? nextSeichi;
  final double? nextDistance;
  final int collectedCount;
  final int total;
  final VoidCallback onShowDestination;
  final VoidCallback onExploreEvents;
  final List<Achievement> eventAchievements;

  static const AchievementService _achievementService = AchievementService();

  @override
  Widget build(BuildContext context) {
    final sortedAchievements = List<Achievement>.from(eventAchievements)
      ..sort((a, b) {
        final aCompleted = _achievementService.isUnlocked(a, collectedCount);
        final bCompleted = _achievementService.isUnlocked(b, collectedCount);

        if (aCompleted != bCompleted) {
          return aCompleted ? 1 : -1;
        }

        return a.requiredCount.compareTo(b.requiredCount);
      });

    final safeTotal = total < 0 ? 0 : total;
    final safeCollected = collectedCount.clamp(0, safeTotal);
    final collectionRatio = safeTotal == 0 ? 0.0 : safeCollected / safeTotal;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(collected: safeCollected, totalCount: safeTotal),
            const SizedBox(height: 14),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onExploreEvents,
              child: QuestGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: QuestUiTokens.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.explore_rounded,
                        color: QuestUiTokens.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'クエストを探す',
                            style: TextStyle(
                              color: QuestUiTokens.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '新しい冒険や参加中のクエストを見つけよう',
                            style: TextStyle(
                              color: QuestUiTokens.mutedInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: QuestUiTokens.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (total == 0)
              _buildEmptyQuestCard()
            else if (nextQuestItem != null)
              _buildQuestMainCard(nextSeichi!)
            else
              _buildAllClearCard(),
            const SizedBox(height: 26),
            _buildChallengeHeader(sortedAchievements),
            const SizedBox(height: 12),
            if (sortedAchievements.isEmpty)
              _buildNoAchievementCard()
            else
              ...sortedAchievements.map(_buildAchievementTile),
            const SizedBox(height: 8),
            _buildJourneyProgress(
              collected: safeCollected,
              totalCount: safeTotal,
              ratio: collectionRatio,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader({required int collected, required int totalCount}) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: QuestUiTokens.primaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: QuestUiTokens.primary.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUEST',
                style: TextStyle(
                  color: QuestUiTokens.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '次の聖地を目指そう',
                style: TextStyle(
                  color: QuestUiTokens.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        QuestStatusChip(
          label: '$collected / $totalCount',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    );
  }

  Widget _buildQuestMainCard(QuestItem seichi) {
    final distance = nextDistance;

    return QuestGlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(QuestUiTokens.contentKeyRadius),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      QuestUiTokens.primary.withValues(alpha: 0.20),
                      QuestUiTokens.primary.withValues(alpha: 0.00),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -80,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      QuestUiTokens.cyan.withValues(alpha: 0.14),
                      QuestUiTokens.cyan.withValues(alpha: 0.00),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.navigation_rounded,
                        size: 16,
                        color: QuestUiTokens.primary,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'NEXT QUEST',
                        style: TextStyle(
                          color: QuestUiTokens.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE9E9FF), Color(0xFFF7F7FF)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: QuestUiTokens.primary.withValues(
                              alpha: 0.16,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: QuestUiTokens.primary.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Text(
                          seichi.icon,
                          style: const TextStyle(fontSize: 38),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seichi.contentKey,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: QuestUiTokens.mutedInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              seichi.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: QuestUiTokens.ink,
                                fontSize: 22,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: QuestUiTokens.cyan.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: QuestUiTokens.cyanGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.near_me_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CURRENT DISTANCE',
                                style: TextStyle(
                                  color: QuestUiTokens.mutedInk,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                distance == null
                                    ? '現在地を取得中…'
                                    : '現在地から ${_formatDistance(distance)}',
                                style: const TextStyle(
                                  color: QuestUiTokens.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  QuestPrimaryButton(
                    label: '目的地を見る',
                    icon: Icons.explore_rounded,
                    onPressed: onShowDestination,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyQuestCard() {
    return const QuestGlassCard(
      child: Column(
        children: [
          _QuestStateIcon(emoji: '🗺️'),
          SizedBox(height: 14),
          Text(
            '準備中',
            style: TextStyle(
              color: QuestUiTokens.ink,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'このクエストには聖地が登録されていません。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllClearCard() {
    return const QuestGlassCard(
      child: Column(
        children: [
          _QuestStateIcon(emoji: '🏆', completed: true),
          SizedBox(height: 14),
          Text(
            '完全制覇！',
            style: TextStyle(
              color: QuestUiTokens.ink,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            '登録されている聖地をすべて獲得しました。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeHeader(List<Achievement> achievements) {
    final completedCount = achievements
        .where(
          (achievement) =>
              _achievementService.isUnlocked(achievement, collectedCount),
        )
        .length;

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHALLENGES',
                style: TextStyle(
                  color: QuestUiTokens.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'チャレンジ',
                style: TextStyle(
                  color: QuestUiTokens.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (achievements.isNotEmpty)
          QuestStatusChip(
            label: '$completedCount / ${achievements.length}',
            icon: Icons.emoji_events_rounded,
            accentColor: QuestUiTokens.cyan,
          ),
      ],
    );
  }

  Widget _buildNoAchievementCard() {
    return QuestGlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: QuestUiTokens.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              size: 28,
              color: QuestUiTokens.primary.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'このクエストにはチャレンジがありません',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuestUiTokens.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'クエストを楽しみながら、次のチャレンジを探してみよう！',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementTile(Achievement achievement) {
    final progress = collectedCount.clamp(0, achievement.requiredCount);
    final completed = _achievementService.isUnlocked(
      achievement,
      collectedCount,
    );
    final ratio = _achievementService.getProgress(achievement, collectedCount);

    final accent = completed ? const Color(0xFF24A77A) : QuestUiTokens.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: QuestGlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: completed
                  ? Icon(Icons.check_rounded, color: accent, size: 27)
                  : Text(
                      achievement.icon,
                      style: const TextStyle(fontSize: 26),
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: QuestUiTokens.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$progress/${achievement.requiredCount}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    achievement.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: QuestUiTokens.mutedInk,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: accent.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyProgress({
    required int collected,
    required int totalCount,
    required double ratio,
  }) {
    return QuestGlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: QuestUiTokens.primaryGradient,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '冒険の進行度',
                        style: TextStyle(
                          color: QuestUiTokens.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '$collected / $totalCount',
                      style: const TextStyle(
                        color: QuestUiTokens.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    backgroundColor: QuestUiTokens.primary.withValues(
                      alpha: 0.10,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      QuestUiTokens.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    }

    return '${(distance / 1000).toStringAsFixed(1)}km';
  }
}

class _QuestStateIcon extends StatelessWidget {
  const _QuestStateIcon({required this.emoji, this.completed = false});

  final String emoji;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final accent = completed ? const Color(0xFFFFB547) : QuestUiTokens.primary;

    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.13), blurRadius: 20),
        ],
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 46)),
    );
  }
}
