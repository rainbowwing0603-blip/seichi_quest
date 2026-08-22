import 'package:flutter/material.dart';

import '../models/stamp_history_entry.dart';

class StampHistoryPage extends StatelessWidget {
  final List<StampHistoryEntry> entries;
  final Map<String, StampHistoryPlace> places;

  const StampHistoryPage({
    super.key,
    required this.entries,
    required this.places,
  });

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('獲得履歴')),
      body: entries.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64),
                  SizedBox(height: 16),
                  Text('まだ獲得履歴はありません'),
                  SizedBox(height: 6),
                  Text('聖地を訪れると、ここに記録されます。'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final place = places[entry.seichiId];
                final title = place?.name ?? '現在は登録されていない聖地';

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(place?.icon ?? '🏆'),
                    ),
                    title: Text(
                      place == null ? title : '${place.card} $title',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('獲得日時 ${_formatDateTime(entry.collectedAt)}'),
                    trailing: const Icon(Icons.verified, color: Colors.green),
                  ),
                );
              },
            ),
    );
  }
}
