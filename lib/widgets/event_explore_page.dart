import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/event.dart';
import '../models/seichi.dart';
import 'event_detail_page.dart';

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
      debugPrint('[EVENT] nearest distance load failed: $error');
      debugPrint('[EVENT] nearest distance stackTrace: $stackTrace');
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
      debugPrint('[EVENT] favorite load failed: $error');
      debugPrint('[EVENT] favorite load stackTrace: $stackTrace');
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
      debugPrint('[EVENT] favorite toggle failed: $error');
      debugPrint('[EVENT] favorite toggle stackTrace: $stackTrace');

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
      debugPrint('[EVENT] explore participation load failed: $error');
      debugPrint('[EVENT] explore participation stackTrace: $stackTrace');

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
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: Text(widget.initialFavoriteOnly ? 'お気に入りクエスト' : 'クエストを探す'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadParticipationStates,
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
      backgroundColor: const Color(0xFFF7F5FB),
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
      return const Center(child: CircularProgressIndicator());
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
            prefixIcon: const Icon(Icons.search),
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
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
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
                    icon: const Icon(Icons.tune, size: 19),
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
                      prefixIcon: const Icon(Icons.sort, size: 19),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
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
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        for (final event in sortedEvents) _buildEventCard(event),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.travel_explore,
              color: Colors.deepPurple,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '新しいクエストを見つけよう',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.events.length}件のクエストを公開中',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: label == '選択中'
            ? Border.all(
                color: Colors.deepPurple.withValues(alpha: 0.30),
                width: 1.5,
              )
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _openEventDetail(event);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.explore_outlined, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 13, color: color),
                              const SizedBox(width: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          height: 1.4,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    if (nearestDistance != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 15,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            nearestDistance < 1000
                                ? nearestPlaceName != null &&
                                          nearestPlaceName.isNotEmpty
                                      ? '最寄り ${nearestDistance.round()}m  $nearestPlaceName'
                                      : '最寄り ${nearestDistance.round()}m'
                                : nearestPlaceName != null &&
                                      nearestPlaceName.isNotEmpty
                                ? '最寄り ${(nearestDistance / 1000).toStringAsFixed(1)}km  $nearestPlaceName'
                                : '最寄り ${(nearestDistance / 1000).toStringAsFixed(1)}km',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: isFavorite ? 'お気に入りから外す' : 'お気に入りに追加',
                onPressed: () {
                  _toggleFavorite(event);
                },
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite
                      ? Colors.amber.shade700
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
