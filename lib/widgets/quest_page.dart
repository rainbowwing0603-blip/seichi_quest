import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/seichi.dart';
import '../services/achievement_service.dart';

class QuestPage extends StatelessWidget {
  const QuestPage({
    super.key,
    required this.nextSeichi,
    required this.nextDistance,
    required this.collectedCount,
    required this.total,
    required this.onShowDestination,
    required this.eventAchievements,
  });

  final Seichi? nextSeichi;
  final double? nextDistance;
  final int collectedCount;
  final int total;
  final VoidCallback onShowDestination;
  final List<Achievement> eventAchievements;

  static const AchievementService _achievementService =
      AchievementService();

  @override
  Widget build(BuildContext context) {
    final sortedAchievements =
        List<Achievement>.from(eventAchievements)
          ..sort((a, b) {
            final aCompleted = _achievementService.isUnlocked(
              a,
              collectedCount,
            );
            final bCompleted = _achievementService.isUnlocked(
              b,
              collectedCount,
            );

            if (aCompleted != bCompleted) {
              return aCompleted ? 1 : -1;
            }

            return a.requiredCount.compareTo(b.requiredCount);
          });

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(
              title: 'クエスト',
              subtitle: '次の聖地を目指そう',
              icon: Icons.flag,
            ),
            const SizedBox(height: 4),
            if (total == 0)
              _buildEmptyQuestCard()
            else if (nextSeichi != null)
              _buildQuestMainCard(nextSeichi!)
            else
              _buildAllClearCard(),
            const SizedBox(height: 20),
            const Text(
              'チャレンジ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (sortedAchievements.isEmpty)
              _buildNoAchievementCard()
            else
              ...sortedAchievements.map(
                (achievement) =>
                    _buildAchievementTile(achievement),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        12,
        8,
        18,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF6A35C8),
                  Color(0xFF8B5CF6),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              icon,
              color:
                  Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestMainCard(Seichi seichi) {
    final distance = nextDistance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF24123D),
            Color(0xFF6A35C8),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEXT QUEST',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                seichi.icon,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seichi.card,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      seichi.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.near_me,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    distance == null
                        ? '現在地を取得中…'
                        : '現在地から ${_formatDistance(distance)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onShowDestination,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6A35C8),
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text(
                '目的地を見る',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyQuestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          Text(
            '🗺️',
            style: TextStyle(fontSize: 64),
          ),
          SizedBox(height: 10),
          Text(
            '準備中',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'このクエストには聖地が登録されていません。',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  Widget _buildAllClearCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          Text(
            '🏆',
            style: TextStyle(fontSize: 64),
          ),
          SizedBox(height: 10),
          Text(
            '完全制覇！',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '登録されている聖地をすべて獲得しました。',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoAchievementCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 42,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          const Text(
            'このクエストにはチャレンジがありません',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'クエストを楽しみながら、次のチャレンジを探してみよう！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
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
    final ratio = _achievementService.getProgress(
      achievement,
      collectedCount,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: completed
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.deepPurple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: completed
                ? const Icon(
                    Icons.check,
                    color: Colors.green,
                  )
                : Text(
                    achievement.icon,
                    style: const TextStyle(fontSize: 25),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$progress/${achievement.requiredCount}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
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