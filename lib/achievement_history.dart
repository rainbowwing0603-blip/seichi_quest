import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievement_system.dart';

class AchievementHistoryEntry {
  final String seichiId;
  final String card;
  final String name;
  final String icon;
  final DateTime collectedAt;

  const AchievementHistoryEntry({
    required this.seichiId,
    required this.card,
    required this.name,
    required this.icon,
    required this.collectedAt,
  });

  Map<String, dynamic> toJson() => {
        'seichiId': seichiId,
        'card': card,
        'name': name,
        'icon': icon,
        'collectedAt': collectedAt.toIso8601String(),
      };

  factory AchievementHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AchievementHistoryEntry(
      seichiId: json['seichiId']?.toString() ?? '',
      card: json['card']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '📍',
      collectedAt: DateTime.tryParse(json['collectedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AchievementHistoryStore {
  static const _historyKey = 'achievement_collection_history_v1';
  static const _unlockedKey = 'achievement_unlocked_ids_v1';

  static Future<List<AchievementHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? <String>[];
    return raw
        .map((value) {
          try {
            return AchievementHistoryEntry.fromJson(
              Map<String, dynamic>.from(jsonDecode(value) as Map),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<AchievementHistoryEntry>()
        .toList();
  }

  static Future<List<String>> recordCollection({
    required String seichiId,
    required String card,
    required String name,
    required String icon,
    required int collectedCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();

    if (!history.any((entry) => entry.seichiId == seichiId)) {
      history.insert(
        0,
        AchievementHistoryEntry(
          seichiId: seichiId,
          card: card,
          name: name,
          icon: icon,
          collectedAt: DateTime.now(),
        ),
      );

      await prefs.setStringList(
        _historyKey,
        history.map((entry) => jsonEncode(entry.toJson())).toList(),
      );
    }

    final unlocked =
        prefs.getStringList(_unlockedKey)?.toSet() ?? <String>{};
    final newlyUnlocked = <String>[];

    for (final achievement in questAchievements) {
      if (achievement.isUnlocked(collectedCount) &&
          unlocked.add(achievement.id)) {
        newlyUnlocked.add(achievement.id);
      }
    }

    await prefs.setStringList(_unlockedKey, unlocked.toList());
    return newlyUnlocked;
  }

  static QuestAchievement achievementById(String id) {
    return questAchievements.firstWhere(
      (achievement) => achievement.id == id,
      orElse: () => questAchievements.first,
    );
  }
}

class AchievementHistoryPage extends StatefulWidget {
  const AchievementHistoryPage({super.key});

  @override
  State<AchievementHistoryPage> createState() =>
      _AchievementHistoryPageState();
}

class _AchievementHistoryPageState extends State<AchievementHistoryPage> {
  List<AchievementHistoryEntry> _history = const [];
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await AchievementHistoryStore.loadHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _count = history.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('実績・獲得履歴'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '実績',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final achievement in questAchievements)
                      AchievementProgressCard(
                        achievement: achievement,
                        collectedCount: _count,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '獲得履歴',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (_history.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('まだ獲得履歴がありません。聖地を訪れてみよう！'),
                ),
              )
            else
              for (final entry in _history)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        entry.icon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    title: Text('${entry.card}  ${entry.name}'),
                    subtitle: Text(_formatDate(entry.collectedAt)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class AchievementUnlockDialog extends StatelessWidget {
  final List<String> achievementIds;

  const AchievementUnlockDialog({
    super.key,
    required this.achievementIds,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.workspace_premium_rounded),
          SizedBox(width: 8),
          Text('実績解除！'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final id in achievementIds) ...[
            Builder(
              builder: (context) {
                final achievement =
                    AchievementHistoryStore.achievementById(id);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(achievement.icon),
                  ),
                  title: Text(achievement.title),
                  subtitle: Text(achievement.description),
                );
              },
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
