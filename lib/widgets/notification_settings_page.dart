import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quest_ui.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const String _stampNotificationKey = 'setting_stamp_notification';

  bool _stampNotification = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _stampNotification = prefs.getBool(_stampNotificationKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setStampNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_stampNotificationKey, value);

    if (!mounted) {
      return;
    }

    setState(() {
      _stampNotification = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuestUiTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '通知設定',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: QuestUiTokens.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                QuestGlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: QuestUiTokens.primaryGradient,
                          borderRadius: BorderRadius.circular(19),
                          boxShadow: [
                            BoxShadow(
                              color: QuestUiTokens.primary.withValues(
                                alpha: 0.16,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NOTIFICATIONS',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.mutedInk,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '冒険のお知らせ',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.ink,
                              ),
                            ),
                            SizedBox(height: 7),
                            Text(
                              '聖地クエストから受け取る通知を設定できます。',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: QuestUiTokens.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _buildSectionTitle('聖地クエスト'),
                _buildSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'スタンプ獲得通知',
                  subtitle: '聖地を獲得したときに通知を表示します',
                  value: _stampNotification,
                  onChanged: _setStampNotification,
                ),
                const SizedBox(height: 16),
                _buildInfoTile(
                  icon: Icons.info_outline_rounded,
                  title: '通知について',
                  subtitle: '通知を表示するには、端末側の通知許可も必要です。',
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: QuestUiTokens.primaryGradient,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: QuestUiTokens.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return QuestGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: value ? QuestUiTokens.primaryGradient : null,
              color: value
                  ? null
                  : QuestUiTokens.mutedInk.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: value ? Colors.white : QuestUiTokens.mutedInk,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: QuestUiTokens.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: QuestUiTokens.mutedInk.withValues(alpha: 0.20),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return QuestGlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: QuestUiTokens.cyan.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: QuestUiTokens.cyan, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.45,
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
