import 'package:flutter/material.dart';

/// Mission data used by 聖地クエスト.
/// This module is intentionally independent from the existing map/stamp logic.
class QuestMission {
  final String id;
  final String title;
  final String description;
  final int target;
  final int reward;
  final IconData icon;

  const QuestMission({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.reward,
    required this.icon,
  });

  double progress(int value) => target <= 0 ? 1 : (value / target).clamp(0.0, 1.0);
}

/// Initial mission catalog. Progress can later be connected to Supabase.
const questMissionCatalog = <QuestMission>[
  QuestMission(
    id: 'visit_1',
    title: '最初の一歩',
    description: '聖地を1か所訪問しよう',
    target: 1,
    reward: 10,
    icon: Icons.location_on,
  ),
  QuestMission(
    id: 'visit_3',
    title: '巡礼ビギナー',
    description: '聖地を3か所訪問しよう',
    target: 3,
    reward: 30,
    icon: Icons.explore,
  ),
  QuestMission(
    id: 'stamp_1',
    title: '札を集めよう',
    description: '札を1枚獲得しよう',
    target: 1,
    reward: 10,
    icon: Icons.style,
  ),
  QuestMission(
    id: 'stamp_5',
    title: '札コレクター',
    description: '札を5枚獲得しよう',
    target: 5,
    reward: 50,
    icon: Icons.collections_bookmark,
  ),
  QuestMission(
    id: 'stamp_10',
    title: '巡礼ハンター',
    description: '札を10枚獲得しよう',
    target: 10,
    reward: 100,
    icon: Icons.emoji_events,
  ),
];

/// Reusable mission card. Existing screens can embed this without changing
/// the current navigation structure.
class QuestMissionCard extends StatelessWidget {
  final QuestMission mission;
  final int progress;
  final VoidCallback? onTap;

  const QuestMissionCard({
    super.key,
    required this.mission,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = progress >= mission.target;
    final ratio = mission.progress(progress);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Icon(mission.icon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mission.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(mission.description),
                      ],
                    ),
                  ),
                  if (completed)
                    const Icon(Icons.check_circle, color: Colors.green)
                  else
                    Text('+${mission.reward} XP'),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: ratio, minHeight: 8),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$progress / ${mission.target}'),
                  Text(completed ? '達成済み' : '${(ratio * 100).round()}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
