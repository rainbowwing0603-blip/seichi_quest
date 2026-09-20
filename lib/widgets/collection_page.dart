import 'package:flutter/material.dart';

import '../models/seichi.dart';
import '../painters/stamp_ring_painter.dart';
import 'quest_item_content_section.dart';
import 'quest_ui.dart';

class CollectionPage extends StatelessWidget {
  const CollectionPage({
    super.key,
    required this.eventId,
    required this.seichiList,
    required this.collectedIds,
    required this.eventNamesByCard,
    required this.collectionFilter,
    required this.onFilterChanged,
    required this.onMoveToSeichi,
    required this.onSetNextDestination,
  });

  final String? eventId;
  final List<Seichi> seichiList;
  final Set<String> collectedIds;
  final Map<String, Set<String>> eventNamesByCard;
  final int collectionFilter;
  final ValueChanged<int> onFilterChanged;
  final Future<void> Function(Seichi seichi) onMoveToSeichi;
  final void Function(Seichi seichi) onSetNextDestination;
  @override
  Widget build(BuildContext context) {
    return _buildCollectionPage(context);
  }

  Widget _buildCollectionPage(BuildContext context) {
    final total = seichiList.length;
    final collected = collectedIds.length.clamp(0, total);
    final remaining = (total - collected).clamp(0, total);
    final progress = total == 0 ? 0.0 : collected / total;

    List<Seichi> filteredList;

    switch (collectionFilter) {
      case 1:
        filteredList = seichiList
            .where((seichi) => collectedIds.contains(seichi.id))
            .toList();
        break;
      case 2:
        filteredList = seichiList
            .where((seichi) => !collectedIds.contains(seichi.id))
            .toList();
        break;
      default:
        filteredList = List<Seichi>.from(seichiList);
    }

    return SafeArea(
      child: Column(
        children: [
          _buildCollectionHeader(
            collected: collected,
            total: total,
            remaining: remaining,
            progress: progress,
          ),
          _buildCollectionFilter(),
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyCollectionState()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                    itemCount: filteredList.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 9,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.63,
                        ),
                    itemBuilder: (context, index) {
                      final seichi = filteredList[index];
                      final collected = collectedIds.contains(seichi.id);

                      return _buildCollectionCard(context, seichi, collected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // スタンプ帳ヘッダー
  // ============================================================

  Widget _buildCollectionHeader({
    required int collected,
    required int total,
    required int remaining,
    required double progress,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: QuestGlassCard(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: QuestUiTokens.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: QuestUiTokens.primary.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.collections_bookmark_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KARUTA COLLECTION',
                        style: TextStyle(
                          color: QuestUiTokens.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '上毛かるた スタンプ帳',
                        style: TextStyle(
                          color: QuestUiTokens.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total == 44 ? '群馬を巡って、44札を集めよう' : '群馬を巡って、$total札を集めよう',
                        style: const TextStyle(
                          color: QuestUiTokens.mutedInk,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                QuestStatusChip(
                  label: '$collected / $total',
                  icon: Icons.auto_awesome_rounded,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: QuestUiTokens.ink,
                    fontSize: 31,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    remaining == 0 && total > 0
                        ? 'COMPLETE!'
                        : 'あと $remaining 札',
                    style: TextStyle(
                      color: remaining == 0 && total > 0
                          ? const Color(0xFF24A77A)
                          : QuestUiTokens.mutedInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: QuestUiTokens.primary.withValues(alpha: 0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  QuestUiTokens.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // スタンプ帳フィルター
  // ============================================================

  Widget _buildCollectionFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'すべて',
            icon: Icons.grid_view_rounded,
            selected: collectionFilter == 0,
            onTap: () => onFilterChanged(0),
          ),
          const SizedBox(width: 7),
          _buildFilterChip(
            label: '獲得済み',
            icon: Icons.check_circle_rounded,
            selected: collectionFilter == 1,
            onTap: () => onFilterChanged(1),
          ),
          const SizedBox(width: 7),
          _buildFilterChip(
            label: '未獲得',
            icon: Icons.lock_outline_rounded,
            selected: collectionFilter == 2,
            onTap: () => onFilterChanged(2),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              gradient: selected ? QuestUiTokens.primaryGradient : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected
                    ? QuestUiTokens.primary.withValues(alpha: 0.35)
                    : QuestUiTokens.primary.withValues(alpha: 0.10),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: QuestUiTokens.primary.withValues(alpha: 0.16),
                        blurRadius: 11,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : QuestUiTokens.mutedInk,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : QuestUiTokens.mutedInk,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // スタンプ帳空状態
  // ============================================================

  Widget _buildEmptyCollectionState() {
    final isCollectedFilter = collectionFilter == 1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCollectedFilter ? Icons.workspace_premium : Icons.celebration,
                size: 44,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isCollectedFilter ? 'まだ獲得した聖地がありません' : '未獲得の札はありません！',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // スタンプカード
  // ============================================================

  Widget _buildCollectionCard(
    BuildContext context,
    Seichi seichi,
    bool collected,
  ) {
    final imageUrl = seichi.cardImageUrl;
    final hasCardImage = imageUrl != null && imageUrl.isNotEmpty;
    final showOriginalCard = collected && hasCardImage;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          _showCollectionStampDetail(context, seichi, collected);
        },
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: collected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xF7FFFFFF),
                      Color(0xEAF3F2FF),
                      Color(0xE6EEF4FF),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.74),
                      const Color(0xFFEFF3F8).withValues(alpha: 0.72),
                    ],
                  ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: collected
                  ? QuestUiTokens.primary.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.88),
              width: collected ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: collected
                    ? QuestUiTokens.primary.withValues(alpha: 0.13)
                    : QuestUiTokens.ink.withValues(alpha: 0.055),
                blurRadius: collected ? 15 : 10,
                offset: const Offset(0, 6),
              ),
              if (collected)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.72),
                  blurRadius: 5,
                  spreadRadius: -1,
                  offset: const Offset(-2, -2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: showOriginalCard
                    ? _buildCollectionKarutaImage(seichi, collected)
                    : _buildStampVisual(seichi, collected),
              ),
              const SizedBox(height: 5),
              _buildCollectionCardStatus(seichi, collected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionCardStatus(Seichi seichi, bool collected) {
    return Container(
      constraints: const BoxConstraints(minHeight: 31),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: collected
            ? Colors.white.withValues(alpha: 0.58)
            : Colors.white.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: collected
              ? QuestUiTokens.primary.withValues(alpha: 0.10)
              : QuestUiTokens.mutedInk.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: collected
                  ? QuestUiTokens.primary.withValues(alpha: 0.11)
                  : QuestUiTokens.mutedInk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              seichi.card,
              style: TextStyle(
                color: collected
                    ? QuestUiTokens.primary
                    : QuestUiTokens.mutedInk,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collected ? seichi.name : '未獲得',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: collected
                        ? QuestUiTokens.ink
                        : QuestUiTokens.mutedInk,
                    fontSize: 8.5,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  collected ? 'STAMP GET' : 'LOCKED',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: collected
                        ? QuestUiTokens.primary
                        : QuestUiTokens.mutedInk.withValues(alpha: 0.78),
                    fontSize: 6.7,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: collected
                  ? const Color(0xFF20A77A)
                  : QuestUiTokens.mutedInk.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              collected ? Icons.check_rounded : Icons.lock_outline_rounded,
              size: 12,
              color: collected ? Colors.white : QuestUiTokens.mutedInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionKarutaImage(Seichi seichi, bool collected) {
    final imageUrl = seichi.cardImageUrl;

    if (!collected || imageUrl == null || imageUrl.isEmpty) {
      return _buildStampVisual(seichi, collected);
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.94)),
        boxShadow: [
          BoxShadow(
            color: QuestUiTokens.primary.withValues(alpha: 0.08),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: ColoredBox(
          color: Colors.white,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: QuestUiTokens.primary.withValues(alpha: 0.55),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(child: _buildStampVisual(seichi, collected));
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // スタンプビジュアル
  // ============================================================

  Widget _buildStampVisual(Seichi seichi, bool collected) {
    if (!collected) {
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.52),
              const Color(0xFFE8EEF5).withValues(alpha: 0.56),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: 1.1,
          ),
        ),
        child: CustomPaint(
          painter: _CollectionLockedSlotPainter(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 8,
                left: 8,
                child: Text(
                  seichi.card,
                  style: TextStyle(
                    color: QuestUiTokens.mutedInk.withValues(alpha: 0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.58),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: QuestUiTokens.mutedInk.withValues(alpha: 0.56),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '未獲得',
                    style: TextStyle(
                      color: QuestUiTokens.mutedInk.withValues(alpha: 0.66),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F3FF), Color(0xFFE6E9FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: QuestUiTokens.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Center(
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.68),
            border: Border.all(
              color: QuestUiTokens.primary.withValues(alpha: 0.25),
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: const StampRingPainter()),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    seichi.card,
                    style: const TextStyle(
                      color: QuestUiTokens.primary,
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(seichi.icon, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // スタンプ詳細
  // ============================================================

  // COLLECTION DETAIL 2.0
  void _showCollectionStampDetail(
    BuildContext context,
    Seichi seichi,
    bool collected,
  ) {
    final eventNames = eventNamesByCard[seichi.card]?.toList() ?? <String>[];
    eventNames.sort();


    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.sizeOf(sheetContext).height;

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
            decoration: const BoxDecoration(
              gradient: QuestUiTokens.glassGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuestGlassCard(
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
                                gradient: collected
                                    ? QuestUiTokens.primaryGradient
                                    : null,
                                color: collected
                                    ? null
                                    : QuestUiTokens.mutedInk.withValues(
                                        alpha: 0.10,
                                      ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                seichi.card,
                                style: TextStyle(
                                  color: collected
                                      ? Colors.white
                                      : QuestUiTokens.mutedInk,
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
                                  Text(
                                    collected
                                        ? 'KARUTA COLLECTION'
                                        : 'LOCKED COLLECTION',
                                    style: TextStyle(
                                      color: collected
                                          ? QuestUiTokens.primary
                                          : QuestUiTokens.mutedInk,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    collected ? seichi.name : '未獲得の聖地',
                                    style: const TextStyle(
                                      color: QuestUiTokens.ink,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        Text(
                          collected
                              ? (seichi.description.isEmpty
                                    ? 'この聖地のスタンプを獲得しました。'
                                    : seichi.description)
                              : 'この聖地を訪れて、スタンプを獲得しよう！',
                          style: const TextStyle(
                            color: QuestUiTokens.ink,
                            fontSize: 14,
                            height: 1.65,
                          ),
                        ),

                        const SizedBox(height: 16),

                        QuestStatusChip(
                          label: collected ? 'STAMP GET' : 'LOCKED',
                          icon: collected
                              ? Icons.check_circle_rounded
                              : Icons.lock_outline_rounded,
                          accentColor: collected
                              ? const Color(0xFF20A77A)
                              : QuestUiTokens.mutedInk,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  QuestItemContentSection(
                    item: seichi,
                    showLegacyText: false,
                  ),

                  if (collected && eventNames.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    QuestGlassCard(
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
                    ),
                  ],

                  const SizedBox(height: 16),

                  QuestPrimaryButton(
                    label: collected ? '獲得した聖地を地図で見る' : 'この聖地を地図で見る',
                    icon: Icons.map_rounded,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onMoveToSeichi(seichi);
                    },
                  ),

                  if (!collected) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        onSetNextDestination(seichi);
                      },
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('次の目的地にする'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: QuestUiTokens.primary,
                        minimumSize: const Size.fromHeight(50),
                        side: BorderSide(
                          color: QuestUiTokens.primary.withValues(alpha: 0.30),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            QuestUiTokens.controlRadius,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  // ============================================================
  // 大きなスタンプ
  // ============================================================



  // ============================================================
  // クエスト画面
  // ============================================================
}

class _CollectionLockedSlotPainter extends CustomPainter {
  const _CollectionLockedSlotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = QuestUiTokens.mutedInk.withValues(alpha: 0.055)
      ..strokeWidth = 1;

    const spacing = 12.0;

    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CollectionLockedSlotPainter oldDelegate) {
    return false;
  }
}
