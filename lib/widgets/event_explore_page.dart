import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/event.dart';
import 'event_detail_page.dart';

class EventExplorePage extends StatefulWidget {
  const EventExplorePage({
    super.key,
    required this.events,
    required this.currentEventId,
    required this.currentCollectedCount,
    required this.currentTotalCount,
  });

  final List<Event> events;
  final String? currentEventId;
  final int currentCollectedCount;
  final int currentTotalCount;

  @override
  State<EventExplorePage> createState() =>
      _EventExplorePageState();
}

class _EventExplorePageState
    extends State<EventExplorePage> {
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, bool> _participationStates = {};

  supabase.SupabaseClient get _client =>
      supabase.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadParticipationStates();
  }

  Future<void> _loadParticipationStates() async {
    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _participationStates = {};
          _isLoading = false;
        });

        return;
      }

      final data = await _client
          .from('user_event_participations')
          .select('event_id, is_active')
          .eq('user_id', user.id);

      final rows =
          List<Map<String, dynamic>>.from(data);

      final states = <String, bool>{};

      for (final row in rows) {
        final eventId =
            row['event_id']?.toString();

        if (eventId == null ||
            eventId.isEmpty) {
          continue;
        }

        states[eventId] =
            row['is_active'] == true;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _participationStates = states;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[EVENT] explore participation load failed: $error',
      );
      debugPrint(
        '[EVENT] explore participation stackTrace: $stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'クエスト情報を読み込めませんでした。';
      });
    }
  }

  String _participationLabel(
    Event event,
  ) {
    if (event.id == widget.currentEventId) {
      return '選択中';
    }

    if (_participationStates[event.id] == true) {
      return '参加中';
    }

    if (_participationStates.containsKey(
      event.id,
    )) {
      return '過去に参加';
    }

    return '未参加';
  }

  Color _statusColor(
    String label,
  ) {
    switch (label) {
      case '選択中':
        return Colors.deepPurple;

      case '参加中':
        return Colors.green;

      case '過去に参加':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(
    String label,
  ) {
    switch (label) {
      case '選択中':
        return Icons.check_circle;

      case '参加中':
        return Icons.flag_outlined;

      case '過去に参加':
        return Icons.history_outlined;

      default:
        return Icons.add_circle_outline;
    }
  }

  String? _primaryActionLabel(
    String label,
  ) {
    switch (label) {
      case '参加中':
        return 'このクエストを選ぶ';

      case '過去に参加':
        return '再参加して選ぶ';

      case '未参加':
        return '参加して選ぶ';

      default:
        return null;
    }
  }

  Future<void> _openEventDetail(
    Event event,
  ) async {
    final label =
        _participationLabel(event);

    final actionLabel =
        _primaryActionLabel(label);

    final isCurrent =
        event.id == widget.currentEventId;

    final changed =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          event: event,
          participationLabel: label,
          collectedCount: isCurrent
              ? widget.currentCollectedCount
              : null,
          totalCount: isCurrent
              ? widget.currentTotalCount
              : null,
          primaryActionLabel: actionLabel,
          onPrimaryAction: actionLabel == null
              ? null
              : () async {},
        ),
      ),
    );

    if (!mounted ||
        changed != true) {
      return;
    }

    Navigator.of(context).pop(event.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: const Text('クエストを探す'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadParticipationStates,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          Icon(
            Icons.cloud_off_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed:
                  _loadParticipationStates,
              icon:
                  const Icon(Icons.refresh),
              label:
                  const Text('再読み込み'),
            ),
          ),
        ],
      );
    }

    if (widget.events.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          Icon(
            Icons.explore_off_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            '公開中のクエストはありません',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        28,
      ),
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        for (final event in widget.events)
          _buildEventCard(event),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.deepPurple
                  .withValues(alpha: 0.09),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.travel_explore,
              color: Colors.deepPurple,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  '新しいクエストを見つけよう',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.events.length}件のクエストを公開中',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    Event event,
  ) {
    final label =
        _participationLabel(event);

    final color =
        _statusColor(label);

    final icon =
        _statusIcon(label);

    final description =
        event.description.trim();

    return Container(
      margin:
          const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: label == '選択中'
            ? Border.all(
                color: Colors.deepPurple
                    .withValues(alpha: 0.30),
                width: 1.5,
              )
            : null,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(20),
        onTap: () {
          _openEventDetail(event);
        },
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: 0.09,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: Icon(
                  Icons.explore_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style:
                                const TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                color.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              999,
                            ),
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 13,
                                color: color,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              Text(
                                label,
                                style:
                                    TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        description,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: TextStyle(
                          height: 1.4,
                          color: Colors
                              .grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons
                              .visibility_outlined,
                          size: 15,
                          color: Colors
                              .grey.shade500,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          '詳細を見る',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors
                                .grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}