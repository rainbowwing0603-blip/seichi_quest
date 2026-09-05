import 'package:flutter/material.dart';

import '../models/seichi.dart';
import '../painters/stamp_ring_painter.dart';

class CollectionPage extends StatelessWidget {
  const CollectionPage({
    super.key,
    required this.seichiList,
    required this.collectedIds,
    required this.collectionFilter,
    required this.onFilterChanged,
    required this.onMoveToSeichi,
    required this.onSetNextDestination,
  });

  final List<Seichi> seichiList;
  final Set<String> collectedIds;
  final int collectionFilter;
  final ValueChanged<int> onFilterChanged;
  final Future<void> Function(Seichi seichi)
      onMoveToSeichi;
  final void Function(Seichi seichi)
      onSetNextDestination;
  @override
  Widget build(BuildContext context) {
    return _buildCollectionPage(context);
  }

  Widget _buildCollectionPage(BuildContext context) {
    final total =
        seichiList.length;

    final collected = collectedIds.length;

    final remaining = (total - collected).clamp(0, total);

    final progress =
        total == 0
            ? 0.0
            : collected / total;

    List<Seichi> filteredList;

    switch (collectionFilter) {
      case 1:
        filteredList = seichiList
            .where(
              (seichi) =>
                  collectedIds.contains(
                seichi.id,
              ),
            )
            .toList();
        break;

      case 2:
        filteredList = seichiList
            .where(
              (seichi) =>
                  !collectedIds.contains(
                seichi.id,
              ),
            )
            .toList();
        break;

      default:
        filteredList =
            List<Seichi>.from(
          seichiList,
        );
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
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      16,
                      4,
                      16,
                      24,
                    ),
                    itemCount:
                        filteredList.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          0.82,
                    ),
                    itemBuilder:
                        (context, index) {
                      final seichi =
                          filteredList[
                              index];

                      final isCollected =
                          collectedIds
                              .contains(
                        seichi.id,
                      );

                      return _buildCollectionCard(
                        context,
                        seichi,
                        isCollected,
                      );
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
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        18,
      ),
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFF5B21B6),
            Color(0xFF7C3AED),
            Color(0xFF9333EA),
          ],
        ),
        borderRadius:
            BorderRadius.only(
          bottomLeft:
              Radius.circular(30),
          bottomRight:
              Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.16,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .workspace_premium,
                  color:
                      Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(
                width: 13,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'スタンプ帳',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 25,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    Text(
                      total == 44
                          ? '上毛かるた 44札'
                          : '上毛かるた $total札',
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.16,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color:
                          Colors.white,
                      size: 17,
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    Text(
                      '$collected / $total',
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 18,
          ),
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                '${(progress * 100).round()}%',
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 38,
                  height: 1,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Padding(
                padding:
                    const EdgeInsets
                        .only(
                  bottom: 3,
                ),
                child: Text(
                  remaining == 0 &&
                          total > 0
                      ? '完全制覇！'
                      : 'あと $remaining 聖地',
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 11,
          ),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            child:
                LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor:
                  Colors.white
                      .withValues(
                alpha: 0.20,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // スタンプ帳フィルター
  // ============================================================

  Widget _buildCollectionFilter() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        10,
      ),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'すべて',
            icon:
                Icons.grid_view_rounded,
            selected:
                collectionFilter ==
                    0,
            onTap: () {
              onFilterChanged(0);
            },
          ),
          const SizedBox(
            width: 8,
          ),
          _buildFilterChip(
            label: '獲得済み',
            icon:
                Icons.check_circle,
            selected:
                collectionFilter ==
                    1,
            onTap: () {
              onFilterChanged(1);
            },
          ),
          const SizedBox(
            width: 8,
          ),
          _buildFilterChip(
            label: '未獲得',
            icon:
                Icons.lock_outline,
            selected:
                collectionFilter ==
                    2,
            onTap: () {
              onFilterChanged(2);
            },
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
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        child:
            AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          padding:
              const EdgeInsets
                  .symmetric(
            vertical: 11,
            horizontal: 8,
          ),
          decoration:
              BoxDecoration(
            color: selected
                ? Colors.deepPurple
                : Colors.white,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color: selected
                  ? Colors.deepPurple
                  : Colors.black
                      .withValues(
                    alpha: 0.06,
                  ),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? Colors.white
                    : Colors.grey
                        .shade700,
              ),
              const SizedBox(
                width: 5,
              ),
              Text(
                label,
                style:
                    TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : Colors.grey
                          .shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // スタンプ帳空状態
  // ============================================================

  Widget _buildEmptyCollectionState() {
    final isCollectedFilter =
        collectionFilter == 1;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
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
                isCollectedFilter
                    ? Icons
                        .workspace_premium
                    : Icons
                        .celebration,
                size: 44,
                color:
                    Colors.deepPurple,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            Text(
              isCollectedFilter
                  ? 'まだ獲得した聖地がありません'
                  : '未獲得の札はありません！',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        onTap: () {
          _showCollectionStampDetail(
            context,
            seichi,
            collected,
          );
        },
        child:
            AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 200,
          ),
          padding:
              const EdgeInsets.all(
            13,
          ),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              22,
            ),
            border: Border.all(
              color: collected
                  ? Colors.green
                      .withValues(
                    alpha: 0.35,
                  )
                  : Colors.grey
                      .withValues(
                    alpha: 0.12,
                  ),
              width:
                  collected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: collected
                    ? Colors.green
                        .withValues(
                      alpha: 0.08,
                    )
                    : Colors.black
                        .withValues(
                      alpha: 0.045,
                    ),
                blurRadius: 12,
                offset:
                    const Offset(
                  0,
                  5,
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    seichi.card,
                    style:
                        TextStyle(
                      fontSize: 24,
                      height: 1,
                      fontWeight:
                          FontWeight.w900,
                      color: collected
                          ? Colors.green.shade700
                          : Colors.deepPurple,
                    ),
                  ),
                  const Spacer(),
                  if (collected)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.green
                            .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check,
                            size: 13,
                            color: Colors.green,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'GET',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child:
                      _buildStampVisual(
                    seichi,
                    collected,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                collected
                    ? seichi.name
                    : '？？？',
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.bold,
                  color: collected
                      ? Colors.black87
                      : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                collected
                    ? seichi.reading
                    : '聖地を訪れて獲得',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    TextStyle(
                  fontSize: 10,
                  color: collected
                      ? Colors.grey.shade600
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // スタンプビジュアル
  // ============================================================

  Widget _buildStampVisual(
    Seichi seichi,
    bool collected,
  ) {
    if (!collected) {
      return Container(
        width: 108,
        height: 108,
        decoration:
            BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              seichi.card,
              style: TextStyle(
                fontSize: 68,
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade300,
              ),
            ),
            Positioned(
              right: 17,
              bottom: 14,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                ),
                child: Icon(
                  Icons.question_mark_rounded,
                  size: 19,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 108,
      height: 108,
      decoration:
          BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F8EA),
            Color(0xFFD0F0D4),
          ],
        ),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.45),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: const StampRingPainter(),
            ),
          ),
          Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                seichi.card,
                style:
                    const TextStyle(
                  fontSize: 35,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                seichi.icon,
                style:
                    const TextStyle(
                  fontSize: 25,
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                'STAMP GET',
                style:
                    TextStyle(
                  fontSize: 7,
                  letterSpacing: 1.0,
                  color: Colors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // スタンプ詳細
  // ============================================================

  void _showCollectionStampDetail(
    BuildContext context,
    Seichi seichi,
    bool collected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 4,
                ),
                _buildLargeStampVisual(
                  seichi,
                  collected,
                ),
                const SizedBox(
                  height: 16,
                ),
                Text(
                  seichi.card,
                  style:
                      TextStyle(
                    color:
                        Theme.of(
                      context,
                    )
                            .colorScheme
                            .primary,
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  collected
                      ? seichi.name
                      : '未獲得の聖地',
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 23,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                if (seichi.reading
                    .isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 5,
                    ),
                    child: Text(
                      seichi.reading,
                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                  ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  collected
                      ? (seichi
                              .description
                              .isEmpty
                          ? 'この聖地のスタンプを獲得しました。'
                          : seichi
                              .description)
                      : 'この聖地を訪れて、スタンプを獲得しよう！',
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                if (collected)
                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .all(
                      13,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.green
                          .withValues(
                        alpha: 0.08,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                    child:
                        const Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Icon(
                          Icons.verified,
                          color:
                              Colors.green,
                          size: 20,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'スタンプ獲得済み',
                          style:
                              TextStyle(
                            color:
                                Colors.green,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(
                  height: 14,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton
                          .icon(
                    onPressed:
                        () async {
                      Navigator.pop(
                        sheetContext,
                      );

                      await onMoveToSeichi(
                        seichi,
                      );
                    },
                    icon:
                        const Icon(
                      Icons.map,
                    ),
                    label: Text(
                      collected
                          ? '獲得した聖地を地図で見る'
                          : 'この聖地を地図で見る',
                    ),
                    style:
                        FilledButton
                            .styleFrom(
                      minimumSize:
                          const Size
                              .fromHeight(
                        50,
                      ),
                    ),
                  ),
                ),
                if (!collected) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        onSetNextDestination(seichi);
                      },
                      icon: const Icon(
                        Icons.flag_rounded,
                      ),
                      label: const Text(
                        '次の目的地にする',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // 大きなスタンプ
  // ============================================================

  Widget _buildLargeStampVisual(
    Seichi seichi,
    bool collected,
  ) {
    return Container(
      width: 165,
      height: 165,
      decoration:
          BoxDecoration(
        shape: BoxShape.circle,
        color: collected
            ? const Color(0xFFE6F6E9)
            : Colors.grey.shade100,
        border: Border.all(
          color: collected
              ? Colors.green
              : Colors.grey.shade300,
          width: 4,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (collected)
            Positioned.fill(
              child: CustomPaint(
                painter:
                    const StampRingPainter(
                  large: true,
                ),
              ),
            ),
          Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                seichi.card,
                style: TextStyle(
                  fontSize: 62,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: collected
                      ? Colors.green
                      : Colors.grey.shade300,
                ),
              ),
              const SizedBox(height: 5),
              if (collected)
                Text(
                  seichi.icon,
                  style:
                      const TextStyle(
                    fontSize: 32,
                  ),
                )
              else
                Icon(
                  Icons.question_mark_rounded,
                  size: 32,
                  color: Colors.grey.shade500,
                ),
              const SizedBox(height: 3),
              Text(
                collected
                    ? 'STAMP GET'
                    : 'LOCKED',
                style:
                    TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  color: collected
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // クエスト画面
  // ============================================================

}
