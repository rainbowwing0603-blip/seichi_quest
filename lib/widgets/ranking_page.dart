import 'package:flutter/material.dart';

class RankingPage extends StatelessWidget {
  final int myCount;
  final int total;

  const RankingPage({
    super.key,
    required this.myCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildPageHeader(
              title: 'ランキング',
              subtitle:
                  '聖地巡礼の記録',
              icon:
                  Icons.leaderboard,
            ),
            const SizedBox(
              height: 4,
            ),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                24,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              child:
                  Column(
                children: [
                  const Text(
                    'あなたの記録',
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    '$myCount / $total',
                    style:
                        const TextStyle(
                      fontSize: 42,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  const Text(
                    '聖地獲得数',
                    style:
                        TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'ランキング',
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            _buildRankingRow(
              rank: 1,
              name: '群馬マスター',
              count: 44,
              icon: '🥇',
            ),
            _buildRankingRow(
              rank: 2,
              name: '上毛探訪者',
              count: 32,
              icon: '🥈',
            ),
            _buildRankingRow(
              rank: 3,
              name: '聖地ハンター',
              count: 27,
              icon: '🥉',
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration:
                  BoxDecoration(
                color: Colors
                    .deepPurple
                    .withValues(
                  alpha: 0.07,
                ),
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child:
                  const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      'オンラインランキングは今後実装予定です。',
                      style:
                          TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingRow({
    required int rank,
    required String name,
    required int count,
    required String icon,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Row(
        children: [
          Text(
            icon,
            style:
                const TextStyle(
              fontSize: 26,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Text(
            '$rank',
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Text(
              name,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
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
      padding:
          const EdgeInsets.fromLTRB(
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
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF6A35C8),
                  Color(0xFF8B5CF6),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              icon,
              color:
                  Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
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