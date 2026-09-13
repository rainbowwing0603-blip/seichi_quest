import 'package:flutter/material.dart';

import '../models/event.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    this.collectedCount,
    this.totalCount,
    this.participationLabel = '選択中',
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onSelectAnotherEvent,
  });

  final Event event;

  final int? collectedCount;
  final int? totalCount;

  final String participationLabel;

  final String? primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;

  final Future<void> Function()? onSelectAnotherEvent;

  @override
  State<EventDetailPage> createState() =>
      _EventDetailPageState();
}

class _EventDetailPageState
    extends State<EventDetailPage> {
  bool _isActionRunning = false;

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '未設定';
    }

    final local = value.toLocal();

    final year = local.year.toString();
    final month =
        local.month.toString().padLeft(2, '0');
    final day =
        local.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  String _periodText() {
    if (widget.event.startAt == null &&
        widget.event.endAt == null) {
      return '開催期間の設定なし';
    }

    if (widget.event.startAt != null &&
        widget.event.endAt != null) {
      return '${_formatDate(widget.event.startAt)}'
          ' 〜 '
          '${_formatDate(widget.event.endAt)}';
    }

    if (widget.event.startAt != null) {
      return '${_formatDate(widget.event.startAt)} 〜';
    }

    return '〜 ${_formatDate(widget.event.endAt)}';
  }

  String _eventStatusText() {
    final now = DateTime.now();

    final startAt =
        widget.event.startAt?.toLocal();
    final endAt =
        widget.event.endAt?.toLocal();

    if (startAt != null &&
        now.isBefore(startAt)) {
      return '開催前';
    }

    if (endAt != null &&
        now.isAfter(endAt)) {
      return '終了';
    }

    return '開催中';
  }

  Color _participationColor() {
    switch (widget.participationLabel) {
      case '選択中':
        return Colors.deepPurple;

      case '参加中':
        return Colors.green;

      case '過去に参加':
        return Colors.orange;

      case '未参加':
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }

  bool get _hasProgress {
    return widget.collectedCount != null &&
        widget.totalCount != null;
  }

  double get _progress {
    final collected = widget.collectedCount;
    final total = widget.totalCount;

    if (collected == null ||
        total == null ||
        total <= 0) {
      return 0;
    }

    return (collected / total)
        .clamp(0.0, 1.0);
  }

  int get _progressPercent {
    return (_progress * 100).round();
  }

  Future<void> _runPrimaryAction() async {
    final action = widget.onPrimaryAction;

    if (action == null ||
        _isActionRunning) {
      return;
    }

    setState(() {
      _isActionRunning = true;
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isActionRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final participationColor =
        _participationColor();

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: const Text('クエスト詳細'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            28,
          ),
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration:
                            BoxDecoration(
                          color: Colors
                              .deepPurple
                              .withValues(
                            alpha: 0.08,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(16),
                        ),
                        child: const Icon(
                          Icons.explore_outlined,
                          color:
                              Colors.deepPurple,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              widget.event.name,
                              style:
                                  const TextStyle(
                                fontSize: 21,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildStatusChip(
                                  _eventStatusText(),
                                  Colors.green,
                                ),
                                _buildStatusChip(
                                  widget
                                      .participationLabel,
                                  participationColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.event.description
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 20,
                    ),
                    Text(
                      widget.event.description,
                      style: TextStyle(
                        height: 1.6,
                        color:
                            Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    '開催情報',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons
                            .calendar_month_outlined,
                        size: 20,
                        color:
                            Colors.grey.shade600,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Text(
                          _periodText(),
                          style: TextStyle(
                            color: Colors
                                .grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_hasProgress) ...[
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '進捗',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.collectedCount}'
                            ' / '
                            '${widget.totalCount}',
                            style:
                                const TextStyle(
                              fontSize: 24,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                        Text(
                          '$_progressPercent%',
                          style:
                              const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        999,
                      ),
                      child:
                          LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (widget.primaryActionLabel !=
                    null &&
                widget.onPrimaryAction !=
                    null) ...[
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isActionRunning
                      ? null
                      : _runPrimaryAction,
                  icon: _isActionRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons
                              .play_arrow_rounded,
                        ),
                  label: Text(
                    widget
                        .primaryActionLabel!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            if (widget.onSelectAnotherEvent !=
                null) ...[
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget
                        .onSelectAnotherEvent!();
                  },
                  icon: const Icon(
                    Icons.swap_horiz,
                  ),
                  label: const Text(
                    '別のクエストを見る',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.09),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight:
              FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}