import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quest_ui.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({
    super.key,
    required this.onResetEventCollectionHistory,
    required this.onTestQuestComplete,
    required this.onTestRecommendedRouteNext,
    required this.onShowOnboarding,
  });

  final Future<void> Function() onResetEventCollectionHistory;
  final Future<void> Function() onTestQuestComplete;
  final Future<void> Function() onTestRecommendedRouteNext;
  final Future<void> Function() onShowOnboarding;

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  static const String _stampEffectKey = 'setting_stamp_effect';
  static const String _autoNextDestinationKey = 'setting_auto_next_destination';

  bool _stampEffect = true;
  bool _autoNextDestination = true;
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
      _stampEffect = prefs.getBool(_stampEffectKey) ?? true;
      _autoNextDestination = prefs.getBool(_autoNextDestinationKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setStampEffect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_stampEffectKey, value);

    if (!mounted) {
      return;
    }

    setState(() {
      _stampEffect = value;
    });
  }

  Future<void> _setAutoNextDestination(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoNextDestinationKey, value);

    if (!mounted) {
      return;
    }

    setState(() {
      _autoNextDestination = value;
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
          'アプリ設定',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
      ),
      body: _loading
          ? const SafeArea(
              child: Center(
                child: CircularProgressIndicator(
                  color: QuestUiTokens.primary,
                  strokeWidth: 2.5,
                ),
              ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  QuestGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: QuestUiTokens.primaryGradient,
                            borderRadius: BorderRadius.circular(18),
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
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QUEST SETTINGS',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w900,
                                  color: QuestUiTokens.mutedInk,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '冒険スタイルを調整',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: QuestUiTokens.ink,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '演出や目的地設定を、自分好みにカスタマイズできます',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
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
                    icon: Icons.auto_awesome,
                    title: 'スタンプ獲得演出',
                    subtitle: '聖地を獲得したときの演出を表示します',
                    value: _stampEffect,
                    onChanged: _setStampEffect,
                  ),
                  _buildSwitchTile(
                    icon: Icons.navigation_rounded,
                    title: '次の目的地を自動設定',
                    subtitle: '聖地を獲得したあと、次の未獲得聖地を目的地にします',
                    value: _autoNextDestination,
                    onChanged: _setAutoNextDestination,
                  ),
                  const SizedBox(height: 14),
                  _buildSectionTitle('データ'),
                  _buildResetHistoryTile(),
                  if (kDebugMode) ...[
                    const SizedBox(height: 14),
                    _buildSectionTitle('開発用'),
                    _buildQuestCompleteTestTile(),
                    _buildRecommendedRouteNextTestTile(),
                  ],
                  const SizedBox(height: 14),
                  _buildSectionTitle('情報'),
                  _buildOnboardingTile(),
                  const SizedBox(height: 10),
                  _buildInfoTile(
                    icon: Icons.info_outline_rounded,
                    title: 'アプリバージョン',
                    value: '1.0.0',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildQuestCompleteTestTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: QuestGlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(QuestUiTokens.cardRadius),
            onTap: () async {
              await widget.onTestQuestComplete();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: QuestUiTokens.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUEST COMPLETE演出をテスト',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '獲得履歴を変更せず、完全制覇時の演出だけを表示します',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: QuestUiTokens.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: QuestUiTokens.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedRouteNextTestTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: QuestGlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(QuestUiTokens.cardRadius),
            onTap: () async {
              await widget.onTestRecommendedRouteNext();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: QuestUiTokens.cyanGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.route_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '巡回ルートのNEXT進行をテスト',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '獲得履歴を変更せず、巡回ルートのNEXTだけを1地点進めます',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: QuestUiTokens.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.skip_next_rounded,
                    color: QuestUiTokens.cyan,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetHistoryTile() {
    return QuestGlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(QuestUiTokens.cardRadius),
          onTap: _confirmResetEventCollectionHistory,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '獲得履歴をリセット',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: QuestUiTokens.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '現在のイベントで獲得した聖地をすべて未獲得に戻します',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: QuestUiTokens.mutedInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmResetEventCollectionHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return QuestDialog(
          icon: Icons.restart_alt_rounded,
          title: '獲得履歴をリセットしますか？',
          subtitle: 'この操作は元に戻せません',
          content: const Text(
            '現在のイベントで獲得した聖地がすべて未獲得になります。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          actionLabel: 'リセット',
          actionIcon: Icons.delete_sweep_rounded,
          onAction: () => Navigator.of(context).pop(true),
          secondaryActionLabel: 'キャンセル',
          onSecondaryAction: () => Navigator.of(context).pop(false),
          isDestructive: true,
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.onResetEventCollectionHistory();

      if (!mounted) {
        return;
      }

      QuestSnackBar.show(
        context,
        message: '獲得履歴をリセットしました。',
        type: QuestNoticeType.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      QuestSnackBar.show(
        context,
        message: 'リセットに失敗しました: $error',
        type: QuestNoticeType.error,
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: QuestUiTokens.primaryGradient,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 0.2,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: QuestGlassCard(
        padding: EdgeInsets.zero,
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          secondary: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: value ? QuestUiTokens.primaryGradient : null,
              color: value
                  ? null
                  : QuestUiTokens.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: value ? Colors.white : QuestUiTokens.primary,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: QuestUiTokens.ink,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: QuestUiTokens.mutedInk,
              ),
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: QuestUiTokens.primary,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: QuestUiTokens.mutedInk.withValues(alpha: 0.22),
        ),
      ),
    );
  }
  Widget _buildOnboardingTile() {
    return QuestGlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(QuestUiTokens.cardRadius),
          onTap: () async {
            await widget.onShowOnboarding();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: QuestUiTokens.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: QuestUiTokens.primary,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'チュートリアルを見る',
                        style: TextStyle(
                          color: QuestUiTokens.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '基本操作をもう一度確認できます',
                        style: TextStyle(
                          color: QuestUiTokens.mutedInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: QuestUiTokens.mutedInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return QuestGlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: QuestUiTokens.cyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: QuestUiTokens.cyan),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: QuestUiTokens.ink,
              ),
            ),
          ),
          QuestStatusChip(
            label: value,
            icon: Icons.apps_rounded,
            accentColor: QuestUiTokens.cyan,
          ),
        ],
      ),
    );
  }
}
