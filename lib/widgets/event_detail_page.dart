import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/event.dart';
import '../models/quest_item.dart';
import '../policies/quest_event_presentation_policy.dart';
import '../policies/quest_event_theme_policy.dart';
import '../services/event_progress_service.dart';
import 'quest_spot_detail_sheet.dart';
import 'quest_ui.dart';
import '../services/app_logger.dart';
import '../services/quest_item_service.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    this.currentPosition,
    this.collectedCount,
    this.totalCount,
    this.participationLabel = '選択中',
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onSelectAnotherEvent,
    this.currentNextSeichiId,
    this.onSetNextDestination,
    this.onShowOnMap,
    this.onStartRecommendedRoute,
  });

  final Event event;
  final Position? currentPosition;

  final int? collectedCount;
  final int? totalCount;

  final String participationLabel;

  final String? primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;

  final Future<void> Function()? onSelectAnotherEvent;

  final String? currentNextSeichiId;
  final ValueChanged<QuestItem>? onSetNextDestination;
  final ValueChanged<QuestItem>? onShowOnMap;
  final ValueChanged<List<QuestItem>>? onStartRecommendedRoute;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  static const QuestEventThemePolicy _eventThemePolicy = QuestEventThemePolicy();

  QuestEventTheme get _eventTheme => _eventThemePolicy.resolve(widget.event);

  bool _isActionRunning = false;

  bool _isLoadingQuestItem = true;
  String? _questItemErrorMessage;

  List<QuestItem> _questItems = [];

  final Set<String> _collectedSeichiIds = <String>{};

  String _galleryFilter = 'すべて';

  bool _isLoadingGeoScopes = false;
  List<Map<String, dynamic>> _geoScopes = <Map<String, dynamic>>[];
  String? _selectedGeoRegionCode;
  EventProgressSummary? _progressSummary;
  bool _isLoadingMoreItems = false;
  bool _pagingExhausted = false;
  int _itemRequestGeneration = 0;

  bool _supportsGeoScopes = false;

  bool _isLoadingSocialStats = true;
  bool _isFavoriteUpdating = false;
  int? _participantCount;
  int? _favoriteCount;
  bool _isFavorited = false;

  final QuestItemService _questItemService = QuestItemService();
  final EventProgressService _progressService = EventProgressService();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializeQuestItems();
    _loadSocialStats();
  }

  Future<void> _initializeQuestItems() async {
    try {
      final data = await _client.rpc(
        'get_event_geo_scopes',
        params: {'p_event_id': widget.event.id},
      );
      final rows = List<Map<String, dynamic>>.from(data as List);
      if (!mounted) return;
      _supportsGeoScopes = rows.isNotEmpty;
      if (_supportsGeoScopes) {
        await _loadGeoScopes(prefetchedRows: rows);
      } else {
        await _loadSeichiList();
      }
    } catch (error) {
      appDebugPrint('[EVENT_DETAIL] geo capability check failed: $error');
      if (!mounted) return;
      await _loadSeichiList();
    }
  }

  Future<void> _loadSeichiList({String? regionCode}) async {
    final generation = ++_itemRequestGeneration;
    final eventId = widget.event.id;
    try {
      final summary = await _progressService.load(widget.event.id);
      final list = regionCode == null
          ? (summary.totalCount > 200
              ? await _questItemService.loadActiveItemsPage(
                  eventId: widget.event.id,
                  limit: 100,
                )
              : await _questItemService.loadActiveItems(widget.event.id))
          : await _questItemService.loadActiveItemsForRegion(
              eventId: widget.event.id,
              regionCode: regionCode,
            );

      final collectedIds = <String>{};
      final user = _client.auth.currentUser;

      if (user != null) {
        try {
          final historyData = await _client
              .from('collection_history')
              .select('event_content_id')
              .eq('user_id', user.id)
              .eq('event_id', widget.event.id);

          for (final row in List<Map<String, dynamic>>.from(historyData)) {
            final questItemId = row['event_content_id']?.toString() ?? '';

            if (questItemId.isNotEmpty) {
              collectedIds.add(questItemId);
            }
          }
        } catch (error, stackTrace) {
          appDebugPrint(
            '[EVENT_DETAIL] collection history load failed: $error',
          );
          appDebugPrint(
            '[EVENT_DETAIL] collection history stackTrace: $stackTrace',
          );
        }
      }

      if (!mounted ||
          generation != _itemRequestGeneration ||
          eventId != widget.event.id ||
          regionCode != _selectedGeoRegionCode) {
        return;
      }

      setState(() {
        _questItems = list;
        _pagingExhausted =
            regionCode != null ||
            list.isEmpty ||
            list.length >= summary.totalCount;
        _progressSummary = summary;

        _collectedSeichiIds
          ..clear()
          ..addAll(collectedIds);

        _isLoadingQuestItem = false;
        _questItemErrorMessage = null;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT_DETAIL] quest item load failed: $error');
      appDebugPrint('[EVENT_DETAIL] quest item load stackTrace: $stackTrace');

      if (!mounted ||
          generation != _itemRequestGeneration ||
          eventId != widget.event.id ||
          regionCode != _selectedGeoRegionCode) {
        return;
      }

      setState(() {
        _isLoadingQuestItem = false;
        _questItemErrorMessage = '${widget.event.itemLabelPlural}情報を読み込めませんでした。';
      });
    }
  }

  bool get _hasMoreItems =>
      !_pagingExhausted &&
      _selectedGeoRegionCode == null &&
      (_progressSummary?.totalCount ?? _questItems.length) > _questItems.length;

  Future<void> _loadMoreItems() async {
    if (_isLoadingMoreItems || !_hasMoreItems) return;
    final generation = _itemRequestGeneration;
    final eventId = widget.event.id;
    final offset = _questItems.length;
    setState(() => _isLoadingMoreItems = true);
    try {
      final next = await _questItemService.loadActiveItemsPage(
        eventId: eventId,
        offset: offset,
        limit: 100,
      );
      if (!mounted ||
          generation != _itemRequestGeneration ||
          eventId != widget.event.id ||
          _selectedGeoRegionCode != null) {
        return;
      }
      if (next.isEmpty) {
        setState(() => _pagingExhausted = true);
        return;
      }
      final byId = <String, QuestItem>{
        for (final item in _questItems) item.id: item,
        for (final item in next) item.id: item,
      };
      final merged = byId.values.toList(growable: false)
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      setState(() {
        _questItems = List<QuestItem>.unmodifiable(merged);
        if (_questItems.length >=
            (_progressSummary?.totalCount ?? _questItems.length)) {
          _pagingExhausted = true;
        }
      });
    } catch (error) {
      appDebugPrint('[EVENT_DETAIL] load more failed: $error');
    } finally {
      if (mounted &&
          generation == _itemRequestGeneration &&
          eventId == widget.event.id &&
          _selectedGeoRegionCode == null) {
        setState(() => _isLoadingMoreItems = false);
      }
    }
  }

  Future<void> _loadGeoScopes({List<Map<String, dynamic>>? prefetchedRows}) async {
    setState(() {
      _isLoadingGeoScopes = true;
    });

    try {
      final rows = prefetchedRows ??
          List<Map<String, dynamic>>.from(
            (await _client.rpc(
              'get_event_geo_scopes',
              params: {'p_event_id': widget.event.id},
            )) as List,
          );

      String? initialCode;
      final prefecture = widget.event.prefecture;
      if (prefecture != null && prefecture.isNotEmpty) {
        for (final row in rows) {
          if (row['region_level'] == 'prefecture' &&
              row['region_name'] == prefecture) {
            initialCode = row['region_code']?.toString();
            break;
          }
        }
      }
      if (initialCode == null) {
        for (final row in rows) {
          if (row['region_level'] == 'prefecture') {
            initialCode = row['region_code']?.toString();
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _geoScopes = rows;
        _selectedGeoRegionCode = initialCode;
        _isLoadingGeoScopes = false;
      });

      if (initialCode != null) {
        await _loadSeichiList(regionCode: initialCode);
      } else {
        await _loadSeichiList();
      }
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT_DETAIL] geo scope load failed: $error');
      appDebugPrint('[EVENT_DETAIL] geo scope stackTrace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoadingGeoScopes = false;
      });
      await _loadSeichiList();
    }
  }

  Future<void> _loadSocialStats() async {
    try {
      final data = await _client.rpc(
        'get_event_social_stats',
        params: {'p_event_id': widget.event.id},
      );

      final rows = data is List
          ? List<Map<String, dynamic>>.from(data)
          : <Map<String, dynamic>>[];

      final row = rows.isNotEmpty ? rows.first : <String, dynamic>{};

      final participantCount = _toIntOrZero(row['participant_count']);

      final favoriteCount = _toIntOrZero(row['favorite_count']);

      final isFavorited = row['is_favorited'] == true;

      if (!mounted) {
        return;
      }

      setState(() {
        _participantCount = participantCount;

        _favoriteCount = favoriteCount;

        _isFavorited = isFavorited;

        _isLoadingSocialStats = false;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT_DETAIL] social stats load failed: $error');

      appDebugPrint('[EVENT_DETAIL] social stats stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingSocialStats = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteUpdating) {
      return;
    }

    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    final wasFavorited = _isFavorited;

    setState(() {
      _isFavoriteUpdating = true;
    });

    try {
      if (wasFavorited) {
        await _client
            .from('user_event_favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('event_id', widget.event.id);
      } else {
        await _client.from('user_event_favorites').insert({
          'user_id': user.id,
          'event_id': widget.event.id,
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isFavorited = !wasFavorited;

        final currentCount = _favoriteCount ?? 0;

        _favoriteCount = wasFavorited
            ? (currentCount > 0 ? currentCount - 1 : 0)
            : currentCount + 1;

        _isFavoriteUpdating = false;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT_DETAIL] favorite toggle failed: $error');

      appDebugPrint('[EVENT_DETAIL] favorite toggle stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isFavoriteUpdating = false;
      });

      QuestSnackBar.show(
        context,
        message: 'お気に入りの更新に失敗しました。',
        type: QuestNoticeType.error,
      );
    }
  }

  int _toIntOrZero(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  QuestItem? get _nearestUncollectedQuestItem {
    // A paged catalogue is only a partial scope. Do not present a local
    // minimum as the nearest destination for the whole event/region.
    if (_hasMoreItems) {
      return null;
    }

    final position = widget.currentPosition;

    if (position == null) {
      return null;
    }

    QuestItem? nearest;
    double? nearestDistance;

    for (final seichi in _questItems) {
      if (_collectedSeichiIds.contains(seichi.id)) {
        continue;
      }

      if (seichi.latitude == 0.0 && seichi.longitude == 0.0) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        seichi.latitude,
        seichi.longitude,
      );

      if (nearestDistance == null || distance < nearestDistance) {
        nearest = seichi;
        nearestDistance = distance;
      }
    }

    return nearest;
  }

  double? _distanceFromCurrentPosition(QuestItem seichi) {
    final position = widget.currentPosition;

    if (position == null) {
      return null;
    }

    if (seichi.latitude == 0.0 && seichi.longitude == 0.0) {
      return null;
    }

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      seichi.latitude,
      seichi.longitude,
    );
  }

  List<QuestItem> get _filteredSeichiList {
    switch (_galleryFilter) {
      case '獲得済み':
        return _questItems
            .where((seichi) => _collectedSeichiIds.contains(seichi.id))
            .toList(growable: false);

      case '未獲得':
        return _questItems
            .where((seichi) => !_collectedSeichiIds.contains(seichi.id))
            .toList(growable: false);

      default:
        return _questItems;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '未設定';
    }

    final local = value.toLocal();

    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  String _periodText() {
    if (widget.event.startAt == null && widget.event.endAt == null) {
      return '開催期間の設定なし';
    }

    if (widget.event.startAt != null && widget.event.endAt != null) {
      return '${_formatDate(widget.event.startAt)}'
          ' 〜 '
          '${_formatDate(widget.event.endAt)}';
    }

    if (widget.event.startAt != null) {
      return '${_formatDate(widget.event.startAt)} 〜';
    }

    return '〜 ${_formatDate(widget.event.endAt)}';
  }

  String _eventStatusText() {
    return widget.event.eventStatusText();
  }

  static const QuestEventPresentationPolicy _eventPresentationPolicy =
      QuestEventPresentationPolicy();

  Color _participationColor() {
    final presentation =
        _eventPresentationPolicy.fromLabel(widget.participationLabel);
    if (presentation.state == QuestParticipationState.selected) {
      return _eventTheme.primary;
    }
    return presentation.color;
  }

  bool get _hasProgress {
    return widget.collectedCount != null && widget.totalCount != null;
  }

  double get _progress {
    final collected = widget.collectedCount;
    final total = widget.totalCount;

    if (collected == null || total == null || total <= 0) {
      return 0;
    }

    return (collected / total).clamp(0.0, 1.0);
  }

  int get _progressPercent {
    return (_progress * 100).round();
  }

  Future<void> _runPrimaryAction() async {
    final action = widget.onPrimaryAction;

    if (action == null || _isActionRunning) {
      return;
    }

    setState(() {
      _isActionRunning = true;
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isActionRunning = false;
      });
    }
  }

  void _showSeichiDetail(QuestItem seichi) {
    final collected = _collectedSeichiIds.contains(seichi.id);
    final isNext = widget.currentNextSeichiId == seichi.id;

    QuestSpotDetailSheet.show(
      context,
      item: seichi,
      collected: collected,
      isNext: isNext,
      onShowOnMap: widget.onShowOnMap == null
          ? null
          : () => widget.onShowOnMap!(seichi),
      onSetNextDestination:
          widget.onSetNextDestination == null || collected || isNext
          ? null
          : () => widget.onSetNextDestination!(seichi),
    );
  }

  Widget _buildSocialStatsCard() {
    return QuestGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups_2_rounded,
                size: 20,
                color: _eventTheme.primary,
              ),
              SizedBox(width: 8),
              Text(
                'クエスト情報',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: QuestUiTokens.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_isLoadingSocialStats)
            SizedBox(
              height: 54,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _eventTheme.primary,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildSocialStatItem(
                    icon: Icons.people_alt_outlined,
                    label: '参加中',
                    value: _participantCount == null
                        ? '−'
                        : '${_participantCount!}人',
                    color: _eventTheme.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSocialStatItem(
                    icon: _isFavorited ? Icons.favorite : Icons.favorite_border,
                    label: 'お気に入り',
                    value: _favoriteCount == null ? '−' : '${_favoriteCount!}件',
                    color: _isFavorited ? Colors.pink : QuestUiTokens.primary,
                    onTap: _isFavoriteUpdating ? null : _toggleFavorite,
                    isLoading: _isFavoriteUpdating,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSocialStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icon, size: 21, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
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
        ),
      ),
    );
  }

  Widget _buildNearestUncollectedCard() {
    final seichi = _nearestUncollectedQuestItem;

    if (seichi == null) {
      return const SizedBox.shrink();
    }

    final distance = _distanceFromCurrentPosition(seichi);
    final isNext = widget.currentNextSeichiId == seichi.id;

    String? distanceText;

    if (distance != null) {
      distanceText = distance < 1000
          ? '${distance.round()}m'
          : '${(distance / 1000).toStringAsFixed(1)}km';
    }

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
                  gradient: _eventTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.near_me_rounded,
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
                      'NEXT SPOT',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '最寄りの未獲得地点',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (isNext)
                const QuestStatusChip(
                  label: 'NEXT',
                  icon: Icons.navigation_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _eventTheme.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: _eventTheme.primary.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _eventTheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    seichi.contentKey,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _eventTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seichi.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: QuestUiTokens.ink,
                        ),
                      ),
                      if (distanceText != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 15,
                              color: QuestUiTokens.mutedInk,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '現在地から $distanceText',
                              style: const TextStyle(
                                fontSize: 12,
                                color: QuestUiTokens.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: QuestPrimaryButton(
              label: isNext ? '次の目的地に設定済み' : '次の目的地に設定',
              icon: isNext
                  ? Icons.check_circle_outline
                  : Icons.navigation_outlined,
              onPressed: widget.onSetNextDestination == null || isNext
                  ? null
                  : () {
                      widget.onSetNextDestination!(seichi);

                      if (!mounted) {
                        return;
                      }

                      setState(() {});
                    },
            ),
          ),
        ],
      ),
    );
  }

  List<QuestItem> _buildRecommendedRoute() {
    final position = widget.currentPosition;

    // A paged catalogue is only a partial event view. Building a route from it
    // would silently omit destinations, so route generation stays disabled
    // until the selected scope is fully loaded.
    if (_hasMoreItems) {
      return const <QuestItem>[];
    }

    if (position == null) {
      return const <QuestItem>[];
    }

    final remaining = _questItems
        .where(
          (seichi) =>
              !_collectedSeichiIds.contains(seichi.id) &&
              !(seichi.latitude == 0.0 && seichi.longitude == 0.0),
        )
        .toList();

    if (remaining.isEmpty) {
      return const <QuestItem>[];
    }

    final route = <QuestItem>[];

    var currentLatitude = position.latitude;
    var currentLongitude = position.longitude;

    while (remaining.isNotEmpty) {
      QuestItem? nearest;
      double? nearestDistance;

      for (final seichi in remaining) {
        final distance = Geolocator.distanceBetween(
          currentLatitude,
          currentLongitude,
          seichi.latitude,
          seichi.longitude,
        );

        if (nearestDistance == null || distance < nearestDistance) {
          nearest = seichi;
          nearestDistance = distance;
        }
      }

      if (nearest == null) {
        break;
      }

      route.add(nearest);
      remaining.remove(nearest);

      currentLatitude = nearest.latitude;
      currentLongitude = nearest.longitude;
    }

    return route;
  }

  String _formatRouteDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    }

    return '${(distance / 1000).toStringAsFixed(1)}km';
  }

  void _showRecommendedRoute() {
    final route = _buildRecommendedRoute();

    if (route.isEmpty) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F8FC),
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_eventTheme.accent, _eventTheme.primary]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.route_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SMART ROUTE',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w900,
                                  color: QuestUiTokens.mutedInk,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'おすすめ巡回ルート',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: QuestUiTokens.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: _eventTheme.primary.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      itemCount: route.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final seichi = route[index];

                        double distance;

                        if (index == 0) {
                          final position = widget.currentPosition!;

                          distance = Geolocator.distanceBetween(
                            position.latitude,
                            position.longitude,
                            seichi.latitude,
                            seichi.longitude,
                          );
                        } else {
                          final previous = route[index - 1];

                          distance = Geolocator.distanceBetween(
                            previous.latitude,
                            previous.longitude,
                            seichi.latitude,
                            seichi.longitude,
                          );
                        }

                        final isNext = widget.currentNextSeichiId == seichi.id;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(17),
                            onTap: () {
                              _showSeichiDetail(seichi);
                            },
                            child: Ink(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(
                                  color: isNext
                                      ? QuestUiTokens.primary.withValues(
                                          alpha: 0.30,
                                        )
                                      : QuestUiTokens.ink.withValues(
                                          alpha: 0.06,
                                        ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: _eventTheme.primaryGradient,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: QuestUiTokens.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      seichi.contentKey,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: _eventTheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          seichi.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: QuestUiTokens.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          index == 0
                                              ? '現在地から ${_formatRouteDistance(distance)}'
                                              : '前の地点から ${_formatRouteDistance(distance)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: QuestUiTokens.mutedInk,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isNext)
                                    Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.navigation_rounded,
                                        size: 20,
                                        color: _eventTheme.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (widget.onStartRecommendedRoute != null) ...[
                    Divider(
                      height: 1,
                      color: _eventTheme.primary.withValues(alpha: 0.08),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: QuestPrimaryButton(
                        label: 'このルートでスタート',
                        icon: Icons.flag_rounded,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();

                          widget.onStartRecommendedRoute!(
                            List<QuestItem>.unmodifiable(route),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecommendedRouteCard() {
    final route = _buildRecommendedRoute();

    if (route.length < 2) {
      return const SizedBox.shrink();
    }

    double totalDistance = 0;

    final position = widget.currentPosition!;

    totalDistance += Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      route.first.latitude,
      route.first.longitude,
    );

    for (var i = 1; i < route.length; i++) {
      totalDistance += Geolocator.distanceBetween(
        route[i - 1].latitude,
        route[i - 1].longitude,
        route[i].latitude,
        route[i].longitude,
      );
    }

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
                  gradient: LinearGradient(colors: [_eventTheme.accent, _eventTheme.primary]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.route_rounded,
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
                      'SMART ROUTE',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'おすすめ巡回ルート',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: QuestUiTokens.cyan.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '残り ${route.length}地点',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: QuestUiTokens.ink,
                    ),
                  ),
                ),
                Text(
                  '約${_formatRouteDistance(totalDistance)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showRecommendedRoute,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: _eventTheme.primary,
                side: BorderSide(
                  color: QuestUiTokens.primary.withValues(alpha: 0.18),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    QuestUiTokens.controlRadius,
                  ),
                ),
              ),
              icon: const Icon(Icons.route_outlined),
              label: const Text(
                '巡回する順番を見る',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (widget.onStartRecommendedRoute != null) ...[
            const SizedBox(height: 10),
            QuestPrimaryButton(
              label: 'このルートでスタート',
              icon: Icons.flag_rounded,
              onPressed: () {
                widget.onStartRecommendedRoute!(
                  List<QuestItem>.unmodifiable(route),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeoScopeSelector() {
    if (!_supportsGeoScopes) return const SizedBox.shrink();

    if (_isLoadingGeoScopes) {
      return const QuestGlassCard(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final rows = _geoScopes;
    if (rows.isEmpty) return const SizedBox.shrink();

    final prefectures =
        rows.where((row) => row['region_level'] == 'prefecture').toList();
    final regional =
        rows.where((row) => row['region_level'] == 'regional').toList();
    final national =
        rows.where((row) => row['region_level'] == 'national').toList();

    Widget progressRows(String title, List<Map<String, dynamic>> scopes) {
      if (scopes.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...scopes.map((row) {
            final name = row['region_name']?.toString() ?? '';
            final collected = (row['collected_count'] as num?)?.toInt() ?? 0;
            final total = (row['total_count'] as num?)?.toInt() ?? 0;
            final percent = total == 0 ? 0.0 : collected / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text('$collected/$total',
                        style: const TextStyle(
                            color: QuestUiTokens.mutedInk,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(value: percent.clamp(0.0, 1.0)),
                ],
              ),
            );
          }),
        ],
      );
    }

    return QuestGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('攻略状況',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                  color: QuestUiTokens.ink)),
          const SizedBox(height: 6),
          Text('地域は表示制限ではありません。移動先の${widget.event.itemLabelPlural}は現在地に合わせて自動で切り替わります。',
              style: TextStyle(fontSize: 12, color: QuestUiTokens.mutedInk)),
          const SizedBox(height: 14),
          progressRows('都道府県', prefectures),
          if (regional.isNotEmpty) ...[
            const SizedBox(height: 8),
            progressRows('地方', regional),
          ],
          if (national.isNotEmpty) ...[
            const SizedBox(height: 8),
            progressRows('全国', national),
          ],
        ],
      ),
    );
  }

  Widget _buildCardGallery() {
    final filteredList = _filteredSeichiList;

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
                  gradient: _eventTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COLLECTION',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${widget.event.itemLabelPlural}ギャラリー',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isLoadingQuestItem && _questItems.isNotEmpty)
                QuestStatusChip(
                  label: '${filteredList.length} / ${_selectedGeoRegionCode == null ? (_progressSummary?.totalCount ?? _questItems.length) : _questItems.length}${widget.event.itemLabelPlural}',
                  accentColor: _eventTheme.accent,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.event.itemLabelSingular}をタップすると詳細を確認できます',
            style: TextStyle(fontSize: 12, color: QuestUiTokens.mutedInk),
          ),
          if (!_isLoadingQuestItem &&
              _questItemErrorMessage == null &&
              _questItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in const <String>['すべて', '獲得済み', '未獲得'])
                  Builder(
                    builder: (context) {
                      final isSelected = _galleryFilter == filter;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _galleryFilter = filter;
                            });
                          },
                          borderRadius: BorderRadius.circular(99),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? QuestUiTokens.primaryGradient
                                  : null,
                              color: isSelected ? null : Colors.white,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : QuestUiTokens.ink.withValues(alpha: 0.07),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: QuestUiTokens.primary.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? Colors.white
                                        : QuestUiTokens.mutedInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (_isLoadingQuestItem)
            const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(color: QuestUiTokens.primary),
              ),
            )
          else if (_questItemErrorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 8),
                  Text(_questItemErrorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoadingQuestItem = true;
                        _questItemErrorMessage = null;
                      });

                      _loadSeichiList(
                        regionCode: _selectedGeoRegionCode,
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('再読み込み'),
                  ),
                ],
              ),
            )
          else if (_questItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: QuestUiTokens.ink.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'このクエストには${widget.event.itemLabelPlural}が登録されていません。',
                textAlign: TextAlign.center,
                style: TextStyle(color: QuestUiTokens.mutedInk),
              ),
            )
          else if (filteredList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: QuestUiTokens.ink.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _galleryFilter == '獲得済み' ? '獲得済みの${widget.event.itemLabelPlural}はまだありません。' : '未獲得の${widget.event.itemLabelPlural}はありません。',
                textAlign: TextAlign.center,
                style: const TextStyle(color: QuestUiTokens.mutedInk),
              ),
            )
          else
            Column(
              children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                return _buildGalleryCard(filteredList[index]);
              },
            ),
            if (_hasMoreItems) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _isLoadingMoreItems ? null : _loadMoreItems,
                icon: _isLoadingMoreItems
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.expand_more_rounded),
                label: Text(_isLoadingMoreItems ? '読み込み中…' : '続きを読み込む'),
              ),
            ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGalleryCard(QuestItem seichi) {
    final imageUrl = seichi.primaryImageUrl;
    final collected = _collectedSeichiIds.contains(seichi.id);
    final isNext = widget.currentNextSeichiId == seichi.id;

    final accent = collected
        ? Colors.green
        : isNext
        ? QuestUiTokens.primary
        : QuestUiTokens.mutedInk;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showSeichiDetail(seichi);
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(
                alpha: collected || isNext ? 0.34 : 0.10,
              ),
              width: collected || isNext ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: QuestUiTokens.ink.withValues(alpha: 0.045),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          cacheWidth: 360,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildGalleryFallback(seichi);
                          },
                        )
                      : _buildGalleryFallback(seichi),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        seichi.contentKey,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        seichi.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: QuestUiTokens.ink,
                        ),
                      ),
                    ),
                    if (collected) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.green,
                      ),
                    ] else if (isNext) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: _eventTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'NEXT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryFallback(QuestItem seichi) {
    return Container(
      color: QuestUiTokens.primary.withValues(alpha: 0.045),
      alignment: Alignment.center,
      child: Text(
        seichi.contentKey,
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: _eventTheme.primary,
        ),
      ),
    );
  }

  Future<void> _shareEvent(BuildContext shareButtonContext) async {
    final eventName = widget.event.name.trim();
    final prefecture = widget.event.prefecture?.trim();
    final slug = widget.event.slug.trim();

    final buffer = StringBuffer()
      ..writeln('聖地クエスト')
      ..writeln()
      ..writeln('「$eventName」に挑戦しよう！');

    if (prefecture != null && prefecture.isNotEmpty) {
      buffer.writeln('エリア: $prefecture');
    }

    if (slug.isNotEmpty) {
      buffer.writeln('クエスト: $slug');
    }

    buffer
      ..writeln()
      ..write('${widget.event.itemLabelPlural}を巡って、スタンプを集めよう！');

    final renderBox = shareButtonContext.findRenderObject() as RenderBox?;

    final sharePositionOrigin = renderBox != null && renderBox.hasSize
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: eventName,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (error) {
      appDebugPrint('[SHARE] event share failed: $error');

      if (!mounted) {
        return;
      }

      QuestSnackBar.show(
        context,
        message: 'クエストを共有できませんでした。',
        type: QuestNoticeType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final participationColor = _participationColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'クエスト詳細',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        foregroundColor: QuestUiTokens.ink,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Builder(
            builder: (shareButtonContext) {
              return IconButton(
                tooltip: 'クエストを共有',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => _shareEvent(shareButtonContext),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            QuestGlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.event.coverImageUrl != null &&
                      widget.event.coverImageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          widget.event.coverImageUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 1200,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: QuestUiTokens.primary.withValues(
                                alpha: 0.045,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: QuestUiTokens.mutedInk,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _eventTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: QuestUiTokens.primary.withValues(
                                alpha: 0.20,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.explore_rounded,
                          color: Colors.white,
                          size: 29,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUEST',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.mutedInk,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.event.name,
                              style: const TextStyle(
                                fontSize: 21,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.ink,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _buildStatusChip(
                                  _eventStatusText(),
                                  Colors.green,
                                ),
                                _buildStatusChip(
                                  widget.participationLabel,
                                  participationColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: QuestUiTokens.primary.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.event.description,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.65,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (widget.primaryActionLabel != null &&
                widget.onPrimaryAction != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: _eventTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(
                    QuestUiTokens.controlRadius,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: QuestUiTokens.primary.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _isActionRunning ? null : _runPrimaryAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: QuestUiTokens.mutedInk.withValues(
                      alpha: 0.30,
                    ),
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        QuestUiTokens.controlRadius,
                      ),
                    ),
                  ),
                  icon: _isActionRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    widget.primaryActionLabel!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            QuestGlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: QuestUiTokens.cyan.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: _eventTheme.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '開催情報',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _periodText(),
                          style: const TextStyle(
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

            const SizedBox(height: 14),

            _buildSocialStatsCard(),

            if (_supportsGeoScopes) ...[
              const SizedBox(height: 14),
              _buildGeoScopeSelector(),
            ],

            if (_hasProgress) ...[
              const SizedBox(height: 14),

              QuestGlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_eventTheme.accent, _eventTheme.primary]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_graph_rounded,
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
                                'PROGRESS',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w900,
                                  color: QuestUiTokens.mutedInk,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'クエスト進捗',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: QuestUiTokens.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$_progressPercent%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _eventTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${widget.collectedCount}',
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.ink,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 5, bottom: 2),
                          child: Text(
                            '/ ${widget.totalCount} SPOTS',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: QuestUiTokens.mutedInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 9,
                        backgroundColor: QuestUiTokens.primary.withValues(
                          alpha: 0.08,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          QuestUiTokens.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      widget.totalCount != null &&
                              widget.collectedCount != null &&
                              widget.totalCount! > 0
                          ? widget.collectedCount! >= widget.totalCount!
                                ? '完全制覇！'
                                : 'あと'
                                      '${widget.totalCount! - widget.collectedCount!}'
                                      '${widget.event.itemLabelPlural}で完全制覇'
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            widget.collectedCount != null &&
                                widget.totalCount != null &&
                                widget.collectedCount! >= widget.totalCount!
                            ? Colors.green
                            : QuestUiTokens.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            _buildNearestUncollectedCard(),

            const SizedBox(height: 14),

            _buildRecommendedRouteCard(),

            const SizedBox(height: 14),

            _buildCardGallery(),

            if (widget.onSelectAnotherEvent != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget.onSelectAnotherEvent!();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: _eventTheme.primary,
                    side: BorderSide(
                      color: QuestUiTokens.primary.withValues(alpha: 0.22),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        QuestUiTokens.controlRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text(
                    '別のクエストを見る',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return QuestStatusChip(label: label, accentColor: color);
  }
}
