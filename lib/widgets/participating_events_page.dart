import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class ParticipatingEventsPage extends StatefulWidget {
  const ParticipatingEventsPage({
    super.key,
    required this.currentEventId,
  });

  final String? currentEventId;

  @override
  State<ParticipatingEventsPage> createState() =>
      _ParticipatingEventsPageState();
}

class _ParticipatingEventsPageState
    extends State<ParticipatingEventsPage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<_ParticipatingEvent> _events = [];

  supabase.SupabaseClient get _client =>
      supabase.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadParticipatingEvents();
  }

  Future<void> _loadParticipatingEvents() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _events = [];
        });

        return;
      }

      final data = await _client
          .from('user_event_participations')
          .select(
            'event_id, joined_at, '
            'events(id, name, description)',
          )
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('joined_at');

      final rows = List<Map<String, dynamic>>.from(data);

      final events = <_ParticipatingEvent>[];

      for (final row in rows) {
        final eventData = row['events'];

        if (eventData is! Map) {
          continue;
        }

        final eventMap =
            Map<String, dynamic>.from(eventData);

        final eventId =
            row['event_id']?.toString() ??
                eventMap['id']?.toString() ??
                '';

        if (eventId.isEmpty) {
          continue;
        }

        events.add(
          _ParticipatingEvent(
            id: eventId,
            name:
                eventMap['name']?.toString() ??
                    '名称未設定',
            description:
                eventMap['description']
                        ?.toString() ??
                    '',
            joinedAt: DateTime.tryParse(
              row['joined_at']?.toString() ??
                  '',
            )?.toLocal(),
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[EVENT] participating events load failed: $error',
      );
      debugPrint(
        '[EVENT] participating events stackTrace: $stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            '参加中クエストを読み込めませんでした。';
      });
    }
  }

  String _formatJoinedAt(DateTime? date) {
    if (date == null) {
      return '参加日不明';
    }

    final year = date.year.toString();
    final month =
        date.month.toString().padLeft(2, '0');
    final day =
        date.day.toString().padLeft(2, '0');

    return '$year/$month/$day 参加';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: const Text('参加中クエスト'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadParticipatingEvents,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics:
            AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 180),
          Center(
            child:
                CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed:
                  _loadParticipatingEvents,
              icon:
                  const Icon(Icons.refresh),
              label:
                  const Text('再読み込み'),
            ),
          ),
        ],
      );
    }

    if (_events.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          Icon(
            Icons.flag_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 18),
          const Text(
            '参加中のクエストはありません',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'クエストを選択すると、ここに参加中クエストとして表示されます。',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              color: Colors.grey.shade600,
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
        for (final event in _events)
          _buildEventCard(event),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.deepPurple
                  .withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'あなたのクエスト',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_events.length}件に参加中',
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
    _ParticipatingEvent event,
  ) {
    final isCurrent =
        event.id == widget.currentEventId;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: isCurrent
            ? Border.all(
                color: Colors.deepPurple
                    .withValues(
                  alpha: 0.35,
                ),
                width: 1.5,
              )
            : null,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isCurrent
                ? Colors.deepPurple
                    .withValues(alpha: 0.12)
                : Colors.grey
                    .withValues(alpha: 0.08),
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: Icon(
            isCurrent
                ? Icons.explore
                : Icons.explore_outlined,
            color: isCurrent
                ? Colors.deepPurple
                : Colors.grey.shade700,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.name,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            if (isCurrent)
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    999,
                  ),
                ),
                child: const Text(
                  '選択中',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (event.description.isNotEmpty)
                Text(
                  event.description,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              if (event.description.isNotEmpty)
                const SizedBox(height: 5),
              Text(
                _formatJoinedAt(
                  event.joinedAt,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        trailing: isCurrent
            ? const Icon(
                Icons.check_circle,
                color: Colors.deepPurple,
              )
            : const Icon(
                Icons.chevron_right,
              ),
        onTap: isCurrent
            ? null
            : () {
                Navigator.of(context)
                    .pop(event.id);
              },
      ),
    );
  }
}

class _ParticipatingEvent {
  const _ParticipatingEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.joinedAt,
  });

  final String id;
  final String name;
  final String description;
  final DateTime? joinedAt;
}