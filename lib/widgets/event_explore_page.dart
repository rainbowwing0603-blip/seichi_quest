import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/event.dart';
import '../policies/quest_event_presentation_policy.dart';
import '../policies/quest_event_theme_policy.dart';
import '../models/quest_item.dart';
import 'event_detail_page.dart';
import 'quest_ui.dart';
import '../services/app_logger.dart';

class EventExplorePage extends StatefulWidget {
  const EventExplorePage({
    super.key,
    required this.events,
    required this.currentPosition,
    required this.currentEventId,
    required this.currentCollectedCount,
    required this.currentTotalCount,
    this.currentNextSeichiId,
    this.onSetNextDestination,
    this.onShowOnMap,
    this.onStartRecommendedRoute,
    this.initialFavoriteOnly = false,
  });

  final List<Event> events;
  final Position? currentPosition;
  final String? currentEventId;
  final int currentCollectedCount;
  final int currentTotalCount;
  final String? currentNextSeichiId;
  final ValueChanged<QuestItem>? onSetNextDestination;
  final ValueChanged<QuestItem>? onShowOnMap;
  final ValueChanged<List<QuestItem>>? onStartRecommendedRoute;
  final bool initialFavoriteOnly;

  @override
  State<EventExplorePage> createState() => _EventExplorePageState();
}

class _EventExplorePageState extends State<EventExplorePage> {
  static const QuestEventThemePolicy _eventThemePolicy = QuestEventThemePolicy();

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, bool> _participationStates = {};

  final Map<String, double> _nearestDistanceByEventId = {};
  final Map<String, String> _nearestPlaceNameByEventId = {};

  final Set<String> _favoriteEventIds = <String>{};

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _statusFilter = 'すべて';
  String _periodFilter = 'すべて';
  String _prefectureFilter = 'すべて';
  String _sortOrder = '標準';
  bool _favoriteOnly = false;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _favoriteOnly = widget.initialFavoriteOnly;
    _loadParticipationStates();
    _loadNearestEventDistances();
    _loadFavoriteEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNearestEventDistances() async {
    final position = widget.currentPosition;

    if (position == null) {
      return;
    }

    try {
      final data = await _client
          .from('event_contents')
          .select(
            'event_id, is_active, '
            'places(name, latitude, longitude, is_active)',
          )
          .eq('is_active', true);

      final rows = List<Map<String, dynamic>>.from(data);

      final distances = <String, double>{};
      final placeNames = <String, String>{};

      for (final row in rows) {
        final eventId = row['event_id']?.toString();

        if (eventId == null || eventId.isEmpty) {
          continue;
        }

        final placeData = row['places'];

        if (placeData is! Map) {
          continue;
        }

        final place = Map<String, dynamic>.from(placeData);

        if (place['is_active'] != true) {
          continue;
        }

        final latitude = (place['latitude'] as num?)?.toDouble();

        final longitude = (place['longitude'] as num?)?.toDouble();

        if (latitude == null || longitude == null) {
          continue;
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        );

        final current = distances[eventId];

        if (current == null || distance < current) {
          distances[eventId] = distance;

          final placeName = place['name']?.toString().trim();

          if (placeName != null && placeName.isNotEmpty) {
            placeNames[eventId] = placeName;
          } else {
            placeNames.remove(eventId);
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _nearestDistanceByEventId
          ..clear()
          ..addAll(distances);

        _nearestPlaceNameByEventId
          ..clear()
          ..addAll(placeNames);
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT] nearest distance load failed: $error');
      appDebugPrint('[EVENT] nearest distance stackTrace: $stackTrace');
    }
  }

  Future<void> _loadFavoriteEvents() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final data = await _client
          .from('user_event_favorites')
          .select('event_id')
          .eq('user_id', user.id);

      final rows = List<Map<String, dynamic>>.from(data);

      final ids = <String>{};

      for (final row in rows) {
        final eventId = row['event_id']?.toString();

        if (eventId == null || eventId.isEmpty) {
          continue;
        }

        ids.add(eventId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _favoriteEventIds
          ..clear()
          ..addAll(ids);
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT] favorite load failed: $error');
      appDebugPrint('[EVENT] favorite load stackTrace: $stackTrace');
    }
  }

  Future<void> _toggleFavorite(Event event) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    final isFavorite = _favoriteEventIds.contains(event.id);

    try {
      if (isFavorite) {
        await _client
            .from('user_event_favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('event_id', event.id);
      } else {
        await _client.from('user_event_favorites').insert({
          'user_id': user.id,
          'event_id': event.id,
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        if (isFavorite) {
          _favoriteEventIds.remove(event.id);
        } else {
          _favoriteEventIds.add(event.id);
        }
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT] favorite toggle failed: $error');
      appDebugPrint('[EVENT] favorite toggle stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }
      QuestSnackBar.show(
        context,
        message: 'お気に入りの更新に失敗しました。',
        type: QuestNoticeType.error,
      );
    }
  }

  Future<void> _loadParticipationStates() async {
    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _participationStates = {};
          _isLoading = false;
        });

        return;
      }

      final data = await _client
          .from('user_event_participations')
          .select('event_id, is_active')
          .eq('user_id', user.id);

      final rows = List<Map<String, dynamic>>.from(data);

      final states = <String, bool>{};

      for (final row in rows) {
        final eventId = row['event_id']?.toString();

        if (eventId == null || eventId.isEmpty) {
          continue;
        }

        states[eventId] = row['is_active'] == true;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _participationStates = states;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT] explore participation load failed: $error');
      appDebugPrint('[EVENT] explore participation stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'クエスト情報を読み込めませんでした。';
      });
    }
  }

  static const QuestEventPresentationPolicy _eventPresentationPolicy =
      QuestEventPresentationPolicy();

  QuestEventPresentation _eventPresentation(Event event) {
    final hasRecord = _participationStates.containsKey(event.id);
    return _eventPresentationPolicy.resolve(
      isSelected: event.id == widget.currentEventId,
      hasParticipationRecord: hasRecord,
      isParticipating: _participationStates[event.id] == true,
    );
  }

  String _participationLabel(Event event) => _eventPresentation(event).label;

  Color _statusColor(String label) =>
      _eventPresentationPolicy.fromLabel(label).color;

  IconData _statusIcon(String label) =>
      _eventPresentationPolicy.fromLabel(label).icon;

  String? _primaryActionLabel(String label) =>
      _eventPresentationPolicy.fromLabel(label).primaryActionLabel;

  Future<void> _confirmLeaveEvent(Event event) async {
    if (event.id == widget.currentEventId) {
      QuestSnackBar.show(
        context,
        message: '現在選択中のクエストは参加解除できません。',
        type: QuestNoticeType.warning,
      );
      return;
    }

    if (_participationStates[event.id] != true) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return QuestDialog(
          icon: Icons.flag_outlined,
          title: '参加をやめますか？',
          subtitle: event.name,
          content: const Text('参加をやめても、獲得済みの記録は削除されません。あとからもう一度参加できます。'),
          actionLabel: '参加をやめる',
          onAction: () {
            Navigator.of(dialogContext).pop(true);
          },
          secondaryActionLabel: 'キャンセル',
          onSecondaryAction: () {
            Navigator.of(dialogContext).pop(false);
          },
          isDestructive: true,
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _leaveEvent(event);
  }

  Future<void> _leaveEvent(Event event) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      QuestSnackBar.show(
        context,
        message: '参加情報を更新できませんでした。',
        type: QuestNoticeType.error,
      );
      return;
    }

    if (event.id == widget.currentEventId) {
      QuestSnackBar.show(
        context,
        message: '現在選択中のクエストは参加解除できません。',
        type: QuestNoticeType.warning,
      );
      return;
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _client
          .from('user_event_participations')
          .update({'is_active': false, 'left_at': now, 'updated_at': now})
          .eq('user_id', user.id)
          .eq('event_id', event.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _participationStates[event.id] = false;
      });

      QuestSnackBar.show(
        context,
        message: '${event.name} の参加を解除しました。',
        type: QuestNoticeType.success,
      );
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT] leave participation failed: $error');
      appDebugPrint('[EVENT] leave participation stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      QuestSnackBar.show(
        context,
        message: '参加解除に失敗しました。',
        type: QuestNoticeType.error,
      );
    }
  }

  Future<void> _openEventDetail(Event event) async {
    final label = _participationLabel(event);

    final actionLabel = _primaryActionLabel(label);

    final isCurrent = event.id == widget.currentEventId;

    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          event: event,
          currentPosition: widget.currentPosition,
          participationLabel: label,
          collectedCount: isCurrent ? widget.currentCollectedCount : null,
          totalCount: isCurrent ? widget.currentTotalCount : null,
          currentNextSeichiId: isCurrent ? widget.currentNextSeichiId : null,
          onSetNextDestination: isCurrent ? widget.onSetNextDestination : null,
          onShowOnMap: isCurrent
              ? (seichi) {
                  Navigator.of(context).pop(seichi);
                }
              : null,
          onStartRecommendedRoute: widget.onStartRecommendedRoute == null
              ? null
              : (route) {
                  widget.onStartRecommendedRoute!(route);
                },
          primaryActionLabel: actionLabel,
          onPrimaryAction: actionLabel == null ? null : () async {},
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result is QuestItem) {
      Navigator.of(context).pop(result);
      return;
    }

    if (result == true) {
      Navigator.of(context).pop(event.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: Text(
          widget.initialFavoriteOnly ? 'お気に入りクエスト' : 'クエストを探す',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        foregroundColor: QuestUiTokens.ink,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadParticipationStates,
          color: QuestUiTokens.primary,
          child: _buildBody(),
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(List<String> prefectureOptions) async {
    var temporaryStatus = _statusFilter;
    var temporaryPeriod = _periodFilter;
    var temporaryPrefecture = _prefectureFilter;
    var temporaryFavoriteOnly = _favoriteOnly;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: QuestUiTokens.ink.withValues(alpha: 0.48),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildFilterOption({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: selected ? QuestUiTokens.primaryGradient : null,
                      color: selected
                          ? null
                          : Colors.white.withValues(alpha: 0.72),
                      border: Border.all(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.72)
                            : QuestUiTokens.primary.withValues(alpha: 0.16),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: QuestUiTokens.primary.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : QuestUiTokens.ink,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget buildSection({
              required IconData icon,
              required String title,
              required List<String> options,
              required String selected,
              required ValueChanged<String> onSelected,
              String? helperText,
            }) {
              return QuestGlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: QuestUiTokens.primary.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: QuestUiTokens.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          title,
                          style: const TextStyle(
                            color: QuestUiTokens.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in options)
                          buildFilterOption(
                            label: option,
                            selected: selected == option,
                            onTap: () {
                              onSelected(option);
                            },
                          ),
                      ],
                    ),
                    if (helperText != null && helperText.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: QuestUiTokens.mutedInk,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              helperText,
                              style: const TextStyle(
                                color: QuestUiTokens.mutedInk,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }

            return FractionallySizedBox(
              heightFactor: 0.92,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF6F8FC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 11),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: QuestUiTokens.mutedInk.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: QuestUiTokens.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: QuestUiTokens.primary.withValues(
                                          alpha: 0.24,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'FILTER QUESTS',
                                        style: TextStyle(
                                          color: QuestUiTokens.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.6,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'クエストを絞り込む',
                                        style: TextStyle(
                                          color: QuestUiTokens.ink,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        '条件を組み合わせて、次の冒険を見つけよう',
                                        style: TextStyle(
                                          color: QuestUiTokens.mutedInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            buildSection(
                              icon: Icons.how_to_reg_rounded,
                              title: '参加状態',
                              options: const ['すべて', '未参加', '参加中', '過去に参加'],
                              selected: temporaryStatus,
                              onSelected: (value) {
                                setSheetState(() {
                                  temporaryStatus = value;
                                });
                              },
                              helperText: '「参加中」には現在選択中のクエストも含まれます。',
                            ),
                            const SizedBox(height: 12),
                            buildSection(
                              icon: Icons.event_available_rounded,
                              title: '開催状態',
                              options: const ['すべて', '開催中', '開催前', '終了'],
                              selected: temporaryPeriod,
                              onSelected: (value) {
                                setSheetState(() {
                                  temporaryPeriod = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            buildSection(
                              icon: Icons.location_on_outlined,
                              title: '都道府県',
                              options: <String>['すべて', ...prefectureOptions],
                              selected: temporaryPrefecture,
                              onSelected: (value) {
                                setSheetState(() {
                                  temporaryPrefecture = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            QuestGlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              borderRadius: 20,
                              child: InkWell(
                                onTap: () {
                                  setSheetState(() {
                                    temporaryFavoriteOnly =
                                        !temporaryFavoriteOnly;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: temporaryFavoriteOnly
                                            ? Colors.amber.withValues(
                                                alpha: 0.16,
                                              )
                                            : QuestUiTokens.primary.withValues(
                                                alpha: 0.08,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        temporaryFavoriteOnly
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: temporaryFavoriteOnly
                                            ? Colors.amber.shade700
                                            : QuestUiTokens.primary,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'お気に入りのみ',
                                            style: TextStyle(
                                              color: QuestUiTokens.ink,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            '★を付けたクエストだけ表示',
                                            style: TextStyle(
                                              color: QuestUiTokens.mutedInk,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      width: 48,
                                      height: 28,
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        gradient: temporaryFavoriteOnly
                                            ? QuestUiTokens.primaryGradient
                                            : null,
                                        color: temporaryFavoriteOnly
                                            ? null
                                            : QuestUiTokens.mutedInk.withValues(
                                                alpha: 0.16,
                                              ),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: AnimatedAlign(
                                        duration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        alignment: temporaryFavoriteOnly
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: QuestUiTokens.ink
                                                    .withValues(alpha: 0.14),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.90),
                        border: Border(
                          top: BorderSide(
                            color: QuestUiTokens.primary.withValues(
                              alpha: 0.10,
                            ),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setSheetState(() {
                                  temporaryStatus = 'すべて';
                                  temporaryPeriod = 'すべて';
                                  temporaryPrefecture = 'すべて';
                                  temporaryFavoriteOnly = false;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('リセット'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                foregroundColor: QuestUiTokens.primaryDeep,
                                side: BorderSide(
                                  color: QuestUiTokens.primary.withValues(
                                    alpha: 0.26,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    QuestUiTokens.controlRadius,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: QuestPrimaryButton(
                              label: 'この条件で表示',
                              icon: Icons.check_rounded,
                              onPressed: () {
                                Navigator.of(sheetContext).pop(true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || applied != true) {
      return;
    }

    setState(() {
      _statusFilter = temporaryStatus;
      _periodFilter = temporaryPeriod;
      _prefectureFilter = temporaryPrefecture;
      _favoriteOnly = temporaryFavoriteOnly;
    });
  }

  Widget _buildBody() {
    final query = _searchQuery.trim().toLowerCase();

    final prefectureOptions =
        widget.events
            .map((event) {
              final prefecture = event.prefecture?.trim();

              if (prefecture == null || prefecture.isEmpty) {
                return '未設定';
              }

              return prefecture;
            })
            .toSet()
            .toList(growable: false)
          ..sort();

    final searchedEvents = query.isEmpty
        ? widget.events
        : widget.events
              .where((event) {
                final name = event.name.toLowerCase();
                final description = event.description.toLowerCase();

                return name.contains(query) || description.contains(query);
              })
              .toList(growable: false);

    final filteredEvents = searchedEvents
        .where((event) {
          bool matchesParticipation = true;

          if (_statusFilter != 'すべて') {
            final participationLabel = _participationLabel(event);

            if (_statusFilter == '参加中') {
              matchesParticipation =
                  participationLabel == '選択中' || participationLabel == '参加中';
            } else {
              matchesParticipation = participationLabel == _statusFilter;
            }
          }

          if (!matchesParticipation) {
            return false;
          }

          if (_periodFilter != 'すべて' &&
              event.eventStatusText() != _periodFilter) {
            return false;
          }

          if (_prefectureFilter != 'すべて') {
            final prefecture = event.prefecture?.trim();

            final prefectureLabel = prefecture == null || prefecture.isEmpty
                ? '未設定'
                : prefecture;

            if (prefectureLabel != _prefectureFilter) {
              return false;
            }
          }

          if (_favoriteOnly && !_favoriteEventIds.contains(event.id)) {
            return false;
          }

          return true;
        })
        .toList(growable: false);

    final sortedEvents = List<Event>.from(filteredEvents);

    switch (_sortOrder) {
      case '現在地から近い順':
        sortedEvents.sort((a, b) {
          final aDistance = _nearestDistanceByEventId[a.id];
          final bDistance = _nearestDistanceByEventId[b.id];

          if (aDistance == null && bDistance == null) {
            return a.name.compareTo(b.name);
          }

          if (aDistance == null) {
            return 1;
          }

          if (bDistance == null) {
            return -1;
          }

          final result = aDistance.compareTo(bDistance);

          if (result != 0) {
            return result;
          }

          return a.name.compareTo(b.name);
        });
        break;

      case '終了が近い順':
        sortedEvents.sort((a, b) {
          final aEnd = a.endAt;
          final bEnd = b.endAt;

          if (aEnd == null && bEnd == null) {
            return a.name.compareTo(b.name);
          }

          if (aEnd == null) {
            return 1;
          }

          if (bEnd == null) {
            return -1;
          }

          final result = aEnd.compareTo(bEnd);

          if (result != 0) {
            return result;
          }

          return a.name.compareTo(b.name);
        });
        break;

      case '開始日が早い順':
        sortedEvents.sort((a, b) {
          final aStart = a.startAt;
          final bStart = b.startAt;

          if (aStart == null && bStart == null) {
            return a.name.compareTo(b.name);
          }

          if (aStart == null) {
            return 1;
          }

          if (bStart == null) {
            return -1;
          }

          final result = aStart.compareTo(bStart);

          if (result != 0) {
            return result;
          }

          return a.name.compareTo(b.name);
        });
        break;

      case '名前順':
        sortedEvents.sort((a, b) => a.name.compareTo(b.name));
        break;

      case '標準':
      default:
        break;
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: QuestUiTokens.primary),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          Icon(Icons.cloud_off_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed: _loadParticipationStates,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ),
        ],
      );
    }

    if (widget.events.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          Icon(
            Icons.explore_off_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            '公開中のクエストはありません',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'クエスト名・説明から検索',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: QuestUiTokens.primary,
            ),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: '検索をクリア',
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.82),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide(
                color: QuestUiTokens.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            final activeFilterCount =
                [
                  _statusFilter,
                  _periodFilter,
                  _prefectureFilter,
                ].where((value) => value != 'すべて').length +
                (_favoriteOnly ? 1 : 0);

            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showFilterSheet(prefectureOptions);
                    },
                    icon: const Icon(Icons.tune_rounded, size: 19),
                    label: Text(
                      activeFilterCount == 0
                          ? '絞り込み'
                          : '絞り込み ・ $activeFilterCount',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        barrierColor: QuestUiTokens.ink.withValues(alpha: 0.48),
                        builder: (sheetContext) {
                          final options =
                              <
                                ({
                                  String value,
                                  String label,
                                  String description,
                                  IconData icon,
                                })
                              >[
                                (
                                  value: '標準',
                                  label: '標準',
                                  description: 'おすすめの順番で表示',
                                  icon: Icons.auto_awesome_rounded,
                                ),
                                (
                                  value: '現在地から近い順',
                                  label: '近い順',
                                  description: '現在地から近いクエストを優先',
                                  icon: Icons.near_me_rounded,
                                ),
                                (
                                  value: '終了が近い順',
                                  label: '終了順',
                                  description: '終了日が近いクエストを優先',
                                  icon: Icons.hourglass_bottom_rounded,
                                ),
                                (
                                  value: '開始日が早い順',
                                  label: '開始順',
                                  description: '開始日が早いクエストを優先',
                                  icon: Icons.event_available_rounded,
                                ),
                                (
                                  value: '名前順',
                                  label: '名前順',
                                  description: 'クエスト名の順番で表示',
                                  icon: Icons.sort_by_alpha_rounded,
                                ),
                              ];

                          return Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF6F8FC),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  11,
                                  20,
                                  20,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 42,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: QuestUiTokens.mutedInk
                                              .withValues(alpha: 0.45),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            gradient:
                                                QuestUiTokens.primaryGradient,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: QuestUiTokens.primary
                                                    .withValues(alpha: 0.24),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.sort_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 13),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'SORT QUESTS',
                                                style: TextStyle(
                                                  color: QuestUiTokens.primary,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.6,
                                                ),
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                '並び替え',
                                                style: TextStyle(
                                                  color: QuestUiTokens.ink,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                'クエストの表示順を選択',
                                                style: TextStyle(
                                                  color: QuestUiTokens.mutedInk,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    for (final option in options) ...[
                                      Builder(
                                        builder: (context) {
                                          final isSelected =
                                              _sortOrder == option.value;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.of(sheetContext)
                                                      .pop(option.value);
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: QuestGlassCard(
                                                  padding: const EdgeInsets.all(
                                                    15,
                                                  ),
                                                  borderRadius: 20,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 42,
                                                        height: 42,
                                                        alignment:
                                                            Alignment.center,
                                                        decoration: BoxDecoration(
                                                          gradient: isSelected
                                                              ? QuestUiTokens
                                                                    .primaryGradient
                                                              : null,
                                                          color: isSelected
                                                              ? null
                                                              : QuestUiTokens
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.08,
                                                                    ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                13,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          option.icon,
                                                          size: 20,
                                                          color: isSelected
                                                              ? Colors.white
                                                              : QuestUiTokens
                                                                    .primary,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 13),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              option.label,
                                                              style: TextStyle(
                                                                color:
                                                                    QuestUiTokens
                                                                        .ink,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    isSelected
                                                                    ? FontWeight
                                                                          .w900
                                                                    : FontWeight
                                                                          .w800,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 3,
                                                            ),
                                                            Text(
                                                              option
                                                                  .description,
                                                              style: const TextStyle(
                                                                color:
                                                                    QuestUiTokens
                                                                        .mutedInk,
                                                                fontSize: 11,
                                                                height: 1.35,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      if (isSelected)
                                                        Container(
                                                          width: 28,
                                                          height: 28,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration:
                                                              const BoxDecoration(
                                                                gradient:
                                                                    QuestUiTokens
                                                                        .primaryGradient,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          child: const Icon(
                                                            Icons.check_rounded,
                                                            size: 17,
                                                            color: Colors.white,
                                                          ),
                                                        )
                                                      else
                                                        const Icon(
                                                          Icons
                                                              .chevron_right_rounded,
                                                          color: QuestUiTokens
                                                              .mutedInk,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );

                      if (!mounted || selected == null) {
                        return;
                      }

                      setState(() {
                        _sortOrder = selected;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: QuestUiTokens.ink,
                      side: BorderSide(
                        color: QuestUiTokens.primary.withValues(alpha: 0.16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sort_rounded,
                          size: 19,
                          color: QuestUiTokens.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            switch (_sortOrder) {
                              '現在地から近い順' => '近い順',
                              '終了が近い順' => '終了順',
                              '開始日が早い順' => '開始順',
                              '名前順' => '名前順',
                              _ => '標準',
                            },
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.expand_more_rounded,
                          size: 19,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _searchQuery.trim().isEmpty
                ? '${filteredEvents.length}件のクエスト'
                : '検索結果 ${filteredEvents.length}件',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: QuestUiTokens.mutedInk,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (filteredEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  '該当するクエストはありません',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '検索条件やフィルターを変えてみてください。',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        for (final event in sortedEvents) _buildEventCard(event),
      ],
    );
  }

  Widget _buildHeader() {
    final title = widget.initialFavoriteOnly ? 'お気に入りを巡ろう' : '新しいクエストを見つけよう';

    final subtitle = widget.initialFavoriteOnly
        ? '${widget.events.length}件のクエストからお気に入りを表示'
        : '${widget.events.length}件のクエストを公開中';

    return QuestGlassCard(
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
                  color: QuestUiTokens.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              widget.initialFavoriteOnly
                  ? Icons.star_rounded
                  : Icons.travel_explore_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DISCOVER QUESTS',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
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

  Widget _buildEventCard(Event event) {
    final label = _participationLabel(event);
    final color = _statusColor(label);
    final icon = _statusIcon(label);
    final description = event.description.trim();
    final nearestDistance = _nearestDistanceByEventId[event.id];
    final nearestPlaceName = _nearestPlaceNameByEventId[event.id];
    final isFavorite = _favoriteEventIds.contains(event.id);

    String? distanceText;

    if (nearestDistance != null) {
      final distance = nearestDistance < 1000
          ? '${nearestDistance.round()}m'
          : '${(nearestDistance / 1000).toStringAsFixed(1)}km';

      distanceText = nearestPlaceName != null && nearestPlaceName.isNotEmpty
          ? '最寄り $distance  $nearestPlaceName'
          : '最寄り $distance';
    }

    final isCurrent = label == '選択中';
    final eventTheme = _eventThemePolicy.resolve(event);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrent
              ? [
                  eventTheme.primary.withValues(alpha: 0.12),
                  eventTheme.accent.withValues(alpha: 0.055),
                ]
              : [
                  Colors.white.withValues(alpha: 0.86),
                  Colors.white.withValues(alpha: 0.62),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCurrent
              ? eventTheme.primary.withValues(alpha: 0.28)
              : QuestUiTokens.primary.withValues(alpha: 0.07),
          width: isCurrent ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: QuestUiTokens.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            _openEventDetail(event);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: isCurrent ? eventTheme.primaryGradient : null,
                    color: isCurrent ? null : color.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.explore_rounded,
                    color: isCurrent ? Colors.white : color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              event.name,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.25,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          QuestStatusChip(
                            label: label,
                            icon: icon,
                            accentColor: color,
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: QuestUiTokens.mutedInk,
                          ),
                        ),
                      ],
                      if (distanceText != null) ...[
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            const Icon(
                              Icons.near_me_outlined,
                              size: 15,
                              color: QuestUiTokens.primary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                distanceText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: QuestUiTokens.mutedInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: isFavorite ? 'お気に入りから外す' : 'お気に入りに追加',
                  onPressed: () {
                    _toggleFavorite(event);
                  },
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFavorite
                        ? Colors.amber.shade700
                        : QuestUiTokens.mutedInk,
                  ),
                ),
                if (label == '参加中')
                  IconButton(
                    tooltip: 'クエストメニュー',
                    onPressed: () async {
                      final action = await showModalBottomSheet<String>(
                        context: context,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        barrierColor: QuestUiTokens.ink.withValues(alpha: 0.48),
                        builder: (sheetContext) {
                          return Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF6F8FC),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  11,
                                  20,
                                  20,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 42,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: QuestUiTokens.mutedInk
                                              .withValues(alpha: 0.45),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            gradient:
                                                QuestUiTokens.primaryGradient,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: QuestUiTokens.primary
                                                    .withValues(alpha: 0.24),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.more_horiz_rounded,
                                            color: Colors.white,
                                            size: 25,
                                          ),
                                        ),
                                        const SizedBox(width: 13),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'QUEST MENU',
                                                style: TextStyle(
                                                  color: QuestUiTokens.primary,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.6,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              const Text(
                                                'クエストメニュー',
                                                style: TextStyle(
                                                  color: QuestUiTokens.ink,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                event.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: QuestUiTokens.mutedInk,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.of(sheetContext)
                                              .pop('leave');
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: QuestGlassCard(
                                          padding: const EdgeInsets.all(15),
                                          borderRadius: 20,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 42,
                                                height: 42,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD94B5B)
                                                      .withValues(alpha: 0.10),
                                                  borderRadius:
                                                      BorderRadius.circular(13),
                                                ),
                                                child: const Icon(
                                                  Icons.logout_rounded,
                                                  size: 20,
                                                  color: Color(0xFFD94B5B),
                                                ),
                                              ),
                                              const SizedBox(width: 13),
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '参加をやめる',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFFD94B5B,
                                                        ),
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    SizedBox(height: 3),
                                                    Text(
                                                      '獲得済みの記録は削除されません',
                                                      style: TextStyle(
                                                        color: QuestUiTokens
                                                            .mutedInk,
                                                        fontSize: 11,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: Color(0xFFD94B5B),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );

                      if (!mounted || action == null) {
                        return;
                      }

                      if (action == 'leave') {
                        await _confirmLeaveEvent(event);
                      }
                    },
                    icon: const Icon(
                      Icons.more_vert_rounded,
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
