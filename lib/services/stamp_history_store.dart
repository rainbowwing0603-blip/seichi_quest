import 'package:shared_preferences/shared_preferences.dart';

import '../models/stamp_history_entry.dart';

class StampHistoryStore {
  static const String key = 'collected_seichi_history';

  static Future<List<StampHistoryEntry>> load(
    SharedPreferences preferences,
  ) async {
    final raw = preferences.getStringList(key) ?? const <String>[];
    final entries = <StampHistoryEntry>[];

    for (final value in raw) {
      final separator = value.lastIndexOf('|');
      if (separator <= 0 || separator >= value.length - 1) {
        continue;
      }

      final id = value.substring(0, separator);
      final timestamp = int.tryParse(value.substring(separator + 1));
      if (timestamp == null) {
        continue;
      }

      entries.add(
        StampHistoryEntry(
          seichiId: id,
          collectedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
        ),
      );
    }

    entries.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
    return entries;
  }

  static Future<void> saveEntry(
    SharedPreferences preferences,
    String seichiId,
    DateTime collectedAt,
  ) async {
    final entries = await load(preferences);
    entries.removeWhere((entry) => entry.seichiId == seichiId);
    entries.add(
      StampHistoryEntry(
        seichiId: seichiId,
        collectedAt: collectedAt,
      ),
    );
    entries.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));

    await preferences.setStringList(
      key,
      entries
          .map(
            (entry) => '${entry.seichiId}|${entry.collectedAt.millisecondsSinceEpoch}',
          )
          .toList(),
    );
  }
}
