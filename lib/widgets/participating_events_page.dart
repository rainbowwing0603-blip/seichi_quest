import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'quest_ui.dart';
import '../services/app_logger.dart';

class ParticipatingEventsPage extends StatefulWidget {
  const ParticipatingEventsPage({super.key, required this.currentEventId});

  final String? currentEventId;

  @override
  State<ParticipatingEventsPage> createState() =>
      _ParticipatingEventsPageState();
}

class _ParticipatingEventsPageState extends State<ParticipatingEventsPage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<_ParticipatingEvent> _events = [];

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

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

        final eventMap = Map<String, dynamic>.from(eventData);

        final eventId =
            row['event_id']?.toString() ?? eventMap['id']?.toString() ?? '';

        if (eventId.isEmpty) {
          continue;
        }

        events.add(
          _ParticipatingEvent(
            id: eventId,
            name: eventMap['name']?.toString() ?? '名称未設定',
            description: eventMap['description']?.toString() ?? '',
            joinedAt: DateTime.tryParse(row['joined_at']?.toString() ?? '')
                ?.toLocal(),
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
      appDebugPrint('[EVENT] participating events load failed: $error');
      appDebugPrint('[EVENT] participating events stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '参加中クエストを読み込めませんでした。';
      });
    }
  }

  Future<void> _confirmLeaveEvent(_ParticipatingEvent event) async {
    if (event.id == widget.currentEventId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('選択中のクエストからは参加解除できません。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('参加をやめますか？'),
              content: Text(
                '「${event.name}」への参加をやめます。\n'
                '獲得済みの記録は削除されません。',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('参加をやめる'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    await _leaveEvent(event);
  }

  Future<void> _leaveEvent(_ParticipatingEvent event) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ログイン情報を取得できませんでした。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (event.id == widget.currentEventId) {
      return;
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _client
          .from('user_event_participations')
          .update({'is_active': false, 'left_at': now, 'updated_at': now})
          .eq('user_id', user.id)
          .eq('event_id', event.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _events = _events
            .where((item) => item.id != event.id)
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${event.name}」への参加をやめました。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT] leave participation failed: $error');
      appDebugPrint('[EVENT] leave participation stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('参加状態を更新できませんでした。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatJoinedAt(DateTime? date) {
    if (date == null) {
      return '参加日不明';
    }

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year/$month/$day 参加';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '参加中クエスト',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: QuestUiTokens.primary,
        onRefresh: _loadParticipatingEvents,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 70, 20, 30),
        children: [
          QuestGlassCard(
            child: const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  color: QuestUiTokens.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
        children: [
          QuestGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 30,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '読み込みに失敗しました',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    height: 1.5,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
                const SizedBox(height: 20),
                QuestPrimaryButton(
                  label: '再読み込み',
                  icon: Icons.refresh_rounded,
                  onPressed: _loadParticipatingEvents,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_events.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
        children: [
          QuestGlassCard(
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    gradient: QuestUiTokens.primaryGradient,
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '参加中のクエストはありません',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'クエストを選択すると、ここからいつでも切り替えられます。',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.55, color: QuestUiTokens.mutedInk),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        for (final event in _events) _buildEventCard(event),
      ],
    );
  }

  Widget _buildHeader() {
    final currentExists = _events.any(
      (event) => event.id == widget.currentEventId,
    );

    return QuestGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: QuestUiTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MY QUESTS',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.35,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'あなたのクエスト',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
              QuestStatusChip(
                label: '${_events.length}件',
                icon: Icons.explore_rounded,
                accentColor: QuestUiTokens.cyan,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: currentExists
                  ? QuestUiTokens.primary.withValues(alpha: 0.045)
                  : QuestUiTokens.ink.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  currentExists
                      ? Icons.navigation_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: currentExists
                      ? QuestUiTokens.primary
                      : QuestUiTokens.mutedInk,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    currentExists ? '選択中のクエストは強調表示されています' : 'クエストをタップして選択できます',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: QuestUiTokens.mutedInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(_ParticipatingEvent event) {
    final isCurrent = event.id == widget.currentEventId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCurrent
              ? null
              : () {
                  Navigator.of(context).pop(event.id);
                },
          borderRadius: BorderRadius.circular(QuestUiTokens.cardRadius),
          child: Ink(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: isCurrent
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.98),
                        QuestUiTokens.primary.withValues(alpha: 0.075),
                      ],
                    )
                  : QuestUiTokens.glassGradient,
              borderRadius: BorderRadius.circular(QuestUiTokens.cardRadius),
              border: Border.all(
                color: isCurrent
                    ? QuestUiTokens.primary.withValues(alpha: 0.26)
                    : QuestUiTokens.ink.withValues(alpha: 0.055),
                width: isCurrent ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: QuestUiTokens.ink.withValues(
                    alpha: isCurrent ? 0.075 : 0.045,
                  ),
                  blurRadius: isCurrent ? 22 : 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: isCurrent
                        ? QuestUiTokens.primaryGradient
                        : QuestUiTokens.cyanGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isCurrent
                        ? Icons.navigation_rounded
                        : Icons.explore_outlined,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              event.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.ink,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            const QuestStatusChip(
                              label: '選択中',
                              icon: Icons.check_circle_rounded,
                            ),
                          ],
                        ],
                      ),
                      if (event.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          event.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            height: 1.45,
                            fontSize: 13,
                            color: QuestUiTokens.mutedInk,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: QuestUiTokens.mutedInk,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _formatJoinedAt(event.joinedAt),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: QuestUiTokens.mutedInk,
                              ),
                            ),
                          ),
                          if (!isCurrent)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              tooltip: 'クエスト操作',
                              color: Colors.white,
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: QuestUiTokens.mutedInk,
                              ),
                              onSelected: (value) async {
                                if (value == 'leave') {
                                  await _confirmLeaveEvent(event);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem<String>(
                                  value: 'leave',
                                  child: Row(
                                    children: [
                                      Icon(Icons.logout_outlined, size: 20),
                                      SizedBox(width: 10),
                                      Text('参加をやめる'),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 22,
                              color: QuestUiTokens.primary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
