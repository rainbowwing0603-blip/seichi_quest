import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../services/level_service.dart';
import 'profile_avatar.dart';
import 'quest_ui.dart';

class MyPage extends StatelessWidget {
  static const AchievementService _achievementService = AchievementService();

  final String? displayName;
  final String? avatarKey;
  final int? myRank;
  final LevelProgress? levelProgress;
  final List<Achievement> eventAchievements;
  final int count;
  final int total;
  final String? currentEventName;
  final String? nextDestinationName;
  final String? nextDestinationCard;
  final String? nextDestinationIcon;
  final double? nextDestinationDistance;
  final VoidCallback onShowNextDestination;
  final VoidCallback onShowAchievements;
  final VoidCallback onShowRanking;
  final VoidCallback onShowAdventureLog;
  final VoidCallback onShowSyncStatus;
  final VoidCallback onShowProfile;
  final VoidCallback onShowAccount;
  final VoidCallback onShowNotifications;
  final VoidCallback onShowAnnouncements;
  final int unreadAnnouncementCount;
  final VoidCallback onShowSettings;
  final VoidCallback onShowAbout;

  const MyPage({
    super.key,
    required this.displayName,
    required this.avatarKey,
    required this.myRank,
    required this.levelProgress,
    required this.eventAchievements,
    required this.count,
    required this.total,
    required this.currentEventName,
    required this.nextDestinationName,
    required this.nextDestinationCard,
    required this.nextDestinationIcon,
    required this.nextDestinationDistance,
    required this.onShowNextDestination,
    required this.onShowAchievements,
    required this.onShowRanking,
    required this.onShowAdventureLog,
    required this.onShowSyncStatus,
    required this.onShowProfile,
    required this.onShowAccount,
    required this.onShowNotifications,
    required this.onShowAnnouncements,
    required this.unreadAnnouncementCount,
    required this.onShowSettings,
    required this.onShowAbout,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0 : (count / total * 100).round();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            _buildSectionTitle('記録', Icons.auto_graph_outlined),
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
              subtitle: 'これまでに獲得した札の履歴',
              onTap: onShowAdventureLog,
            ),

            const SizedBox(height: 18),

            _buildSettingsExpansion(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsExpansion() {
    return QuestGlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: QuestUiTokens.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: QuestUiTokens.primary.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SETTINGS',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.15,
                  fontWeight: FontWeight.w900,
                  color: QuestUiTokens.mutedInk,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '設定・管理',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: QuestUiTokens.ink,
                ),
              ),
            ],
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text(
              'プロフィール・通知・アプリ設定など',
              style: TextStyle(fontSize: 11, color: QuestUiTokens.mutedInk),
            ),
          ),
          iconColor: QuestUiTokens.primary,
          collapsedIconColor: QuestUiTokens.mutedInk,
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            const SizedBox(height: 2),
            _buildSettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'プロフィール',
              subtitle: 'ユーザー情報を設定',
              onTap: onShowProfile,
              compact: true,
            ),
            _buildSettingsTile(
              icon: Icons.manage_accounts_outlined,
              title: 'アカウント',
              subtitle: 'データを引き継ぐ',
              onTap: onShowAccount,
              compact: true,
            ),
            _buildSettingsTile(
              icon: unreadAnnouncementCount > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              title: unreadAnnouncementCount > 0
                  ? 'お知らせ  未読 $unreadAnnouncementCount件'
                  : 'お知らせ',
              subtitle: '運営からのお知らせを確認',
              onTap: onShowAnnouncements,
              compact: true,
            ),
            _buildSettingsTile(
              icon: Icons.notifications_none_rounded,
              title: '通知設定',
              subtitle: 'お知らせ・到達通知',
              onTap: onShowNotifications,
              compact: true,
            ),
            _buildSettingsTile(
              icon: Icons.cloud_sync_outlined,
              title: '同期状態',
              subtitle: '保留中の訪問データを確認',
              onTap: onShowSyncStatus,
              compact: true,
            ),
            _buildSettingsTile(
              icon: Icons.settings_outlined,
              title: 'アプリ設定',
              subtitle: '各種設定',
              onTap: onShowSettings,
              compact: true,
            ),
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: '聖地クエストについて',
              subtitle: 'アプリ情報',
              onTap: onShowAbout,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(int progress) {
    final level = levelProgress;

    return QuestGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: QuestUiTokens.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: QuestUiTokens.primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ProfileAvatar(
                    avatarKey: avatarKey,
                    size: 66,
                    iconSize: 35,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName ?? 'ゲストユーザー',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'SEICHI QUEST ADVENTURER',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                    if (myRank != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onShowRanking,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.leaderboard_rounded,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'RANK  $myRank位',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: QuestUiTokens.ink,
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
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: QuestUiTokens.mutedInk,
              ),
            ],
          ),
          if (level != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: QuestUiTokens.primary.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: QuestUiTokens.primary.withValues(alpha: 0.10),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: QuestUiTokens.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Lv.${level.level}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'EXPERIENCE',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${level.totalXp} XP',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: QuestUiTokens.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: level.progress,
                      minHeight: 8,
                      backgroundColor: QuestUiTokens.primary.withValues(
                        alpha: 0.09,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        '${level.xpIntoLevel} / '
                        '${level.xpNeededForNextLevel} XP',
                        style: const TextStyle(
                          fontSize: 10,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'NEXT  '
                        '${level.xpNeededForNextLevel - level.xpIntoLevel} XP',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: QuestUiTokens.primary.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCompactStat(value: '$count', label: '獲得'),
                ),
                _buildStatDivider(),
                Expanded(
                  child: _buildCompactStat(value: '$total', label: '登録'),
                ),
                _buildStatDivider(),
                Expanded(
                  child: _buildCompactStat(value: '$progress%', label: '達成率'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat({required String value, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            height: 1,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
            color: QuestUiTokens.mutedInk,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: QuestUiTokens.primary.withValues(alpha: 0.10),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: QuestUiTokens.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: QuestUiTokens.primary),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: QuestUiTokens.ink,
            ),
          ),
          const Spacer(),
          Container(
            width: 26,
            height: 2,
            decoration: BoxDecoration(
              gradient: QuestUiTokens.primaryGradient,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextDestinationCard() {
    final destinationName = nextDestinationName?.trim();
    final hasDestination =
        destinationName != null && destinationName.isNotEmpty;

    if (!hasDestination) {
      final isComplete = total > 0 && count >= total;

      return QuestGlassCard(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isComplete ? Colors.amber : QuestUiTokens.primary)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isComplete
                    ? Icons.emoji_events_rounded
                    : Icons.explore_outlined,
                color: isComplete
                    ? Colors.amber.shade700
                    : QuestUiTokens.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NEXT DESTINATION',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.25,
                      fontWeight: FontWeight.w900,
                      color: QuestUiTokens.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isComplete ? 'このクエストを完全制覇！' : '次の目的地を準備中',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: QuestUiTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isComplete ? 'すべての聖地を獲得しました' : '位置情報を取得すると候補が表示されます',
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

    final distance = nextDestinationDistance;

    String? distanceText;

    if (distance != null) {
      distanceText = distance < 1000
          ? 'あと ${distance.round()}m'
          : 'あと ${(distance / 1000).toStringAsFixed(1)}km';
    }

    final card = nextDestinationCard?.trim();
    final icon = nextDestinationIcon?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onShowNextDestination,
        child: QuestGlassCard(
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  QuestUiTokens.primary.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.20),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: QuestUiTokens.primaryGradient,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: QuestUiTokens.primary.withValues(alpha: 0.20),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    icon == null || icon.isEmpty ? '📍' : icon,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT DESTINATION',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.25,
                          fontWeight: FontWeight.w900,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card == null || card.isEmpty
                            ? destinationName
                            : '$card  $destinationName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: QuestUiTokens.ink,
                        ),
                      ),
                      if (distanceText != null) ...[
                        const SizedBox(height: 5),
                        QuestStatusChip(
                          label: distanceText,
                          icon: Icons.near_me_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: QuestUiTokens.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    size: 20,
                    color: QuestUiTokens.primary,
                  ),
                ),
              ],
            ),
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

    return QuestGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: QuestUiTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: QuestUiTokens.primary.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACHIEVEMENTS',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.15,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '実績',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
              QuestStatusChip(
                label: '${unlocked.length}/${eventAchievements.length}',
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: QuestUiTokens.mutedInk,
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (eventAchievements.isEmpty) ...[
            const Text(
              'このクエストには実績がありません。',
              style: TextStyle(fontSize: 12, color: QuestUiTokens.mutedInk),
            ),
          ] else if (next == null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Colors.green,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'すべての実績を達成しました！',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: QuestUiTokens.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(next.icon, style: const TextStyle(fontSize: 23)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT ACHIEVEMENT',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w800,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: QuestUiTokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${count.clamp(0, next.requiredCount)}/${next.requiredCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _achievementService.getProgress(next, count),
                minHeight: 7,
                backgroundColor: QuestUiTokens.primary.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              next.description,
              style: const TextStyle(
                fontSize: 11,
                color: QuestUiTokens.mutedInk,
              ),
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

    return QuestGlassCard(
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.20)),
            ),
            child: const Icon(
              Icons.leaderboard_rounded,
              color: Colors.amber,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RANKING',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.15,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'ランキング',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            rankLabel,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: QuestUiTokens.ink,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(
            Icons.chevron_right_rounded,
            color: QuestUiTokens.mutedInk,
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
    bool compact = false,
  }) {
    final radius = compact ? 14.0 : 18.0;
    final iconSize = compact ? 38.0 : 44.0;

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 7 : 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: compact ? 0.58 : 0.82),
            QuestUiTokens.primary.withValues(alpha: compact ? 0.025 : 0.045),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: QuestUiTokens.primary.withValues(alpha: compact ? 0.07 : 0.09),
        ),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: QuestUiTokens.ink.withValues(alpha: 0.035),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 9 : 12,
            ),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: QuestUiTokens.primary.withValues(
                      alpha: compact ? 0.065 : 0.085,
                    ),
                    borderRadius: BorderRadius.circular(compact ? 12 : 14),
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 19 : 21,
                    color: QuestUiTokens.primary,
                  ),
                ),
                SizedBox(width: compact ? 11 : 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          fontWeight: compact
                              ? FontWeight.w700
                              : FontWeight.w800,
                          color: QuestUiTokens.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 10 : 11,
                          height: 1.25,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: compact ? 27 : 30,
                  height: compact ? 27 : 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.62),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: compact ? 18 : 20,
                    color: QuestUiTokens.mutedInk,
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
