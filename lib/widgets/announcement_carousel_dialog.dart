import 'package:flutter/material.dart';

import '../models/announcement.dart';
import 'quest_ui.dart';

class AnnouncementCarouselDialog extends StatefulWidget {
  const AnnouncementCarouselDialog({
    super.key,
    required this.announcements,
    this.onOpenEvent,
  });

  final List<Announcement> announcements;
  final Future<void> Function(String eventId)? onOpenEvent;

  @override
  State<AnnouncementCarouselDialog> createState() =>
      _AnnouncementCarouselDialogState();
}

class _AnnouncementCarouselDialogState
    extends State<AnnouncementCarouselDialog> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _AnnouncementVisual _visualFor(String category) {
    return switch (category) {
      'event_start' => const _AnnouncementVisual(
          label: 'NEW QUEST',
          icon: Icons.flag_rounded,
          accent: QuestUiTokens.primary,
        ),
      'event_ending' => const _AnnouncementVisual(
          label: 'ENDING SOON',
          icon: Icons.timer_outlined,
          accent: Color(0xFFE49B35),
        ),
      'update' => const _AnnouncementVisual(
          label: 'UPDATE',
          icon: Icons.auto_awesome_rounded,
          accent: QuestUiTokens.cyan,
        ),
      'maintenance' => const _AnnouncementVisual(
          label: 'MAINTENANCE',
          icon: Icons.build_circle_outlined,
          accent: Color(0xFFE49B35),
        ),
      'campaign' => const _AnnouncementVisual(
          label: 'CAMPAIGN',
          icon: Icons.celebration_rounded,
          accent: Color(0xFFD95B9B),
        ),
      _ => const _AnnouncementVisual(
          label: 'INFORMATION',
          icon: Icons.notifications_active_rounded,
          accent: QuestUiTokens.primary,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final announcements = widget.announcements;
    final current = announcements[_index];
    final visual = _visualFor(current.category);
    final hasEvent = current.eventId != null && widget.onOpenEvent != null;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 620),
        child: QuestGlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 30,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        visual.accent.withValues(alpha: 0.20),
                        Colors.white.withValues(alpha: 0.74),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                        child: Icon(visual.icon, color: visual.accent, size: 27),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visual.label,
                              style: TextStyle(
                                color: visual.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'お知らせ',
                              style: TextStyle(
                                color: QuestUiTokens.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '閉じる',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: QuestUiTokens.mutedInk,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: announcements.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) {
                      final item = announcements[index];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: QuestUiTokens.ink,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item.body,
                              style: const TextStyle(
                                color: QuestUiTokens.mutedInk,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                  child: Column(
                    children: [
                      if (announcements.length > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            announcements.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: index == _index ? 22 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                color: index == _index
                                    ? visual.accent
                                    : QuestUiTokens.mutedInk.withValues(alpha: 0.20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swipe_rounded,
                                size: 17, color: QuestUiTokens.mutedInk),
                            SizedBox(width: 6),
                            Text(
                              '左右にスワイプして確認',
                              style: TextStyle(
                                color: QuestUiTokens.mutedInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (hasEvent)
                        QuestPrimaryButton(
                          label: 'クエストを見る',
                          icon: Icons.flag_outlined,
                          onPressed: () {
                            final eventId = current.eventId;
                            if (eventId == null) return;
                            Navigator.of(context).pop();
                            widget.onOpenEvent!(eventId);
                          },
                        )
                      else
                        QuestPrimaryButton(
                          label: '確認しました',
                          icon: Icons.check_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
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

class _AnnouncementVisual {
  const _AnnouncementVisual({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;
}
