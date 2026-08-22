from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if "import 'achievement_history.dart';" not in s:
    anchor = "import 'package:flutter/material.dart';\n"
    s = s.replace(anchor, anchor + "import 'achievement_history.dart';\n", 1)

if '_achievementHistoryCount' not in s:
    anchor = "  bool _isCollecting = false;\n"
    insert = """  bool _isCollecting = false;\n\n  int _achievementHistoryCount = 0;\n"""
    s = s.replace(anchor, insert, 1)

if 'AchievementHistoryStore.recordCollection' not in s:
    anchor = "      await _saveStamps();\n\n      if (!mounted) {"
    insert = """      await _saveStamps();\n\n      _achievementHistoryCount = _getCollectedCount();\n      final newlyUnlocked =\n          await AchievementHistoryStore.recordCollection(\n        seichiId: seichi.id,\n        card: seichi.card,\n        name: seichi.name,\n        icon: seichi.icon,\n        collectedCount: _achievementHistoryCount,\n      );\n\n      if (!mounted) {"""
    if anchor not in s:
        raise SystemExit('collection anchor not found')
    s = s.replace(anchor, insert, 1)

    anchor = "      setState(() {\n        _justCollected = true;\n        _collectedName = seichi.name;\n      });\n\n      _updateNextDestination();"
    insert = """      setState(() {\n        _justCollected = true;\n        _collectedName = seichi.name;\n      });\n\n      if (newlyUnlocked.isNotEmpty && mounted) {\n        await showDialog<void>(\n          context: context,\n          builder: (_) => AchievementUnlockDialog(\n            achievementIds: newlyUnlocked,\n          ),\n        );\n      }\n\n      _updateNextDestination();"""
    if anchor not in s:
        raise SystemExit('unlock dialog anchor not found')
    s = s.replace(anchor, insert, 1)

if 'AchievementHistoryPage' not in s:
    anchor = "            _buildMissionTile(\n              icon: Icons.workspace_premium,\n              title: '完全制覇',\n              subtitle:\n                  '44個すべての聖地を獲得する',\n              progress:\n                  math.min(count, 44),\n              total: 44,\n            ),\n"
    insert = anchor + """            const SizedBox(height: 8),\n            SizedBox(\n              width: double.infinity,\n              child: OutlinedButton.icon(\n                onPressed: () {\n                  Navigator.of(context).push(\n                    MaterialPageRoute(\n                      builder: (_) => const AchievementHistoryPage(),\n                    ),\n                  );\n                },\n                icon: const Icon(Icons.workspace_premium_rounded),\n                label: const Text('実績・獲得履歴を見る'),\n              ),\n            ),\n"""
    if anchor not in s:
        raise SystemExit('quest button anchor not found')
    s = s.replace(anchor, insert, 1)

p.write_text(s, encoding='utf-8')
print('achievement integration complete')
