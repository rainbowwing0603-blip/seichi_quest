import 'package:flutter/material.dart';

import '../models/event.dart';

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    required this.collectedCount,
    required this.totalCount,
    required this.onSelectAnotherEvent,
  });

  final Event event;
  final int collectedCount;
  final int totalCount;
  final Future<void> Function() onSelectAnotherEvent;

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '未設定';
    }

    final local = value.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  String _periodText() {
    if (event.startAt == null && event.endAt == null) {
      return '開催期間の設定なし';
    }

    if (event.startAt != null && event.endAt != null) {
      return '${_formatDate(event.startAt)} 〜 ${_formatDate(event.endAt)}';
    }

    if (event.startAt != null) {
      return '${_formatDate(event.startAt)} 〜';
    }

    return '〜 ${_formatDate(event.endAt)}';
  }

  String _statusText() {
    final now = DateTime.now();
    final startAt = event.startAt?.toLocal();
    final endAt = event.endAt?.toLocal();

    if (startAt != null && now.isBefore(startAt)) {
      return '開催前';
    }

    if (endAt != null && now.isAfter(endAt)) {
      return '終了';
    }

    if (startAt == null && endAt == null) {
      return '開催中';
    }

    return '開催中';
  }

  double get _progress {
    if (totalCount <= 0) {
      return 0;
    }

    return (collectedCount / totalCount).clamp(0.0, 1.0);
  }

  int get _progressPercent {
    return (_progress * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: const Text('クエスト詳細'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.explore_outlined,
                          color: Colors.deepPurple,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.name,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _statusText(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      event.description,
                      style: TextStyle(
                        height: 1.6,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '開催情報',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _periodText(),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '進捗',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$collectedCount / $totalCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '$_progressPercent%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await onSelectAnotherEvent();
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('別のクエストを選ぶ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}