import 'dart:async';

import 'package:flutter/material.dart';

import '../models/quest_item.dart';
import '../policies/quest_event_theme_policy.dart';
import '../services/story_preview_unlock_service.dart';
import '../services/story_rewarded_ad_service.dart';
import 'quest_item_content_section.dart';
import 'quest_ui.dart';

class StoryPreviewSection extends StatefulWidget {
  const StoryPreviewSection({
    super.key,
    required this.item,
    required this.collected,
    required this.eventTheme,
  });

  final QuestItem item;
  final bool collected;
  final QuestEventTheme eventTheme;

  @override
  State<StoryPreviewSection> createState() => _StoryPreviewSectionState();
}

class _StoryPreviewSectionState extends State<StoryPreviewSection> {
  bool _checkingAccess = true;
  bool _unlocked = false;
  bool _watchingAd = false;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _refreshAccess();
  }

  @override
  void didUpdateWidget(covariant StoryPreviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.contentId != widget.item.contentId ||
        oldWidget.collected != widget.collected) {
      _expiryTimer?.cancel();
      _refreshAccess();
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAccess() async {
    if (widget.collected || widget.item.contentId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _checkingAccess = false;
          _unlocked = false;
        });
      }
      return;
    }

    setState(() => _checkingAccess = true);
    try {
      final remaining = await StoryPreviewUnlockService()
          .remainingAccess(widget.item.contentId);
      if (!mounted) return;
      if (remaining != null && remaining > Duration.zero) {
        setState(() => _unlocked = true);
        _scheduleExpiry(remaining);
      } else {
        setState(() => _unlocked = false);
      }
    } catch (error) {
      debugPrint('[STORY_PREVIEW] access check failed: $error');
      if (mounted) setState(() => _unlocked = false);
    } finally {
      if (mounted) setState(() => _checkingAccess = false);
    }
  }

  void _scheduleExpiry(Duration remaining) {
    _expiryTimer?.cancel();
    _expiryTimer = Timer(remaining, () {
      if (mounted) setState(() => _unlocked = false);
    });
  }

  Future<void> _watchAd() async {
    if (_watchingAd || _checkingAccess || widget.collected || _unlocked) {
      return;
    }

    final unlockService = StoryPreviewUnlockService();
    if (!unlockService.hasAuthenticatedUser) {
      _showMessage('アカウントの準備ができていません。少し待ってから再度お試しください。');
      return;
    }

    setState(() => _watchingAd = true);
    try {
      final rewarded = await StoryRewardedAdService.instance.showForStoryUnlock();
      if (!mounted) return;

      if (!rewarded) {
        _showMessage('広告を最後まで視聴すると、物語を1時間読めます。広告を読み込めない場合は、通信を確認して再度お試しください。');
        return;
      }

      await unlockService.grantOneHour(widget.item.contentId);
      if (!mounted) return;
      setState(() => _unlocked = true);
      _scheduleExpiry(const Duration(hours: 1));
      _showMessage('物語を1時間解放しました。');
    } catch (error) {
      debugPrint('[STORY_PREVIEW] rewarded unlock failed: $error');
      if (mounted) {
        _showMessage('解放の確認に失敗しました。通信を確認してから再度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _watchingAd = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storyAvailable = widget.collected || _unlocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestGlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                storyAvailable
                    ? Icons.auto_stories_rounded
                    : Icons.lock_outline_rounded,
                color: storyAvailable
                    ? widget.eventTheme.primary
                    : QuestUiTokens.mutedInk,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.collected
                          ? 'スポットの物語'
                          : _unlocked
                          ? '物語を1時間解放中'
                          : '獲得すると物語が解放',
                      style: const TextStyle(
                        color: QuestUiTokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      storyAvailable
                          ? '由来・歴史・関連画像・現地で見るポイント'
                          : '基本情報は無料で確認できます。広告を視聴すると、このスポットの物語を1時間読めます。',
                      style: const TextStyle(
                        color: QuestUiTokens.mutedInk,
                        fontSize: 12.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!widget.collected &&
            widget.item.contentId.trim().isNotEmpty &&
            !_unlocked) ...[
          const SizedBox(height: 10),
          QuestPrimaryButton(
            label: _watchingAd
                ? '広告を準備しています…'
                : '広告を見て物語を1時間読む',
            icon: Icons.play_circle_outline_rounded,
            onPressed: _watchingAd || _checkingAccess ? null : _watchAd,
          ),
          if (_checkingAccess) ...[
            const SizedBox(height: 6),
            const Text(
              '解放状況を確認しています…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: QuestUiTokens.mutedInk,
                fontSize: 12,
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),
        QuestItemContentSection(
          item: widget.item,
          collected: widget.collected,
          previewUnlocked: _unlocked,
        ),
      ],
    );
  }
}
