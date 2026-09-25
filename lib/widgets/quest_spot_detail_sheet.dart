import 'package:flutter/material.dart';

import '../models/quest_item.dart';
import 'quest_item_content_section.dart';
import 'quest_ui.dart';

class QuestSpotDetailSheet extends StatelessWidget {
  const QuestSpotDetailSheet({
    super.key,
    required this.item,
    required this.collected,
    this.isNext = false,
    this.distanceMeters,
    this.eventNames = const <String>[],
    this.onShowOnMap,
    this.onSetNextDestination,
  });

  final QuestItem item;
  final bool collected;
  final bool isNext;
  final double? distanceMeters;
  final List<String> eventNames;
  final VoidCallback? onShowOnMap;
  final VoidCallback? onSetNextDestination;

  static Future<void> show(
    BuildContext context, {
    required QuestItem item,
    required bool collected,
    bool isNext = false,
    double? distanceMeters,
    List<String> eventNames = const <String>[],
    VoidCallback? onShowOnMap,
    VoidCallback? onSetNextDestination,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return QuestSpotDetailSheet(
          item: item,
          collected: collected,
          isNext: isNext,
          distanceMeters: distanceMeters,
          eventNames: eventNames,
          onShowOnMap: onShowOnMap == null ? null : () {
            Navigator.of(sheetContext).pop();
            onShowOnMap();
          },
          onSetNextDestination: onSetNextDestination == null ? null : () {
            Navigator.of(sheetContext).pop();
            onSetNextDestination();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
        decoration: const BoxDecoration(
          gradient: QuestUiTokens.glassGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: '詳細を閉じる',
                  child: IconButton.filledTonal(
                    tooltip: '閉じる',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _buildHeader(),
              const SizedBox(height: 14),
              _buildStoryNotice(),
              const SizedBox(height: 12),
              QuestItemContentSection(
                item: item,                collected: collected,
              ),
              if (collected && eventNames.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildEventNames(),
              ],
              if (onShowOnMap != null) ...[
                const SizedBox(height: 16),
                QuestPrimaryButton(
                  label: collected ? '獲得したスポットを地図で見る' : 'このスポットを地図で見る',
                  icon: Icons.map_rounded,
                  onPressed: onShowOnMap,
                ),
              ],
              if (onSetNextDestination != null && !collected) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: isNext ? null : onSetNextDestination,
                  icon: Icon(isNext ? Icons.flag : Icons.navigation_outlined),
                  label: Text(isNext ? '次の目的地に設定済み' : '次の目的地にする'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: QuestUiTokens.primary,
                    side: BorderSide(
                      color: QuestUiTokens.primary.withValues(alpha: 0.22),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return QuestGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: collected ? QuestUiTokens.primaryGradient : null,
                  color: collected ? null : QuestUiTokens.mutedInk.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  item.icon.isNotEmpty ? item.icon : '📍',
                  style: TextStyle(
                    color: collected ? Colors.white : QuestUiTokens.mutedInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SPOT DETAIL 2.0',
                      style: TextStyle(
                        color: QuestUiTokens.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.45,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: QuestUiTokens.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              QuestStatusChip(
                label: collected ? '獲得済み' : '未獲得',
                icon: collected ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                accentColor: collected ? const Color(0xFF20A77A) : QuestUiTokens.mutedInk,
              ),
              if (isNext && !collected)
                const QuestStatusChip(label: 'NEXT', icon: Icons.navigation_rounded),
              QuestStatusChip(
                label: '獲得範囲 ${item.stampRadiusMeters}m',
                icon: Icons.place_outlined,
                accentColor: QuestUiTokens.cyan,
              ),
              if (distanceMeters != null)
                QuestStatusChip(
                  label: distanceMeters! < 1000
                      ? '現在地から ${distanceMeters!.round()}m'
                      : '現在地から ${(distanceMeters! / 1000).toStringAsFixed(1)}km',
                  icon: Icons.near_me_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoryNotice() {
    return QuestGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            collected ? Icons.auto_stories_rounded : Icons.lock_outline_rounded,
            color: collected ? QuestUiTokens.primary : QuestUiTokens.mutedInk,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collected ? 'スポットの物語' : '獲得すると物語が解放',
                  style: const TextStyle(
                    color: QuestUiTokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  collected
                      ? '由来・歴史・関連画像・現地で見るポイント'
                      : '基本情報を確認できます。現地でスタンプを獲得すると、由来・歴史・関連情報が解放されます。',
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
    );
  }

  Widget _buildEventNames() {
    return QuestGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '獲得イベント',
            style: TextStyle(
              color: QuestUiTokens.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final eventName in eventNames)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '・$eventName',
                style: const TextStyle(
                  color: QuestUiTokens.ink,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
