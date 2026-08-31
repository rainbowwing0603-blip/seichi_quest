import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class RankingPage extends StatefulWidget {
  final int myCount;
  final int total;

  const RankingPage({
    super.key,
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

  supabase.SupabaseClient get _client =>
      supabase.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    try {
      final data = await _client.rpc(
        'get_public_ranking',
        params: {
          'p_limit': 50,
        },
      );

      final rows = (data as List)
          .map(
            (item) => _RankingEntry.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _ranking = rows;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(
                title: 'ランキング',
                subtitle: '聖地巡礼の記録',
                icon: Icons.leaderboard,
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'あなたの記録',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.myCount} / ${widget.total}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '聖地獲得数',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'オンラインランキング',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildRankingContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankingContent() {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _refreshRanking,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    if (_ranking.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.leaderboard_outlined,
              size: 40,
              color: Colors.grey,
            ),
            SizedBox(height: 10),
            Text(
              'まだランキング参加者がいません。',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'プロフィールで表示名を設定すると参加できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final entry in _ranking)
          _buildRankingRow(
            rank: entry.rank,
            name: entry.displayName,
            count: entry.collectedCount,
            isMe: entry.isMe,
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '表示名を設定したユーザーのみランキングに表示されます。',
                  style: TextStyle(
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankingRow({
    required int rank,
    required String name,
    required int count,
    required bool isMe,
  }) {
    String rankIcon;

    if (rank == 1) {
      rankIcon = '🥇';
    } else if (rank == 2) {
      rankIcon = '🥈';
    } else if (rank == 3) {
      rankIcon = '🥉';
    } else {
      rankIcon = '🏅';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.deepPurple.withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isMe
            ? Border.all(
                color: Colors.deepPurple.withValues(alpha: 0.35),
                width: 1.5,
              )
            : null,
      ),
      child: Row(
        children: [
          Text(
            rankIcon,
            style: const TextStyle(
              fontSize: 26,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'あなた',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
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
      padding: const EdgeInsets.fromLTRB(
        8,
        12,
        8,
        18,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6A35C8),
                  Color(0xFF8B5CF6),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankingEntry {
  final int rank;
  final String displayName;
  final int collectedCount;
  final bool isMe;

  const _RankingEntry({
    required this.rank,
    required this.displayName,
    required this.collectedCount,
    required this.isMe,
  });

  factory _RankingEntry.fromMap(
    Map<String, dynamic> map,
  ) {
    return _RankingEntry(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      displayName: map['display_name']?.toString() ?? '',
      collectedCount:
          (map['collected_count'] as num?)?.toInt() ?? 0,
      isMe: map['is_me'] == true,
    );
  }
}