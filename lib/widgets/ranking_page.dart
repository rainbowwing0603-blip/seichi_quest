import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'profile_avatar.dart';
import 'quest_ui.dart';

class RankingPage extends StatefulWidget {
  final String eventId;
  final String? displayName;
  final Future<bool> Function() onShowProfile;
  final int? myRank;
  final int myCount;
  final int total;

  const RankingPage({
    super.key,
    required this.eventId,
    required this.displayName,
    required this.onShowProfile,
    required this.myRank,
    required this.myCount,
    required this.total,
  });

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<_RankingEntry> _ranking = [];
  int _participantCount = 0;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  @override
  void didUpdateWidget(covariant RankingPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.eventId != widget.eventId) {
      _refreshRanking();
    }
  }

  Future<void> _loadRanking() async {
    try {
      final data = await _client.rpc(
        'get_public_ranking',
        params: {'p_event_id': widget.eventId, 'p_limit': 50},
      );

      final rows = (data as List)
          .map(
            (item) =>
                _RankingEntry.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      final participantCount = rows.isEmpty ? 0 : rows.first.participantCount;

      if (!mounted) {
        return;
      }

      setState(() {
        _ranking = rows;
        _participantCount = participantCount;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      debugPrint('[RANKING] load failed: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'ランキングを取得できませんでした。';
      });
    }
  }

  Future<void> _refreshRanking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadRanking();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshRanking,
        color: QuestUiTokens.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(
                title: 'ランキング',
                subtitle: _participantCount > 0
                    ? '参加者 $_participantCount人'
                    : '聖地巡礼の記録',
                icon: Icons.leaderboard_rounded,
              ),
              const SizedBox(height: 8),
              _buildMyRecord(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: QuestUiTokens.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      size: 18,
                      color: QuestUiTokens.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RANKING',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.mutedInk,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'オンラインランキング',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_participantCount > 0)
                    QuestStatusChip(
                      label: '$_participantCount人参加',
                      icon: Icons.groups_2_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRankingContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyRecord() {
    final hasDisplayName =
        widget.displayName != null && widget.displayName!.trim().isNotEmpty;

    String statusText;
    String? guidanceText;

    if (widget.myRank != null) {
      statusText = '現在 ${widget.myRank}位';
    } else if (!hasDisplayName) {
      statusText = 'ランキング未参加';
      guidanceText = '表示名を設定するとランキングに参加できます。';
    } else if (widget.myCount == 0) {
      statusText = 'ランキング未参加';
      guidanceText = '聖地を1つ獲得するとランキングに参加できます。';
    } else {
      statusText = '順位を取得できませんでした';
      guidanceText = 'ランキング情報を更新してください。';
    }

    final progress = widget.total <= 0
        ? 0.0
        : (widget.myCount / widget.total).clamp(0.0, 1.0);

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
                  boxShadow: [
                    BoxShadow(
                      color: QuestUiTokens.primary.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.military_tech_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR RECORD',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: widget.myRank == null
                            ? QuestUiTokens.mutedInk
                            : QuestUiTokens.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.myRank != null)
                QuestStatusChip(
                  label: '${widget.myRank}位',
                  icon: Icons.emoji_events_rounded,
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.myCount}',
                style: const TextStyle(
                  fontSize: 42,
                  height: 0.95,
                  fontWeight: FontWeight.w900,
                  color: QuestUiTokens.ink,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 5, bottom: 4),
                child: Text(
                  '/ ${widget.total} 聖地',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: QuestUiTokens.primary.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                QuestUiTokens.primary,
              ),
            ),
          ),
          if (guidanceText != null) ...[
            const SizedBox(height: 14),
            Text(
              guidanceText,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: QuestUiTokens.mutedInk,
              ),
            ),
          ],
          if (!hasDisplayName) ...[
            const SizedBox(height: 16),
            QuestPrimaryButton(
              label: 'プロフィールを設定',
              icon: Icons.person_add_alt_1_outlined,
              onPressed: () async {
                final changed = await widget.onShowProfile();

                if (!mounted || !changed) {
                  return;
                }

                await _refreshRanking();
              },
            ),
          ],
          if (_participantCount > 0) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                const Icon(
                  Icons.groups_2_outlined,
                  size: 16,
                  color: QuestUiTokens.mutedInk,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.myRank == null
                      ? '現在 $_participantCount人が参加中'
                      : '$_participantCount人中 ${widget.myRank}位',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankingContent() {
    if (_isLoading) {
      return const QuestGlassCard(
        padding: EdgeInsets.symmetric(vertical: 42),
        child: Center(
          child: CircularProgressIndicator(color: QuestUiTokens.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return QuestGlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 27,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: QuestUiTokens.ink),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _refreshRanking,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('再読み込み'),
              style: OutlinedButton.styleFrom(
                foregroundColor: QuestUiTokens.primary,
                side: BorderSide(
                  color: QuestUiTokens.primary.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_ranking.isEmpty) {
      return const QuestGlassCard(
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        child: Column(
          children: [
            Icon(
              Icons.leaderboard_outlined,
              size: 42,
              color: QuestUiTokens.mutedInk,
            ),
            SizedBox(height: 12),
            Text(
              'まだランキング参加者がいません。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: QuestUiTokens.ink,
              ),
            ),
            SizedBox(height: 5),
            Text(
              '表示名を設定し、聖地を1つ以上獲得すると参加できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: QuestUiTokens.mutedInk,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final entry in _ranking) _buildRankingRow(entry: entry),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: QuestUiTokens.primary.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: QuestUiTokens.primary.withValues(alpha: 0.08),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: QuestUiTokens.primary,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  '表示名を設定し、聖地を1つ以上獲得したユーザーのみランキングに表示されます。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankingRow({required _RankingEntry entry}) {
    String rankLabel;

    if (entry.rank == 1) {
      rankLabel = '🥇';
    } else if (entry.rank == 2) {
      rankLabel = '🥈';
    } else if (entry.rank == 3) {
      rankLabel = '🥉';
    } else {
      rankLabel = '${entry.rank}';
    }

    final isTopThree = entry.rank >= 1 && entry.rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: entry.isMe
              ? [
                  QuestUiTokens.primary.withValues(alpha: 0.13),
                  QuestUiTokens.cyan.withValues(alpha: 0.06),
                ]
              : [
                  Colors.white.withValues(alpha: 0.82),
                  Colors.white.withValues(alpha: 0.58),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isMe
              ? QuestUiTokens.primary.withValues(alpha: 0.28)
              : QuestUiTokens.primary.withValues(alpha: 0.06),
          width: entry.isMe ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: QuestUiTokens.ink.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTopThree
                  ? Colors.amber.withValues(alpha: 0.10)
                  : QuestUiTokens.primary.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              rankLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTopThree ? 23 : 15,
                fontWeight: FontWeight.w900,
                color: QuestUiTokens.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ProfileAvatar(avatarKey: entry.avatarKey, size: 42, iconSize: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: QuestUiTokens.ink,
                        ),
                      ),
                    ),
                    if (entry.isMe) ...[
                      const SizedBox(width: 7),
                      QuestStatusChip(label: 'あなた', icon: Icons.person_rounded),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.collectedCount}聖地獲得',
                  style: const TextStyle(
                    fontSize: 11,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '${entry.collectedCount}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: QuestUiTokens.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: QuestUiTokens.primaryGradient,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: QuestUiTokens.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SEICHI QUEST',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingEntry {
  final int rank;
  final String displayName;
  final String? avatarKey;
  final int collectedCount;
  final int participantCount;
  final bool isMe;

  const _RankingEntry({
    required this.rank,
    required this.displayName,
    required this.avatarKey,
    required this.collectedCount,
    required this.participantCount,
    required this.isMe,
  });

  factory _RankingEntry.fromMap(Map<String, dynamic> map) {
    return _RankingEntry(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      displayName: map['display_name']?.toString() ?? '',
      avatarKey: map['avatar_key']?.toString(),
      collectedCount: (map['collected_count'] as num?)?.toInt() ?? 0,
      participantCount: (map['participant_count'] as num?)?.toInt() ?? 0,
      isMe: map['is_me'] == true,
    );
  }
}
