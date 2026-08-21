import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MissionDefinition {
  final String id;
  final String title;
  final String description;
  final int target;
  final int reward;
  final IconData icon;
  const MissionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.reward,
    required this.icon,
  });
}

const missionDefinitions = <MissionDefinition>[
  MissionDefinition(
    id: 'visit_1',
    title: '最初の一歩',
    description: '聖地を1か所訪問する',
    target: 1,
    reward: 10,
    icon: Icons.location_on_rounded,
  ),
  MissionDefinition(
    id: 'visit_3',
    title: '巡礼ビギナー',
    description: '聖地を3か所訪問する',
    target: 3,
    reward: 30,
    icon: Icons.explore_rounded,
  ),
  MissionDefinition(
    id: 'stamp_1',
    title: '最初の札',
    description: '札を1枚獲得する',
    target: 1,
    reward: 10,
    icon: Icons.style_rounded,
  ),
  MissionDefinition(
    id: 'stamp_5',
    title: '札コレクター',
    description: '札を5枚獲得する',
    target: 5,
    reward: 50,
    icon: Icons.collections_bookmark_rounded,
  ),
  MissionDefinition(
    id: 'stamp_10',
    title: '巡礼ハンター',
    description: '札を10枚獲得する',
    target: 10,
    reward: 100,
    icon: Icons.emoji_events_rounded,
  ),
  MissionDefinition(
    id: 'stamp_20',
    title: '群馬探訪者',
    description: '札を20枚獲得する',
    target: 20,
    reward: 200,
    icon: Icons.map_rounded,
  ),
  MissionDefinition(
    id: 'stamp_44',
    title: '完全制覇への道',
    description: '札を44枚すべて獲得する',
    target: 44,
    reward: 1000,
    icon: Icons.workspace_premium_rounded,
  ),
];

class MissionPage extends StatefulWidget {
  final int collectedCount;
  final int visitedCount;
  const MissionPage({
    super.key,
    required this.collectedCount,
    required this.visitedCount,
  });
  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> {
  static const _xpKey = 'mission_xp';
  static const _claimedKey = 'mission_claimed';
  int _xp = 0;
  final Set<String> _claimed = {};
  late int _daySeed;

  @override
  void initState() {
    super.initState();
    _daySeed = DateTime.now().difference(DateTime(2020)).inDays;
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _xp = p.getInt(_xpKey) ?? 0;
      _claimed.addAll(p.getStringList(_claimedKey) ?? const []);
    });
  }

  Future<void> _claim(MissionDefinition mission) async {
    if (_claimed.contains(mission.id) || !_completed(mission)) return;
    final p = await SharedPreferences.getInstance();
    setState(() {
      _claimed.add(mission.id);
      _xp += mission.reward;
    });
    await p.setInt(_xpKey, _xp);
    await p.setStringList(_claimedKey, _claimed.toList());
  }

  int _progress(MissionDefinition m) {
    if (m.id.startsWith('visit_')) return widget.visitedCount;
    return widget.collectedCount;
  }

  bool _completed(MissionDefinition m) => _progress(m) >= m.target;

  @override
  Widget build(BuildContext context) {
    final daily = missionDefinitions[_daySeed % missionDefinitions.length];
    return Scaffold(
      appBar: AppBar(title: const Text('ミッション')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _summary(context),
          const SizedBox(height: 16),
          _sectionTitle('今日のおすすめ'),
          _missionCard(context, daily, highlighted: true),
          const SizedBox(height: 16),
          _sectionTitle('ミッション一覧'),
          for (final mission in missionDefinitions)
            _missionCard(context, mission),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                '$_xp',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ミッションXP', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 3),
                  Text(
                    '$_xp XP',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_claimed.length} / ${missionDefinitions.length}\n達成',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    ),
  );

  Widget _missionCard(
    BuildContext context,
    MissionDefinition mission, {
    bool highlighted = false,
  }) {
    final progress = _progress(mission).clamp(0, mission.target);
    final completed = _completed(mission);
    final claimed = _claimed.contains(mission.id);
    final ratio = mission.target == 0 ? 1.0 : progress / mission.target;
    return Card(
      elevation: highlighted ? 3 : 1,
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
                      Text(
                        mission.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(mission.description),
                    ],
                  ),
                ),
                Text(
                  '+${mission.reward} XP',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: ratio, minHeight: 8),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$progress / ${mission.target}'),
                Text(
                  completed
                      ? (claimed ? '報酬受取済み' : '達成！')
                      : '${(ratio * 100).round()}%',
                ),
              ],
            ),
            if (completed && !claimed) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _claim(mission),
                  icon: const Icon(Icons.card_giftcard_rounded),
                  label: Text('${mission.reward} XPを受け取る'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
