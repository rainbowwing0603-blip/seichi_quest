import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/achievement_service.dart';

class MyPage extends StatelessWidget {
  static const AchievementService _achievementService = AchievementService();

  final String? displayName;
  final int? myRank;
  final List<Achievement> eventAchievements;
  final int count;
  final int total;
  final String? currentEventName;
  final VoidCallback onSelectEvent;
  final VoidCallback onShowAchievements;
  final VoidCallback onShowRanking;
  final VoidCallback onShowProfile;
  final VoidCallback onShowAccount;
  final VoidCallback onShowNotifications;
  final VoidCallback onShowSettings;
  final VoidCallback onShowAbout;

  const MyPage({
    super.key,
    required this.displayName,
    required this.myRank,
    required this.eventAchievements,
    required this.count,
    required this.total,
    required this.currentEventName,
    required this.onSelectEvent,
    required this.onShowAchievements,
    required this.onShowRanking,
    required this.onShowProfile,
    required this.onShowAccount,
    required this.onShowNotifications,
    required this.onShowSettings,
    required this.onShowAbout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A35C8), Color(0xFF9B72E8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 14),
            Text(
              displayName ?? 'ゲストユーザー',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('聖地クエスト冒険者', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.workspace_premium,
                    value: '$count',
                    label: '獲得聖地',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.map,
                    value: '$total',
                    label: '登録聖地',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.percent,
                    value: total == 0
                        ? '0%'
                        : '${(count / total * 100).round()}%',
                    label: '達成率',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onShowAchievements,
              behavior: HitTestBehavior.opaque,
              child: _buildAchievementSummary(),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onShowRanking,
              behavior: HitTestBehavior.opaque,
              child: _buildRankingSummary(),
            ),
            const SizedBox(height: 14),
            _buildSettingsTile(
              icon: Icons.explore_outlined,
              title: '現在のクエスト',
              subtitle: currentEventName ?? 'クエストを選択',
              onTap: onSelectEvent,
            ),
            _buildSettingsTile(
              icon: Icons.person_outline,
              title: 'プロフィール',
              subtitle: 'ユーザー情報を設定',
              onTap: onShowProfile,
            ),
            _buildSettingsTile(
              icon: Icons.manage_accounts_outlined,
              title: 'アカウント',
              subtitle: 'データを引き継ぐ',
              onTap: onShowAccount,
            ),
            _buildSettingsTile(
              icon: Icons.notifications_none,
              title: '通知設定',
              subtitle: 'お知らせ・到達通知',
              onTap: onShowNotifications,
            ),
            _buildSettingsTile(
              icon: Icons.settings_outlined,
              title: 'アプリ設定',
              subtitle: '各種設定',
              onTap: onShowSettings,
            ),
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: '聖地クエストについて',
              subtitle: 'アプリ情報',
              onTap: onShowAbout,
            ),
          ],
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

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 23),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
