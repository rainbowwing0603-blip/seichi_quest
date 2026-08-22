import 'package:flutter/material.dart';

/// 聖地クエストの実績定義。
/// 現在の獲得数だけを入力すれば、進捗と解除状態を一貫して扱える。
class QuestAchievement {
  final String id;
  final String title;
  final String description;
  final int requiredCount;
  final IconData icon;

  const QuestAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredCount,
    required this.icon,
  });

  bool isUnlocked(int collectedCount) => collectedCount >= requiredCount;

  double progress(int collectedCount) {
    if (requiredCount <= 0) return 1;
    return (collectedCount / requiredCount).clamp(0.0, 1.0);
  }
}

const questAchievements = <QuestAchievement>[
  QuestAchievement(
    id: 'first_stamp',
    title: '最初の一歩',
    description: '最初の聖地を獲得する',
    requiredCount: 1,
    icon: Icons.location_on_rounded,
  ),
  QuestAchievement(
    id: 'collector_10',
    title: 'コレクター',
    description: '10個の聖地を獲得する',
    requiredCount: 10,
    icon: Icons.emoji_events_rounded,
  ),
  QuestAchievement(
    id: 'gunma_explorer_25',
    title: '群馬探訪',
    description: '25個の聖地を獲得する',
    requiredCount: 25,
    icon: Icons.map_rounded,
  ),
  QuestAchievement(
    id: 'complete_44',
    title: '完全制覇',
    description: '44個すべての聖地を獲得する',
    requiredCount: 44,
    icon: Icons.workspace_premium_rounded,
  ),
];

class AchievementProgressCard extends StatelessWidget {
  final QuestAchievement achievement;
  final int collectedCount;

  const AchievementProgressCard({
    super.key,
    required this.achievement,
    required this.collectedCount,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked(collectedCount);
    final progress = achievement.progress(collectedCount);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked
                    ? const Color(0xFFE6F6E9)
                    : Colors.grey.shade100,
              ),
              child: Icon(
                achievement.icon,
                color: unlocked ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (unlocked)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 21,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${collectedCount.clamp(0, achievement.requiredCount)} / ${achievement.requiredCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
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
}
