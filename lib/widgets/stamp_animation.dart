import 'package:flutter/material.dart';

import 'quest_ui.dart';

class StampAnimation extends StatelessWidget {
  const StampAnimation({
    super.key,
    required this.justCollected,
    required this.collectedName,
    required this.collectedCount,
    required this.total,
  });

  final bool justCollected;
  final String? collectedName;
  final int collectedCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (!justCollected) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 500),
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 310),
              child: QuestGlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: QuestUiTokens.primaryGradient,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'スポット到達！',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: QuestUiTokens.ink,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      collectedName ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: QuestUiTokens.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const QuestStatusChip(
                      label: 'スポットの物語が解放されました',
                      icon: Icons.auto_stories_rounded,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$collectedCount / $total スポット獲得',
                      style: const TextStyle(
                        color: QuestUiTokens.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
