import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/achievement_service.dart';
import 'profile_avatar.dart';

class MyPage extends StatelessWidget {
  static const AchievementService _achievementService = AchievementService();

  final String? displayName;
  final String? avatarKey;
  final int? myRank;
  final List<Achievement> eventAchievements;
  final int count;
  final int total;
  final String? currentEventName;
  final String? nextDestinationName;
  final String? nextDestinationCard;
  final String? nextDestinationIcon;
  final double? nextDestinationDistance;
  final VoidCallback onShowNextDestination;
  final VoidCallback onShowCurrentEvent;
  final VoidCallback onShowParticipatingEvents;
  final VoidCallback onShowEventExplore;
  final VoidCallback onShowFavoriteEvents;
  final VoidCallback onSelectEvent;
  final VoidCallback onShowAchievements;
  final VoidCallback onShowRanking;
  final VoidCallback onShowAdventureLog;
  final VoidCallback onShowSyncStatus;
  final VoidCallback onShowProfile;
  final VoidCallback onShowAccount;
  final VoidCallback onShowNotifications;
  final VoidCallback onShowSettings;
  final VoidCallback onShowAbout;

  const MyPage({
    super.key,
    required this.displayName,
    required this.avatarKey,
    required this.myRank,
    required this.eventAchievements,
    required this.count,
    required this.total,
    required this.currentEventName,
    required this.nextDestinationName,
    required this.nextDestinationCard,
    required this.nextDestinationIcon,
    required this.nextDestinationDistance,
    required this.onShowNextDestination,
    required this.onShowCurrentEvent,
    required this.onShowParticipatingEvents,
    required this.onShowEventExplore,
    required this.onShowFavoriteEvents,
    required this.onSelectEvent,
    required this.onShowAchievements,
    required this.onShowRanking,
    required this.onShowAdventureLog,
    required this.onShowSyncStatus,
    required this.onShowProfile,
    required this.onShowAccount,
    required this.onShowNotifications,
    required this.onShowSettings,
    required this.onShowAbout,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0
        ? 0
        : (count / total * 100).round();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          28,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onShowProfile,
                child: _buildProfileHeader(progress),
              ),
            ),
            const SizedBox(height: 14),
            _buildNextDestinationCard(),
            const SizedBox(height: 24),

            _buildSectionTitle(
              'クエスト',
              Icons.explore_outlined,
            ),
            const SizedBox(height: 10),
            _buildSettingsTile(
              icon: Icons.explore_outlined,
              title: '現在のクエスト',
              subtitle:
                  currentEventName ??
                      'クエストを選択',
              onTap: onShowCurrentEvent,
            ),
            _buildSettingsTile(
              icon: Icons.travel_explore,
              title: 'クエストを探す',
              subtitle:
                  '新しいクエストを見つける',
              onTap: onShowEventExplore,
            ),
            _buildSettingsTile(
              icon: Icons.star_outline,
              title: 'お気に入りクエスト',
              subtitle: '★を付けたクエストを見る',
              onTap: onShowFavoriteEvents,
            ),
            _buildSettingsTile(
              icon: Icons.flag_outlined,
              title: '参加中クエスト',
              subtitle:
                  '参加しているクエストを確認・切替',
              onTap: onShowParticipatingEvents,
            ),

            const SizedBox(height: 18),

            _buildSectionTitle(
              '記録',
              Icons.auto_graph_outlined,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onShowAchievements,
              behavior: HitTestBehavior.opaque,
              child: _buildAchievementSummary(),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onShowRanking,
              behavior: HitTestBehavior.opaque,
              child: _buildRankingSummary(),
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              icon: Icons.history_outlined,
              title: '冒険ログ',
              subtitle:
                  'これまでに獲得した札の履歴',
              onTap: onShowAdventureLog,
            ),

            const SizedBox(height: 18),

            _buildSectionTitle(
              '設定・管理',
              Icons.tune,
            ),
            const SizedBox(height: 10),
            _buildSettingsTile(
              icon: Icons.person_outline,
              title: 'プロフィール',
              subtitle:
                  'ユーザー情報を設定',
              onTap: onShowProfile,
            ),
            _buildSettingsTile(
              icon: Icons.manage_accounts_outlined,
              title: 'アカウント',
              subtitle:
                  'データを引き継ぐ',
              onTap: onShowAccount,
            ),
            _buildSettingsTile(
              icon: Icons.notifications_none,
              title: '通知設定',
              subtitle:
                  'お知らせ・到達通知',
              onTap: onShowNotifications,
            ),
            _buildSettingsTile(
              icon: Icons.cloud_sync_outlined,
              title: '同期状態',
              subtitle:
                  '保留中の訪問データを確認',
              onTap: onShowSyncStatus,
            ),
            _buildSettingsTile(
              icon: Icons.settings_outlined,
              title: 'アプリ設定',
              subtitle:
                  '各種設定',
              onTap: onShowSettings,
            ),
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: '聖地クエストについて',
              subtitle:
                  'アプリ情報',
              onTap: onShowAbout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    int progress,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProfileAvatar(
                avatarKey: avatarKey,
                size: 72,
                iconSize: 38,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName ??
                          'ゲストユーザー',
                      style:
                          const TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '聖地クエスト冒険者',
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                    if (myRank != null) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onShowRanking,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                          ),
                          child:
                        Row(
                          children: [
                            const Icon(
                              Icons.leaderboard,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(
                              width: 5,
                            ),
                            Text(
                              'ランキング $myRank位',
                              style:
                                  const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildCompactStat(
                  value: '$count',
                  label: '獲得',
                ),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildCompactStat(
                  value: '$total',
                  label: '登録',
                ),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildCompactStat(
                  value: '$progress%',
                  label: '達成率',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat({
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.deepPurple,
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextDestinationCard() {
    final destinationName =
        nextDestinationName?.trim();

    final hasDestination =
        destinationName != null &&
            destinationName.isNotEmpty;

    if (!hasDestination) {
      final isComplete =
          total > 0 && count >= total;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
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
                color: (isComplete
                        ? Colors.amber
                        : Colors.deepPurple)
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isComplete
                    ? Icons.emoji_events
                    : Icons.explore_outlined,
                color: isComplete
                    ? Colors.amber.shade700
                    : Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    isComplete
                        ? 'このクエストを完全制覇！'
                        : '次の目的地を準備中',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isComplete
                        ? 'すべての聖地を獲得しました'
                        : '位置情報を取得すると候補が表示されます',
                    style: TextStyle(
                      fontSize: 12,
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

    final distance =
        nextDestinationDistance;

    String? distanceText;

    if (distance != null) {
      distanceText = distance < 1000
          ? 'あと ${distance.round()}m'
          : 'あと ${(distance / 1000).toStringAsFixed(1)}km';
    }

    final card =
        nextDestinationCard?.trim();

    final icon =
        nextDestinationIcon?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(20),
        onTap: onShowNextDestination,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.deepPurple
                      .withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Text(
                  icon == null ||
                          icon.isEmpty
                      ? '📍'
                      : icon,
                  style: const TextStyle(
                    fontSize: 25,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '次の目的地',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      card == null ||
                              card.isEmpty
                          ? destinationName
                          : '$card $destinationName',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    if (distanceText !=
                        null) ...[
                      const SizedBox(height: 4),
                      Text(
                        distanceText,
                        style: const TextStyle(
                          fontSize: 12,
                          color:
                              Colors.deepPurple,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '地図',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementSummary() {
    final unlocked = _achievementService.getUnlockedAchievements(
      eventAchievements,
      count,
    );

    final next = _achievementService.getNextAchievement(
      eventAchievements,
      count,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '実績',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${unlocked.length}/${eventAchievements.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (eventAchievements.isEmpty) ...[
            Text(
              'このクエストには実績がありません。',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ] else if (next == null) ...[
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'すべての実績を達成しました！',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Text(next.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '次の実績',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${count.clamp(0, next.requiredCount)}/${next.requiredCount}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _achievementService.getProgress(next, count),
                minHeight: 7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              next.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankingSummary() {
    String rankLabel;
    String statusText;

    if (myRank != null) {
      rankLabel = '$myRank位';
      statusText = '獲得 $count個';
    } else if (displayName == null) {
      rankLabel = '未参加';
      statusText = '表示名を設定すると参加できます';
    } else if (count == 0) {
      rankLabel = '未参加';
      statusText = '聖地を1つ獲得すると参加できます';
    } else {
      rankLabel = '--';
      statusText = '順位を取得できませんでした';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.leaderboard, color: Colors.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ランキング',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            rankLabel,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 4,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.deepPurple),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
