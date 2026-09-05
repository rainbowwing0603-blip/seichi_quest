import 'package:flutter/material.dart';

class MyPage extends StatelessWidget {
  final int count;
  final int total;
  final String? currentEventName;
  final VoidCallback onSelectEvent;
  final VoidCallback onShowProfile;
  final VoidCallback onShowNotifications;
  final VoidCallback onShowSettings;
  final VoidCallback onShowAbout;

  const MyPage({
    super.key,
    required this.count,
    required this.total,
    required this.currentEventName,
    required this.onSelectEvent,
    required this.onShowProfile,
    required this.onShowNotifications,
    required this.onShowSettings,
    required this.onShowAbout,
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
          children: [
            const SizedBox(
              height: 12,
            ),
            Container(
              width: 94,
              height: 94,
              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFF6A35C8),
                    Color(0xFF9B72E8),
                  ],
                ),
                shape:
                    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors
                        .deepPurple
                        .withValues(
                      alpha: 0.25,
                    ),
                    blurRadius: 18,
                    offset:
                        const Offset(
                      0,
                      8,
                    ),
                  ),
                ],
              ),
              child:
                  const Icon(
                Icons.person,
                color:
                    Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            const Text(
              'ゲストユーザー',
              style:
                  TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              '聖地クエスト冒険者',
              style:
                  TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            Row(
              children: [
                Expanded(
                  child:
                      _buildStatCard(
                    icon: Icons
                        .workspace_premium,
                    value:
                        '$count',
                    label:
                        '獲得聖地',
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      _buildStatCard(
                    icon:
                        Icons.map,
                    value:
                        '$total',
                    label:
                        '登録聖地',
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      _buildStatCard(
                    icon:
                        Icons.percent,
                    value: total == 0
                        ? '0%'
                        : '${(count / total * 100).round()}%',
                    label:
                        '達成率',
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 24,
            ),
            _buildSettingsTile(
              icon:
                  Icons.explore_outlined,
              title:
                  '現在のクエスト',
              subtitle:
                  currentEventName ?? 'クエストを選択',
              onTap:
                  onSelectEvent,
            ),
            _buildSettingsTile(
              icon:
                  Icons.person_outline,
              title:
                  'プロフィール',
              subtitle:
                  'ユーザー情報を設定',
              onTap:
                  onShowProfile,
            ),
            _buildSettingsTile(
              icon: Icons
                  .notifications_none,
              title:
                  '通知設定',
              subtitle:
                  'お知らせ・到達通知',
              onTap:
                  onShowNotifications,
            ),
            _buildSettingsTile(
              icon:
                  Icons.settings_outlined,
              title:
                  'アプリ設定',
              subtitle:
                  '各種設定',
              onTap:
                  onShowSettings,
            ),
            _buildSettingsTile(
              icon:
                  Icons.info_outline,
              title:
                  '聖地クエストについて',
              subtitle:
                  'アプリ情報',
              onTap:
                  onShowAbout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 8,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color:
                Colors.deepPurple,
            size: 23,
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            value,
            style:
                const TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            label,
            style:
                const TextStyle(
              fontSize: 11,
              color:
                  Colors.grey,
            ),
          ),
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
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 4,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(
            color: Colors
                .deepPurple
                .withValues(
              alpha: 0.08,
            ),
            shape:
                BoxShape.circle,
          ),
          child: Icon(
            icon,
            color:
                Colors.deepPurple,
          ),
        ),
        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style:
              const TextStyle(
            fontSize: 12,
          ),
        ),
        trailing:
            const Icon(
          Icons.chevron_right,
        ),
          onTap: onTap,
        ),
      ),
    );
  }
}