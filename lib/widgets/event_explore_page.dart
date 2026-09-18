import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/event.dart';
import '../models/seichi.dart';
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
  final ValueChanged<Seichi>? onSetNextDestination;
  final ValueChanged<Seichi>? onShowOnMap;
  final ValueChanged<List<Seichi>>? onStartRecommendedRoute;
  final bool initialFavoriteOnly;

  @override
  State<EventExplorePage> createState() => _EventExplorePageState();
}

class _EventExplorePageState extends State<EventExplorePage> {
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

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('お気に入りの更新に失敗しました。')));
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

  String _participationLabel(Event event) {
    if (event.id == widget.currentEventId) {
      return '選択中';
    }

    if (_participationStates[event.id] == true) {
      return '参加中';
    }

    if (_participationStates.containsKey(event.id)) {
      return '過去に参加';
    }

    return '未参加';
  }

  Color _statusColor(String label) {
    switch (label) {
      case '選択中':
        return Colors.deepPurple;

      case '参加中':
        return Colors.green;

      case '過去に参加':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String label) {
    switch (label) {
      case '選択中':
        return Icons.check_circle;

      case '参加中':
        return Icons.flag_outlined;

      case '過去に参加':
        return Icons.history_outlined;

      default:
        return Icons.add_circle_outline;
    }
  }

  String? _primaryActionLabel(String label) {
    switch (label) {
      case '参加中':
        return 'このクエストを選ぶ';

      case '過去に参加':
        return '再参加して選ぶ';

      case '未参加':
        return '参加して選ぶ';

      default:
        return null;
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

    if (result is Seichi) {
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
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F8FC),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildSection({
              required String title,
              required List<String> options,
              required String selected,
              required ValueChanged<String> onSelected,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in options)
                        ChoiceChip(
                          label: Text(option),
                          selected: selected == option,
                          onSelected: (_) {
                            onSelected(option);
                          },
                        ),
                    ],
                  ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '絞り込み',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '条件を組み合わせてクエストを探せます。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    buildSection(
                      title: '参加状態',
                      options: const ['すべて', '未参加', '参加中', '過去に参加'],
                      selected: temporaryStatus,
                      onSelected: (value) {
                        setSheetState(() {
                          temporaryStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    buildSection(
                      title: '開催状態',
                      options: const ['すべて', '開催中', '開催前', '終了'],
                      selected: temporaryPeriod,
                      onSelected: (value) {
                        setSheetState(() {
                          temporaryPeriod = value;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    buildSection(
                      title: '都道府県',
                      options: <String>['すべて', ...prefectureOptions],
                      selected: temporaryPrefecture,
                      onSelected: (value) {
                        setSheetState(() {
                          temporaryPrefecture = value;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'お気に入りのみ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text('★を付けたクエストだけ表示'),
                      value: temporaryFavoriteOnly,
                      onChanged: (value) {
                        setSheetState(() {
                          temporaryFavoriteOnly = value;
                        });
                      },
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                temporaryStatus = 'すべて';
                                temporaryPeriod = 'すべて';
                                temporaryPrefecture = 'すべて';
                                temporaryFavoriteOnly = false;
                              });
                            },
                            child: const Text('リセット'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(true);
                            },
                            child: const Text('この条件で表示'),
                          ),
                        ),
                      ],
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
                          : '絞り込み $activeFilterCount',
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
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_sortOrder),
                    initialValue: _sortOrder,
                    isDense: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.sort_rounded,
                        size: 19,
                        color: QuestUiTokens.primary,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.82),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: QuestUiTokens.primary.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: '標準', child: Text('標準')),
                      DropdownMenuItem(value: '現在地から近い順', child: Text('近い順')),
                      DropdownMenuItem(value: '終了が近い順', child: Text('終了順')),
                      DropdownMenuItem(value: '開始日が早い順', child: Text('開始順')),
                      DropdownMenuItem(value: '名前順', child: Text('名前順')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _sortOrder = value;
                      });
                    },
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

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrent
              ? [
                  QuestUiTokens.primary.withValues(alpha: 0.12),
                  QuestUiTokens.cyan.withValues(alpha: 0.055),
                ]
              : [
                  Colors.white.withValues(alpha: 0.86),
                  Colors.white.withValues(alpha: 0.62),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCurrent
              ? QuestUiTokens.primary.withValues(alpha: 0.28)
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
                    gradient: isCurrent ? QuestUiTokens.primaryGradient : null,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
