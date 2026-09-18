import 'dart:ui';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'collection_history_service.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/collection_page.dart';
import 'widgets/quest_page.dart';
import 'widgets/ranking_page.dart';
import 'widgets/map_page.dart';
import 'widgets/my_page.dart';
import 'widgets/profile_page.dart';
import 'widgets/account_page.dart';
import 'widgets/adventure_log_page.dart';
import 'widgets/event_detail_page.dart';
import 'widgets/event_explore_page.dart';
import 'widgets/sync_status_page.dart';
import 'widgets/participating_events_page.dart';
import 'widgets/notification_settings_page.dart';
import 'widgets/app_settings_page.dart';
import 'widgets/quest_ui.dart';
import 'models/seichi.dart';
import 'models/achievement.dart';
import 'models/event.dart';
import 'services/achievement_service.dart';
import 'services/level_service.dart';
import 'services/next_destination_service.dart';
import 'services/notification_service.dart';
import 'models/real_world_state.dart';
import 'services/external_navigation_service.dart';
import 'services/weather_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'services/app_logger.dart';

// ============================================================
// Supabase
// ============================================================

const supabaseUrl = 'https://wxlvhpmolrtcwryaazfb.supabase.co';

const supabasePublishableKey = 'sb_publishable_F5e3RPpeUzlQG31-yv4FeA_fExmYk3w';

// ============================================================
// アプリ起動
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();

  await NotificationService.instance.initialize();

  await supabase.Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const SeichiQuestApp());
}

// ============================================================
// 聖地データ
// ============================================================

// ============================================================
// アプリ本体
// ============================================================

class SeichiQuestApp extends StatelessWidget {
  const SeichiQuestApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '聖地クエスト',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A35C8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F5FB),
      ),
      home: home ?? const SeichiMapPage(),
    );
  }
}

// ============================================================
// メイン画面
// ============================================================

class SeichiMapPage extends StatefulWidget {
  const SeichiMapPage({super.key});

  @override
  State<SeichiMapPage> createState() => _SeichiMapPageState();
}

class _SeichiMapPageState extends State<SeichiMapPage>
    with SingleTickerProviderStateMixin {
  static const AchievementService _achievementService = AchievementService();

  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSubscription;

  Position? _currentPosition;

  // スタンプ判定に使用した直前のGPS位置。
  // GPSの急跳びによる誤獲得を防ぐために使用する。
  Position? _lastStampCheckPosition;

  final WeatherService _weatherService = WeatherService();
  RealWorldState? _realWorldState;
  DateTime? _lastWeatherFetchAt;
  Position? _lastWeatherFetchPosition;
  bool _isWeatherFetchInProgress = false;

  List<Seichi> _seichiList = [];
  final Set<String> _collectedIds = {};
  final Map<String, Set<String>> _collectionEventNamesByCard = {};

  SharedPreferences? _preferences;

  final CollectionHistoryService _historyService = CollectionHistoryService();

  static const LevelService _levelService = LevelService();
  LevelProgress? _levelProgress;

  // 現在表示・獲得対象としているイベント。
  String? _currentEventId;
  String? _currentEventName;
  String? _displayName;
  String? _avatarKey;
  int? _myEventRank;
  List<Event> _events = [];
  List<Achievement> _eventAchievements = [];

  bool _isLoading = true;
  bool _isLoadingLocation = false;

  String? _errorMessage;

  Seichi? _nextSeichi;
  double? _nextDistance;

  bool _focusNextDestinationOnMapOpen = false;
  Seichi? _pendingMapSeichi;

  // ユーザーが「次の目的地にする」で指定した聖地。
  // 未指定時は従来どおり、現在地から最も近い未獲得聖地を自動選択する。
  String? _manualNextSeichiId;

  // おすすめ巡回ルート開始中の未完了ルート。
  // 先頭要素が現在のNEXT目的地になる。
  final List<Seichi> _activeRecommendedRoute = <Seichi>[];

  // 現在のユーザー・イベントについて、
  // おすすめルートの永続化状態を読み込み済みかどうか。
  bool _isRecommendedRouteLoaded = false;

  bool _justCollected = false;
  String? _collectedName;

  bool _isCollecting = false;

  late AnimationController _sonarController;

  int _selectedTab = 0;

  // スタンプ帳表示状態
  //
  // 0 = すべて
  // 1 = 獲得済み
  // 2 = 未獲得
  int _collectionFilter = 0;

  // ------------------------------------------------------------
  // 初期位置
  // ------------------------------------------------------------

  static const LatLng _defaultCenter = LatLng(36.3910, 139.0600);

  // 上毛かるたの札順。
  // Supabase側の登録順に依存せず、スタンプ帳を必ず札順で表示する。
  static const List<String> _jomoKarutaOrder = [
    'あ',
    'い',
    'う',
    'え',
    'お',
    'か',
    'き',
    'く',
    'け',
    'こ',
    'さ',
    'し',
    'す',
    'せ',
    'そ',
    'た',
    'ち',
    'つ',
    'て',
    'と',
    'な',
    'に',
    'ぬ',
    'ね',
    'の',
    'は',
    'ひ',
    'ふ',
    'へ',
    'ほ',
    'ま',
    'み',
    'む',
    'め',
    'も',
    'や',
    'ゆ',
    'よ',
    'ら',
    'り',
    'る',
    'れ',
    'ろ',
    'わ',
    'を',
  ];

  int _cardOrderIndex(String card) {
    final index = _jomoKarutaOrder.indexOf(card.trim());
    return index == -1 ? 999 : index;
  }

  // ============================================================
  // 初期化
  // ============================================================

  @override
  void initState() {
    super.initState();

    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _initialize();
  }

  Future<void> _loadCurrentEvent() async {
    try {
      final client = supabase.Supabase.instance.client;
      final user = client.auth.currentUser;

      final data = await client
          .from('events')
          .select(
            'id, slug, name, description, prefecture, is_active, '
            'icon_url, cover_image_url, start_at, end_at, updated_at',
          )
          .eq('is_active', true)
          .order('created_at');

      final events = List<Map<String, dynamic>>.from(data)
          .map(Event.fromMap)
          .toList(growable: false);

      _events = events;

      if (events.isEmpty) {
        throw Exception('有効なクエストがありません。');
      }

      String? savedEventId;

      if (user != null) {
        try {
          final preference = await client
              .from('user_event_preferences')
              .select('current_event_id')
              .eq('user_id', user.id)
              .maybeSingle();

          savedEventId = preference?['current_event_id']?.toString();
        } catch (error) {
          appDebugPrint('[EVENT] preference load failed: $error');
        }
      }

      Event? currentEvent;

      if (savedEventId != null && savedEventId.isNotEmpty) {
        for (final event in events) {
          if (event.id == savedEventId) {
            currentEvent = event;
            break;
          }
        }
      }

      if (currentEvent == null) {
        for (final event in events) {
          if (event.slug == 'jomo-karuta-gunma') {
            currentEvent = event;
            break;
          }
        }
      }

      currentEvent ??= events.first;

      _currentEventId = currentEvent.id;
      _currentEventName = currentEvent.name;

      if (_currentEventId == null || _currentEventId!.isEmpty) {
        throw Exception('現在のイベントIDが取得できません。');
      }

      if (user != null && savedEventId != _currentEventId) {
        await _saveCurrentEventPreference(_currentEventId!);
      }

      await _ensureEventParticipation(_currentEventId!);

      appDebugPrint(
        '[EVENT] current event restored: id=$_currentEventId, name=$_currentEventName',
      );
    } catch (e) {
      appDebugPrint('現在のイベント取得エラー: $e');
      rethrow;
    }
  }

  Future<void> _saveCurrentEventPreference(String eventId) async {
    final client = supabase.Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null || eventId.isEmpty) {
      return;
    }

    try {
      await client.from('user_event_preferences').upsert({
        'user_id': user.id,
        'current_event_id': eventId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');

      appDebugPrint('[EVENT] preference saved: eventId=$eventId');
    } catch (error) {
      appDebugPrint('[EVENT] preference save failed: $error');
      rethrow;
    }
  }

  Future<void> _ensureEventParticipation(String eventId) async {
    final client = supabase.Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null || eventId.isEmpty) {
      return;
    }

    try {
      final existing = await client
          .from('user_event_participations')
          .select('is_active')
          .eq('user_id', user.id)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existing == null) {
        final now = DateTime.now().toUtc().toIso8601String();

        await client.from('user_event_participations').insert({
          'user_id': user.id,
          'event_id': eventId,
          'joined_at': now,
          'is_active': true,
          'left_at': null,
          'updated_at': now,
        });

        appDebugPrint('[EVENT] participation created: eventId=$eventId');
        return;
      }

      if (existing['is_active'] == true) {
        return;
      }

      await client
          .from('user_event_participations')
          .update({
            'is_active': true,
            'left_at': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('event_id', eventId);

      appDebugPrint('[EVENT] participation reactivated: eventId=$eventId');
    } catch (error) {
      appDebugPrint('[EVENT] participation ensure failed: $error');
      rethrow;
    }
  }

  Future<void> _loadEventAchievements() async {
    if (_currentEventId == null || _currentEventId!.isEmpty) {
      throw Exception('イベントIDが未取得のため、チャレンジを読み込めません。');
    }

    final data = await supabase.Supabase.instance.client
        .from('event_achievements')
        .select(
          'sort_order, achievements('
          'id, title, description, icon, required_count'
          ')',
        )
        .eq('event_id', _currentEventId!)
        .order('sort_order');

    final rows = List<Map<String, dynamic>>.from(data);

    final achievements = <Achievement>[];

    for (final row in rows) {
      final raw = row['achievements'];

      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final id = raw['id']?.toString() ?? '';

      if (id.isEmpty) {
        continue;
      }

      final requiredCount = raw['required_count'] is int
          ? raw['required_count'] as int
          : int.tryParse(raw['required_count']?.toString() ?? '') ?? 0;

      achievements.add(
        Achievement(
          id: id,
          title: raw['title']?.toString() ?? '',
          description: raw['description']?.toString() ?? '',
          icon: raw['icon']?.toString() ?? '',
          requiredCount: requiredCount,
        ),
      );
    }

    _eventAchievements = achievements;
  }

  Future<void> _initialize() async {
    await _ensureCloudUser();
    await _loadDisplayName();
    await _loadCurrentEvent();
    await _loadEventAchievements();
    await _loadSavedStamps();

    final syncedRows = await _historyService.syncPendingPlaceVisits();

    await _loadSeichi();
    await _applyCollectedRows(syncedRows);
    await _loadCloudHistory();
    await _loadManualNextDestination();
    await _loadRecommendedRoute();

    if (_activeRecommendedRoute.isNotEmpty) {
      _manualNextSeichiId = _activeRecommendedRoute.first.id;
    }
    await _loadMyEventRank();
    await _loadLevelProgress();
    await _initializeLocation();
  }

  Future<void> _loadLevelProgress() async {
    try {
      final totalCollected = await _historyService.loadTotalCollectionCount();

      final totalXp = _levelService.xpFromCollectedCount(totalCollected);

      final levelProgress = _levelService.progressFromXp(totalXp);

      if (!mounted) {
        return;
      }

      setState(() {
        _levelProgress = levelProgress;
      });

      appDebugPrint(
        '[LEVEL] collected=$totalCollected '
        'xp=${levelProgress.totalXp} '
        'level=${levelProgress.level}',
      );
    } catch (error) {
      appDebugPrint('[LEVEL] load failed: $error');
    }
  }

  Future<void> _loadDisplayName() async {
    final client = supabase.Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _displayName = null;
        });
      }
      return;
    }

    try {
      final data = await client
          .from('profiles')
          .select('display_name, avatar_key')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      final displayName = data?['display_name']?.toString().trim();

      final avatarKey = data?['avatar_key']?.toString().trim();

      setState(() {
        _displayName = displayName == null || displayName.isEmpty
            ? null
            : displayName;

        _avatarKey = avatarKey == null || avatarKey.isEmpty ? null : avatarKey;
      });
    } catch (error) {
      appDebugPrint('[PROFILE] display name load failed: $error');
    }
  }

  Future<void> _ensureCloudUser() async {
    final client = supabase.Supabase.instance.client;

    final existingUser = client.auth.currentUser;

    if (existingUser != null) {
      appDebugPrint(
        '[AUTH] existing user: ${existingUser.id}, '
        'anonymous=${existingUser.isAnonymous}',
      );
      return;
    }

    appDebugPrint('[AUTH] no current user. Starting anonymous sign-in...');

    try {
      final response = await client.auth.signInAnonymously();
      final user = response.user;

      if (user != null) {
        appDebugPrint(
          '[AUTH] anonymous sign-in success: ${user.id}, '
          'anonymous=${user.isAnonymous}',
        );
      } else {
        appDebugPrint('[AUTH] anonymous sign-in returned null user');
      }
    } on supabase.AuthException catch (error) {
      appDebugPrint(
        '[AUTH] anonymous sign-in failed: '
        'code=${error.statusCode}, message=${error.message}',
      );
    } catch (error) {
      appDebugPrint('[AUTH] anonymous sign-in failed: $error');
    }
  }

  Future<void> _loadMyEventRank() async {
    final eventId = _currentEventId;

    if (eventId == null || eventId.isEmpty) {
      if (mounted) {
        setState(() {
          _myEventRank = null;
        });
      }
      return;
    }

    try {
      final data = await supabase.Supabase.instance.client.rpc(
        'get_my_event_rank',
        params: {'p_event_id': eventId},
      );

      final rows = List<Map<String, dynamic>>.from(data as List);

      final rank = rows.isEmpty ? null : (rows.first['rank'] as num?)?.toInt();

      if (!mounted) {
        return;
      }

      setState(() {
        _myEventRank = rank;
      });
    } catch (error) {
      appDebugPrint('[RANKING] my event rank load failed: $error');
    }
  }

  Future<void> _resetCurrentEventCollectionHistory() async {
    final eventId = _currentEventId;

    if (eventId == null || eventId.isEmpty) {
      throw Exception('現在のイベントIDが取得できません。');
    }

    await _historyService.resetEventCollectionHistory(eventId: eventId);

    _collectedIds.clear();
    _manualNextSeichiId = null;
    _activeRecommendedRoute.clear();

    await _saveManualNextDestination();
    await _saveRecommendedRoute();
    await _saveStamps();
    await _loadCollectionEventNames();

    _updateNextDestination();
    await _checkStampDistance();
    await _loadMyEventRank();

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _loadCloudHistory() async {
    try {
      final history = await _historyService.loadHistory(
        eventId: _currentEventId!,
      );
      for (final item in history) {
        final id = item['seichi_id']?.toString();
        if (id != null && id.isNotEmpty) {
          _collectedIds.add(id);
        }
      }

      await _saveStamps();
    } catch (_) {
      // DB取得失敗時は端末キャッシュをそのまま使用する。
    }

    await _loadCollectionEventNames();
  }

  Future<void> _loadCollectionEventNames() async {
    try {
      final history = await _historyService.loadCollectionDisplayHistory();

      final next = <String, Set<String>>{};

      for (final item in history) {
        final card = item['card']?.toString();
        final eventName = item['event_name']?.toString();

        if (card == null ||
            card.isEmpty ||
            eventName == null ||
            eventName.isEmpty) {
          continue;
        }

        next.putIfAbsent(card, () => <String>{}).add(eventName);
      }

      _collectionEventNamesByCard
        ..clear()
        ..addAll(next);
    } catch (_) {
      // 表示用履歴の取得失敗時は、既に保持している情報を維持する。
    }
  }

  // ============================================================
  // 保存済みスタンプ
  // ============================================================

  String _stampStorageKey({required String userId, required String eventId}) {
    return 'collected_seichi_ids_v2_${userId}_$eventId';
  }

  Future<void> _migrateLegacyStampCache({
    required SharedPreferences preferences,
    required String userId,
    required String currentEventId,
  }) async {
    const legacyGlobalKey = 'collected_seichi_ids';
    const legacyEventPrefix = 'collected_seichi_ids_';
    const scopedPrefix = 'collected_seichi_ids_v2_';

    final keys = preferences.getKeys().toList();

    for (final key in keys) {
      if (!key.startsWith(legacyEventPrefix) || key.startsWith(scopedPrefix)) {
        continue;
      }

      final eventId = key.substring(legacyEventPrefix.length);

      if (eventId.isEmpty) {
        continue;
      }

      final legacyIds = preferences.getStringList(key);
      final scopedKey = _stampStorageKey(userId: userId, eventId: eventId);
      final scopedIds = preferences.getStringList(scopedKey) ?? <String>[];

      final mergedIds = <String>{...scopedIds, ...?legacyIds}.toList();

      await preferences.setStringList(scopedKey, mergedIds);
      await preferences.remove(key);
    }

    final legacyGlobalIds = preferences.getStringList(legacyGlobalKey);

    if (legacyGlobalIds != null) {
      final scopedKey = _stampStorageKey(
        userId: userId,
        eventId: currentEventId,
      );
      final scopedIds = preferences.getStringList(scopedKey) ?? <String>[];

      final mergedIds = <String>{...scopedIds, ...legacyGlobalIds}.toList();

      await preferences.setStringList(scopedKey, mergedIds);
      await preferences.remove(legacyGlobalKey);
    }
  }

  Future<void> _loadSavedStamps() async {
    _preferences = await SharedPreferences.getInstance();

    if (_currentEventId == null || _currentEventId!.isEmpty) {
      throw Exception('イベントIDが未取得のため、獲得スタンプを読み込めません。');
    }

    final user = supabase.Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('ユーザーIDが未取得のため、獲得スタンプを読み込めません。');
    }

    final preferences = _preferences!;
    final eventId = _currentEventId!;

    await _migrateLegacyStampCache(
      preferences: preferences,
      userId: user.id,
      currentEventId: eventId,
    );

    final eventKey = _stampStorageKey(userId: user.id, eventId: eventId);

    final savedIds = preferences.getStringList(eventKey);

    _collectedIds
      ..clear()
      ..addAll(savedIds ?? <String>[]);
  }

  String _manualNextDestinationStorageKey({
    required String userId,
    required String eventId,
  }) {
    return 'manual_next_seichi_id_v1_${userId}_$eventId';
  }

  Future<void> _saveManualNextDestination() async {
    final eventId = _currentEventId;
    final user = supabase.Supabase.instance.client.auth.currentUser;

    if (eventId == null || eventId.isEmpty || user == null) {
      return;
    }

    _preferences ??= await SharedPreferences.getInstance();

    final key = _manualNextDestinationStorageKey(
      userId: user.id,
      eventId: eventId,
    );

    final seichiId = _manualNextSeichiId;

    if (seichiId == null || seichiId.isEmpty) {
      await _preferences!.remove(key);
      appDebugPrint('[NEXT-PERSIST] cleared: event=$eventId');
      return;
    }

    await _preferences!.setString(key, seichiId);

    appDebugPrint('[NEXT-PERSIST] saved: event=$eventId seichi=$seichiId');
  }

  Future<void> _loadManualNextDestination() async {
    final eventId = _currentEventId;
    final user = supabase.Supabase.instance.client.auth.currentUser;

    if (eventId == null || eventId.isEmpty || user == null) {
      _manualNextSeichiId = null;
      return;
    }

    _preferences ??= await SharedPreferences.getInstance();

    final key = _manualNextDestinationStorageKey(
      userId: user.id,
      eventId: eventId,
    );

    final savedId = _preferences!.getString(key);

    if (savedId == null || savedId.isEmpty) {
      _manualNextSeichiId = null;
      return;
    }

    final isValid = _seichiList.any(
      (seichi) => seichi.id == savedId && !_collectedIds.contains(seichi.id),
    );

    if (!isValid) {
      _manualNextSeichiId = null;
      await _preferences!.remove(key);

      appDebugPrint(
        '[NEXT-PERSIST] invalid saved destination removed: '
        'event=$eventId seichi=$savedId',
      );
      return;
    }

    _manualNextSeichiId = savedId;

    appDebugPrint('[NEXT-PERSIST] restored: event=$eventId seichi=$savedId');
  }

  String _recommendedRouteStorageKey({
    required String userId,
    required String eventId,
  }) {
    return 'recommended_route_ids_v1_${userId}_$eventId';
  }

  Future<void> _saveRecommendedRoute() async {
    final eventId = _currentEventId;
    final user = supabase.Supabase.instance.client.auth.currentUser;

    if (eventId == null || eventId.isEmpty || user == null) {
      return;
    }

    _preferences ??= await SharedPreferences.getInstance();

    final key = _recommendedRouteStorageKey(userId: user.id, eventId: eventId);

    final routeIds = _activeRecommendedRoute
        .where((seichi) => !_collectedIds.contains(seichi.id))
        .map((seichi) => seichi.id)
        .toList(growable: false);

    if (routeIds.isEmpty) {
      await _preferences!.remove(key);

      appDebugPrint('[ROUTE-PERSIST] cleared: event=$eventId');
      return;
    }

    await _preferences!.setStringList(key, routeIds);

    appDebugPrint('[ROUTE-PERSIST] saved: event=$eventId ids=$routeIds');
  }

  void _saveRecommendedRouteInBackground() {
    _saveRecommendedRoute().catchError((Object error) {
      appDebugPrint('[ROUTE-PERSIST] save failed: $error');
    });
  }

  Future<void> _loadRecommendedRoute() async {
    final eventId = _currentEventId;
    final user = supabase.Supabase.instance.client.auth.currentUser;

    _isRecommendedRouteLoaded = false;
    _activeRecommendedRoute.clear();

    if (eventId == null || eventId.isEmpty || user == null) {
      return;
    }

    _preferences ??= await SharedPreferences.getInstance();

    final key = _recommendedRouteStorageKey(userId: user.id, eventId: eventId);

    final savedIds = _preferences!.getStringList(key);

    if (savedIds == null || savedIds.isEmpty) {
      _isRecommendedRouteLoaded = true;
      return;
    }

    final seichiById = <String, Seichi>{
      for (final seichi in _seichiList) seichi.id: seichi,
    };

    final restoredRoute = <Seichi>[];

    for (final id in savedIds) {
      final seichi = seichiById[id];

      if (seichi == null || _collectedIds.contains(id)) {
        continue;
      }

      restoredRoute.add(seichi);
    }

    if (restoredRoute.isEmpty) {
      await _preferences!.remove(key);

      appDebugPrint(
        '[ROUTE-PERSIST] invalid or completed route removed: '
        'event=$eventId',
      );
      _isRecommendedRouteLoaded = true;
      return;
    }

    _activeRecommendedRoute.addAll(restoredRoute);

    if (restoredRoute.length != savedIds.length) {
      await _preferences!.setStringList(
        key,
        restoredRoute.map((item) => item.id).toList(growable: false),
      );
    }

    _isRecommendedRouteLoaded = true;

    appDebugPrint(
      '[ROUTE-PERSIST] loaded: '
      'event=$eventId '
      'ids=${_activeRecommendedRoute.map((item) => item.id).toList()}',
    );
  }

  Future<void> _saveStamps() async {
    if (_currentEventId == null || _currentEventId!.isEmpty) {
      throw Exception('イベントIDが未取得のため、獲得スタンプを保存できません。');
    }

    final user = supabase.Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('ユーザーIDが未取得のため、獲得スタンプを保存できません。');
    }

    _preferences ??= await SharedPreferences.getInstance();

    final eventKey = _stampStorageKey(
      userId: user.id,
      eventId: _currentEventId!,
    );

    await _preferences!.setStringList(eventKey, _collectedIds.toList());
  }

  // ============================================================
  // アプリ設定
  // ============================================================

  bool _isAutoNextDestinationEnabled() {
    return _preferences?.getBool('setting_auto_next_destination') ?? true;
  }

  // ============================================================
  // 有効な獲得数
  // ============================================================

  int _getCollectedCount() {
    if (_seichiList.isEmpty) {
      return 0;
    }

    final validIds = _seichiList.map((seichi) => seichi.id).toSet();

    return _collectedIds.where(validIds.contains).length;
  }

  // ============================================================
  // Supabaseから聖地取得
  // ============================================================

  Future<void> _loadSeichi() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final data = await supabase.Supabase.instance.client
          .from('seichi')
          .select(
            'id, card, reading, name, latitude, longitude, '
            'stamp_radius_meters, description, icon, card_image_url, is_active, place_id',
          )
          .eq('is_active', true)
          .eq('event_id', _currentEventId!);

      final list = List<Map<String, dynamic>>.from(data)
          .map(Seichi.fromMap)
          .where(
            (seichi) =>
                seichi.id.isNotEmpty &&
                seichi.latitude != 0 &&
                seichi.longitude != 0,
          )
          .toList();

      list.sort((a, b) {
        final orderCompare = _cardOrderIndex(a.card)
            .compareTo(_cardOrderIndex(b.card));

        if (orderCompare != 0) {
          return orderCompare;
        }

        return a.card.compareTo(b.card);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _seichiList = list;
        _isLoading = false;
      });

      // 自動次目的地設定がONの場合のみ更新する。
      if (_isAutoNextDestinationEnabled()) {
        _updateNextDestination();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '聖地データを取得できませんでした。\n$e';
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // 現在地初期化
  // ============================================================

  Future<void> _initializeLocation() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoadingLocation = false;
          _errorMessage =
              '位置情報サービスがOFFになっています。\n'
              '端末の位置情報をONにしてください。';
        });

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoadingLocation = false;
          _errorMessage = '位置情報の利用が許可されていません。';
        });

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoadingLocation = false;
          _errorMessage =
              '位置情報の利用が永久に拒否されています。\n'
              '端末の設定から位置情報を許可してください。';
        });

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      _updateNextDestination();
      await _updateWeatherIfNeeded(position, force: true);

      await _moveCameraToCurrentLocation();

      _startLocationStream();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLocation = false;
        _errorMessage = '現在地を取得できませんでした。\n$e';
      });
    }
  }

  // ============================================================
  // 現在地監視
  // ============================================================

  Future<void> _updateWeatherIfNeeded(
    Position position, {
    bool force = false,
  }) async {
    const refreshInterval = Duration(minutes: 15);
    const refreshDistanceMeters = 5000.0;

    if (_isWeatherFetchInProgress) {
      return;
    }

    final now = DateTime.now();
    final lastFetchAt = _lastWeatherFetchAt;
    final lastPosition = _lastWeatherFetchPosition;

    var shouldFetch = force || lastFetchAt == null || lastPosition == null;

    if (!shouldFetch && now.difference(lastFetchAt) >= refreshInterval) {
      shouldFetch = true;
    }

    if (!shouldFetch && lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance >= refreshDistanceMeters) {
        shouldFetch = true;
      }
    }

    if (!shouldFetch) {
      return;
    }

    _isWeatherFetchInProgress = true;

    try {
      final state = await _weatherService.fetchCurrentWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _realWorldState = state;
        _lastWeatherFetchAt = DateTime.now();
        _lastWeatherFetchPosition = position;
      });

      final currentState = _realWorldState;

      appDebugPrint(
        '[WEATHER] '
        'weather=${currentState?.weather.name}, '
        'temperature=${currentState?.temperatureCelsius}, '
        'season=${currentState?.season.name}, '
        'dayPhase=${currentState?.dayPhase.name}, '
        'observedAt=${currentState?.observedAt}',
      );
    } catch (error) {
      appDebugPrint('[WEATHER] fetch failed: $error');
    } finally {
      _isWeatherFetchInProgress = false;
    }
  }

  void _startLocationStream() {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            if (!mounted) {
              return;
            }

            setState(() {
              _currentPosition = position;
            });

            _updateNextDestination();
            _updateWeatherIfNeeded(position);
            _checkStampDistance();
          },
          onError: (error) {
            if (!mounted) {
              return;
            }

            setState(() {
              _errorMessage = '位置情報の監視でエラーが発生しました。\n$error';
            });
          },
        );
  }

  // ============================================================
  // 最寄りの未獲得聖地
  // ============================================================

  void _updateNextDestination() {
    appDebugPrint(
      '[ROUTE-NEXT] UPDATE START '
      'manual=$_manualNextSeichiId '
      'active=${_activeRecommendedRoute.map((item) => '${item.card}:${item.id}').toList()} '
      'collected=${_collectedIds.length}',
    );

    final result = const NextDestinationService().findNextDestination(
      position: _currentPosition,
      seichiList: _seichiList,
      collectedIds: _collectedIds,
      manualNextSeichiId: _manualNextSeichiId,
    );

    appDebugPrint(
      '[ROUTE-NEXT] SERVICE RESULT '
      'next=${result.seichi == null ? null : '${result.seichi!.card}:${result.seichi!.name}:${result.seichi!.id}'} '
      'distance=${result.distance}',
    );

    if (result.seichi == null && _manualNextSeichiId != null) {
      _manualNextSeichiId = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _nextSeichi = result.seichi;
      _nextDistance = result.distance;
    });

    appDebugPrint(
      '[ROUTE-NEXT] UPDATE END '
      'next=${_nextSeichi == null ? null : '${_nextSeichi!.card}:${_nextSeichi!.name}:${_nextSeichi!.id}'} '
      'manual=$_manualNextSeichiId '
      'distance=$_nextDistance',
    );
  }

  Future<void> _setNextDestination(Seichi seichi) async {
    if (_collectedIds.contains(seichi.id)) {
      return;
    }

    setState(() {
      _manualNextSeichiId = seichi.id;
      _nextSeichi = seichi;
    });

    await _saveManualNextDestination();

    if (!mounted) {
      return;
    }

    _updateNextDestination();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${seichi.card} ${seichi.name} を次の目的地に設定しました。'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _testRecommendedRouteNext() async {
    if (_activeRecommendedRoute.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('テストできる巡回ルートが開始されていません。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final previousSeichi = _activeRecommendedRoute.first;

    _activeRecommendedRoute.removeAt(0);

    await _saveRecommendedRoute();

    if (_activeRecommendedRoute.isEmpty) {
      _manualNextSeichiId = null;
      _updateNextDestination();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'テスト: ${previousSeichi.card} ${previousSeichi.name} の次で巡回ルート終了です。',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nextSeichi = _activeRecommendedRoute.first;
    _manualNextSeichiId = nextSeichi.id;
    _updateNextDestination();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'テスト: ${previousSeichi.card} ${previousSeichi.name} → '
          '${nextSeichi.card} ${nextSeichi.name}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startRecommendedRoute(List<Seichi> route) {
    if (route.isEmpty) {
      return;
    }

    final remainingRoute = route
        .where((seichi) => !_collectedIds.contains(seichi.id))
        .toList(growable: false);

    if (remainingRoute.isEmpty) {
      return;
    }

    final firstSeichi = remainingRoute.first;

    _activeRecommendedRoute
      ..clear()
      ..addAll(remainingRoute);

    _manualNextSeichiId = firstSeichi.id;
    _updateNextDestination();

    _saveRecommendedRouteInBackground();

    _moveCameraToSeichi(firstSeichi);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '巡回ルートを開始しました。最初の目的地は '
          '${firstSeichi.card} ${firstSeichi.name} です。',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // スタンプ判定
  // ============================================================

  Future<void> _checkStampDistance() async {
    if (_isCollecting) {
      return;
    }

    final position = _currentPosition;

    if (position == null || _seichiList.isEmpty) {
      return;
    }
    // GPS位置が短時間で現実的でない距離まで跳んだ場合は、
    // スタンプ判定を行わない。
    //
    // 100m/s = 360km/h。
    // 誤ったGPS位置によるスタンプ獲得を防ぐための
    // アプリ側の実装上の閾値。
    const maxPlausibleSpeedMps = 100.0;

    final previousPosition = _lastStampCheckPosition;

    if (previousPosition != null) {
      final elapsedSeconds =
          position.timestamp
              .difference(previousPosition.timestamp)
              .inMilliseconds /
          1000.0;

      if (elapsedSeconds > 0) {
        final movedDistance = Geolocator.distanceBetween(
          previousPosition.latitude,
          previousPosition.longitude,
          position.latitude,
          position.longitude,
        );

        final calculatedSpeed = movedDistance / elapsedSeconds;

        if (calculatedSpeed > maxPlausibleSpeedMps) {
          return;
        }
      }
    }

    _lastStampCheckPosition = position;
    appDebugPrint(
      '[STAMP_GPS] '
      'lat=${position.latitude}, '
      'lon=${position.longitude}, '
      'accuracy=${position.accuracy}m, '
      'timestamp=${position.timestamp}, '
      'seichiCount=${_seichiList.length}',
    );

    // GPS精度が極端に悪い場合は誤獲得を防ぐため判定しない。
    // 聖地ごとの到達半径が広い場合は、それに応じて許容する。
    bool hasSufficientAccuracy(Seichi seichi) {
      final radius = seichi.stampRadiusMeters.toDouble();

      final requiredAccuracy = [
        radius * 0.5,
        30.0,
      ].reduce((a, b) => a > b ? a : b);

      return position.accuracy <= requiredAccuracy;
    }

    Seichi? nearestSeichi;
    double nearestDistance = double.infinity;

    for (final seichi in _seichiList) {
      if (_collectedIds.contains(seichi.id)) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        seichi.latitude,
        seichi.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestSeichi = seichi;
      }
    }

    if (nearestSeichi != null) {
      appDebugPrint(
        '[STAMP_DISTANCE] '
        'name=${nearestSeichi.name}, '
        'card=${nearestSeichi.card}, '
        'distance=${nearestDistance.toStringAsFixed(1)}m, '
        'radius=${nearestSeichi.stampRadiusMeters}m, '
        'accuracy=${position.accuracy}m',
      );
    }

    for (final seichi in _seichiList) {
      if (_collectedIds.contains(seichi.id)) {
        continue;
      }

      if (!hasSufficientAccuracy(seichi)) {
        continue;
      }
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        seichi.latitude,
        seichi.longitude,
      );

      if (distance <= seichi.stampRadiusMeters) {
        await _collectStamp(seichi);
        break;
      }
    }
  }

  // ============================================================
  // スタンプ獲得
  // ============================================================

  Future<void> _collectStamp(Seichi seichi) async {
    if (_isCollecting || _collectedIds.contains(seichi.id)) {
      return;
    }

    appDebugPrint(
      '[STAMP_COLLECT] name=${seichi.name}, card=${seichi.card}, id=${seichi.id}',
    );
    _isCollecting = true;

    try {
      final position = _currentPosition;
      final placeId = seichi.placeId;

      if (position == null || placeId == null || placeId.isEmpty) {
        return;
      }

      await _ensureCloudUser();

      final collectedRows = await _historyService.recordPlaceVisitAndCollect(
        placeId: placeId,
        visitedAt: DateTime.now(),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );

      await _applyCollectedRows(collectedRows, showLevelUp: true);
    } finally {
      _isCollecting = false;
    }
  }

  Future<void> _applyCollectedRows(
    List<Map<String, dynamic>> collectedRows, {
    bool showLevelUp = false,
  }) async {
    final currentEventId = _currentEventId;

    if (collectedRows.isEmpty || currentEventId == null) {
      return;
    }

    final previousCollectedCount = _getCollectedCount();

    final collectedCards = collectedRows
        .where((row) => row['event_id']?.toString() == currentEventId)
        .map((row) => row['card']?.toString())
        .whereType<String>()
        .where((card) => card.isNotEmpty)
        .toSet();

    if (collectedCards.isEmpty) {
      return;
    }

    final newlyCollectedSeichi = _seichiList
        .where(
          (item) =>
              collectedCards.contains(item.card) &&
              !_collectedIds.contains(item.id),
        )
        .toList(growable: false);

    if (newlyCollectedSeichi.isEmpty) {
      return;
    }

    for (final item in newlyCollectedSeichi) {
      _collectedIds.add(item.id);
    }

    appDebugPrint(
      '[ROUTE-NEXT] COLLECTED '
      'new=${newlyCollectedSeichi.map((item) => '${item.card}:${item.name}:${item.id}').toList()} '
      'activeBefore=${_activeRecommendedRoute.map((item) => '${item.card}:${item.id}').toList()} '
      'manualBefore=$_manualNextSeichiId',
    );

    if (_activeRecommendedRoute.isNotEmpty) {
      _activeRecommendedRoute.removeWhere(
        (item) => _collectedIds.contains(item.id),
      );

      if (_activeRecommendedRoute.isNotEmpty) {
        _manualNextSeichiId = _activeRecommendedRoute.first.id;
      } else {
        _manualNextSeichiId = null;
      }
    } else if (_manualNextSeichiId != null &&
        newlyCollectedSeichi.any((item) => item.id == _manualNextSeichiId)) {
      _manualNextSeichiId = null;
    }

    appDebugPrint(
      '[ROUTE-NEXT] AFTER ROUTE ADVANCE '
      'active=${_activeRecommendedRoute.map((item) => '${item.card}:${item.id}').toList()} '
      'manual=$_manualNextSeichiId',
    );

    await _saveManualNextDestination();
    if (_isRecommendedRouteLoaded) {
      await _saveRecommendedRoute();
    } else {
      appDebugPrint('[ROUTE-PERSIST] save skipped: route state not loaded yet');
    }
    await _saveStamps();
    await _loadCollectionEventNames();
    await _loadMyEventRank();

    final previousLevel = _levelProgress?.level;

    await _loadLevelProgress();

    final newLevel = _levelProgress?.level;

    final didLevelUp =
        showLevelUp &&
        previousLevel != null &&
        newLevel != null &&
        newLevel > previousLevel;

    final newCollectedCount = _getCollectedCount();

    final didCompleteQuest =
        _seichiList.isNotEmpty &&
        previousCollectedCount < _seichiList.length &&
        newCollectedCount >= _seichiList.length;

    final previousAchievements = _achievementService.getUnlockedAchievements(
      _eventAchievements,
      previousCollectedCount,
    );

    final newAchievements = _achievementService.getUnlockedAchievements(
      _eventAchievements,
      newCollectedCount,
    );

    final newlyUnlockedAchievements = newAchievements
        .where(
          (achievement) => !previousAchievements.any(
            (previous) => previous.id == achievement.id,
          ),
        )
        .toList(growable: false);

    if (!mounted) {
      return;
    }

    for (var i = 0; i < newlyCollectedSeichi.length; i++) {
      final item = newlyCollectedSeichi[i];

      if (!mounted) {
        return;
      }

      setState(() {
        _justCollected = true;
        _collectedName = '${item.card} ${item.name}を獲得！';
      });

      if (_preferences?.getBool('setting_stamp_notification') ?? true) {
        try {
          await NotificationService.instance.showStampCollected(
            seichiName: '${item.card} ${item.name}',
          );
        } catch (_) {
          // 通知失敗時もスタンプ獲得状態は維持する。
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 2800));

      if (!mounted) {
        return;
      }

      setState(() {
        _justCollected = false;
        _collectedName = null;
      });

      if (i < newlyCollectedSeichi.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }

    _updateNextDestination();

    if (didLevelUp) {
      await _showLevelUpDialog(
        previousLevel: previousLevel,
        newLevel: newLevel,
      );
    }

    for (final achievement in newlyUnlockedAchievements) {
      await _showAchievementUnlockDialog(achievement);
    }

    if (didCompleteQuest) {
      await _showQuestCompleteDialog(totalCount: _seichiList.length);
    }
  }

  // ============================================================
  // カメラを現在地へ
  // ============================================================

  Future<void> _showLevelUpDialog({
    required int previousLevel,
    required int newLevel,
  }) async {
    if (!mounted || newLevel <= previousLevel) {
      return;
    }

    final progress = _levelProgress;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 46,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'LEVEL UP!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Lv.$previousLevel  →  Lv.$newLevel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (progress != null)
                  Text(
                    '累計 ${progress.totalXp} XP',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('冒険を続ける'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAchievementUnlockDialog(Achievement achievement) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🎉 実績解除！', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(achievement.icon, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('OK'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQuestCompleteDialog({required int totalCount}) async {
    if (!mounted || totalCount <= 0) {
      return;
    }

    final eventName = _currentEventName?.trim();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 48,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'QUEST COMPLETE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.deepPurple,
                  ),
                ),
                if (eventName != null && eventName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    eventName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$totalCount / $totalCount',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '全スポット制覇！',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'すべてのスポットを巡り、'
                  'スタンプを集めました。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.5,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'コンプリート！',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _moveCameraToCurrentLocation() async {
    final position = _currentPosition;

    if (position == null || _mapController == null) {
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 13.5,
        ),
      ),
    );
  }

  // ============================================================
  // 次の聖地へ
  // ============================================================

  Future<void> _startNavigationToNextSeichi() async {
    final seichi = _nextSeichi;

    if (seichi == null) {
      return;
    }

    try {
      final launched = await const ExternalNavigationService().openDirections(
        latitude: seichi.latitude,
        longitude: seichi.longitude,
      );

      if (launched || !mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ナビを起動できませんでした。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      appDebugPrint('[NAVIGATION] launch failed: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ナビを起動できませんでした。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _moveCameraToNextSeichi() async {
    final seichi = _nextSeichi;

    if (seichi == null || _mapController == null) {
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(seichi.latitude, seichi.longitude),
          zoom: 16.0,
        ),
      ),
    );
  }

  // ============================================================
  // 特定聖地へ移動
  // ============================================================

  Future<void> _moveCameraToSeichi(Seichi seichi) async {
    _pendingMapSeichi = seichi;

    // 別タブからマップへ戻る場合、現在の controller は
    // 破棄される旧Mapに属している可能性がある。
    // 選択地点は pending のまま保持し、新しいMapの
    // onMapCreated でカメラ移動する。
    if (mounted && _selectedTab != 0) {
      _mapController = null;

      setState(() {
        _selectedTab = 0;
      });

      return;
    }

    final controller = _mapController;

    // Map生成待ちの場合は pending を残す。
    if (controller == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(seichi.latitude, seichi.longitude),
          zoom: 17,
        ),
      ),
    );

    // この地点への移動が完了した場合だけ pending を解除。
    if (_pendingMapSeichi?.id == seichi.id) {
      _pendingMapSeichi = null;
    }
  }

  // ============================================================
  // マーカー
  // ============================================================

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final seichi in _seichiList) {
      final collected = _collectedIds.contains(seichi.id);

      appDebugPrint(
        '[MARKER] ${seichi.name} id=${seichi.id} collected=$collected',
      );

      markers.add(
        Marker(
          markerId: MarkerId(seichi.id),
          position: LatLng(seichi.latitude, seichi.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            collected ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(
            title: '${seichi.icon} ${seichi.card} ${seichi.name}',
            snippet: collected
                ? '🏆 スタンプ獲得済み'
                : '${seichi.reading} ・ '
                      '到達半径 ${seichi.stampRadiusMeters}m',
          ),
          onTap: () {
            _showSeichiDetails(seichi);
          },
        ),
      );
    }

    return markers;
  }

  // ============================================================
  // 聖地詳細
  // ============================================================

  void _showSeichiDetails(Seichi seichi) {
    final position = _currentPosition;

    double? distance;

    if (position != null) {
      distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        seichi.latitude,
        seichi.longitude,
      );
    }

    final collected = _collectedIds.contains(seichi.id);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        seichi.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seichi.card,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            seichi.name,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (collected)
                      const Icon(Icons.verified, color: Colors.green, size: 30),
                  ],
                ),
                const SizedBox(height: 16),
                if (seichi.reading.isNotEmpty)
                  Text(
                    seichi.reading,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                const SizedBox(height: 8),
                Text(
                  seichi.description.isEmpty
                      ? '説明は登録されていません。'
                      : seichi.description,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.radar, size: 20),
                    const SizedBox(width: 8),
                    Text('到達判定 ${seichi.stampRadiusMeters}m'),
                  ],
                ),
                if (distance != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.near_me, size: 20),
                      const SizedBox(width: 8),
                      Text('現在地から ${_formatDistance(distance)}'),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _moveCameraToSeichi(seichi);
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('この聖地を地図で見る'),
                  ),
                ),
                if (!collected) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _setNextDestination(seichi);
                      },
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('次の目的地にする'),
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
  // 距離表示
  // ============================================================

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    }

    return '${(distance / 1000).toStringAsFixed(1)}km';
  }

  // ============================================================
  // ソナー強度
  // ============================================================

  // ============================================================
  // エラー
  // ============================================================

  // ============================================================
  // 次の目的地カード
  // ============================================================

  // ============================================================
  // スタンプ獲得演出
  // ============================================================

  // ============================================================
  // コレクションバッジ
  // ============================================================

  // ============================================================
  // 現在地ボタン
  // ============================================================

  // ============================================================
  // 次の目的地ボタン
  // ============================================================

  // ============================================================
  // Google Maps
  // ============================================================

  // ============================================================
  // マップ画面
  // ============================================================

  Widget _buildMapPage() {
    return MapPage(
      mapController: _mapController,
      currentPosition: _currentPosition,
      realWorldState: _realWorldState,
      nextSeichi: _nextSeichi,
      nextDistance: _nextDistance,
      collectedIds: _collectedIds,
      isLoadingLocation: _isLoadingLocation,
      errorMessage: _errorMessage,
      sonarController: _sonarController,
      justCollected: _justCollected,
      collectedName: _collectedName,
      collectedCount: _getCollectedCount(),
      total: _seichiList.length,
      defaultCenter: _defaultCenter,
      markers: _buildMarkers(),
      onMoveToCurrentLocation: _moveCameraToCurrentLocation,
      onMoveToNextSeichi: _moveCameraToNextSeichi,
      onStartNavigation: _startNavigationToNextSeichi,
      onMapCreated: (controller) {
        _mapController = controller;

        if (_pendingMapSeichi != null) {
          final seichi = _pendingMapSeichi!;
          _pendingMapSeichi = null;
          _moveCameraToSeichi(seichi);
          return;
        }

        if (_focusNextDestinationOnMapOpen && _nextSeichi != null) {
          _focusNextDestinationOnMapOpen = false;
          _moveCameraToNextSeichi();
          return;
        }

        if (_currentPosition != null) {
          _moveCameraToCurrentLocation();
        }
      },
      onDismissError: () {
        setState(() {
          _errorMessage = null;
        });
      },
    );
  }
  // ============================================================
  // クエスト画面
  // ============================================================

  Widget _buildQuestPage() {
    return QuestPage(
      nextSeichi: _nextSeichi,
      nextDistance: _nextDistance,
      collectedCount: _getCollectedCount(),
      total: _seichiList.length,
      onShowDestination: _moveCameraToNextSeichi,
      eventAchievements: _eventAchievements,
    );
  }

  Widget _buildRankingPage() {
    final eventId = _currentEventId;

    if (eventId == null || eventId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RankingPage(
      eventId: eventId,
      displayName: _displayName,
      onShowProfile: () async {
        final changed = await Navigator.of(context)
            .push<bool>(MaterialPageRoute(builder: (_) => const ProfilePage()));

        if (changed != true) {
          return false;
        }

        await _loadDisplayName();
        await _loadMyEventRank();

        return true;
      },
      myRank: _myEventRank,

      myCount: _getCollectedCount(),
      total: _seichiList.length,
    );
  }
  // ============================================================
  // マイページ
  // ============================================================

  Future<void> _selectEvent(Event event) async {
    final eventId = event.id;
    final eventName = event.name;

    if (eventId.isEmpty) {
      throw Exception('選択したイベントのIDが取得できません。');
    }

    if (eventId == _currentEventId) {
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      _currentEventId = eventId;
      _currentEventName = eventName;

      _collectedIds.clear();
      _eventAchievements.clear();
      _myEventRank = null;
      _manualNextSeichiId = null;
      _activeRecommendedRoute.clear();
      _isRecommendedRouteLoaded = false;

      await _loadEventAchievements();
      await _loadSavedStamps();

      final syncedRows = await _historyService.syncPendingPlaceVisits();

      await _loadSeichi();
      await _applyCollectedRows(syncedRows);
      await _loadCloudHistory();
      await _loadManualNextDestination();
      await _loadRecommendedRoute();

      if (_activeRecommendedRoute.isNotEmpty) {
        _manualNextSeichiId = _activeRecommendedRoute.first.id;
      }
      await _loadMyEventRank();
      await _saveCurrentEventPreference(eventId);
      await _ensureEventParticipation(eventId);

      _updateNextDestination();

      if (mounted) {
        setState(() {});
      }

      appDebugPrint('[EVENT] selected: id=, name=');
    } catch (e) {
      appDebugPrint('[EVENT] select error: ');

      if (mounted) {
        setState(() {
          _errorMessage = 'クエストの切り替えに失敗しました。';
        });
      }

      rethrow;
    }
  }

  Future<void> _showEventSelector() async {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('表示できるクエストがありません。')));
      return;
    }

    final client = supabase.Supabase.instance.client;
    final user = client.auth.currentUser;

    Map<String, bool>? participationStates;

    if (user != null) {
      try {
        final data = await client
            .from('user_event_participations')
            .select('event_id, is_active')
            .eq('user_id', user.id);

        final rows = List<Map<String, dynamic>>.from(data);

        participationStates = <String, bool>{};

        for (final row in rows) {
          final eventId = row['event_id']?.toString();

          if (eventId == null || eventId.isEmpty) {
            continue;
          }

          participationStates[eventId] = row['is_active'] == true;
        }
      } catch (error) {
        appDebugPrint('[EVENT] participation status load failed: $error');
      }
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              const Text(
                'クエスト一覧',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '詳細を確認してから参加・選択できます。',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              ..._events.map((event) {
                final eventId = event.id;
                final eventName = event.name;
                final description = event.description;

                final isCurrent = eventId == _currentEventId;

                String statusLabel;
                IconData statusIcon;
                Color statusColor;

                if (isCurrent) {
                  statusLabel = '選択中';
                  statusIcon = Icons.check_circle;
                  statusColor = Colors.deepPurple;
                } else if (participationStates == null) {
                  statusLabel = '状態不明';
                  statusIcon = Icons.help_outline;
                  statusColor = Colors.grey;
                } else if (participationStates[eventId] == true) {
                  statusLabel = '参加中';
                  statusIcon = Icons.flag_outlined;
                  statusColor = Colors.green;
                } else if (participationStates.containsKey(eventId)) {
                  statusLabel = '過去に参加';
                  statusIcon = Icons.history_outlined;
                  statusColor = Colors.orange;
                } else {
                  statusLabel = '未参加';
                  statusIcon = Icons.add_circle_outline;
                  statusColor = Colors.grey;
                }

                String? primaryActionLabel;

                if (!isCurrent) {
                  switch (statusLabel) {
                    case '参加中':
                      primaryActionLabel = 'このクエストを選ぶ';
                      break;

                    case '過去に参加':
                      primaryActionLabel = '再参加して選ぶ';
                      break;

                    case '未参加':
                      primaryActionLabel = '参加して選ぶ';
                      break;

                    default:
                      primaryActionLabel = null;
                  }
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  leading: Icon(
                    isCurrent ? Icons.check_circle : Icons.explore_outlined,
                    color: isCurrent ? Colors.deepPurple : null,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(eventName)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  subtitle: description.isEmpty
                      ? null
                      : Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.chevron_right),

                  // ------------------------------------------------
                  // ここでは選択しない。
                  // まず詳細画面を開く。
                  // ------------------------------------------------
                  onTap: () async {
                    Navigator.of(sheetContext).pop();

                    await Future<void>.delayed(Duration.zero);

                    if (!mounted) {
                      return;
                    }

                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => EventDetailPage(
                          event: event,
                          currentPosition: _currentPosition,

                          participationLabel: statusLabel,

                          collectedCount: isCurrent
                              ? _getCollectedCount()
                              : null,

                          totalCount: isCurrent ? _seichiList.length : null,

                          currentNextSeichiId: isCurrent
                              ? _nextSeichi?.id
                              : null,

                          onSetNextDestination: isCurrent
                              ? _setNextDestination
                              : null,
                          onStartRecommendedRoute: (route) async {
                            if (route.isEmpty) {
                              return;
                            }

                            final routeSeichiIds = route
                                .map((seichi) => seichi.id)
                                .toList(growable: false);

                            if (!isCurrent) {
                              await _selectEvent(event);
                            }

                            if (!mounted) {
                              return;
                            }

                            final seichiById = <String, Seichi>{
                              for (final seichi in _seichiList)
                                seichi.id: seichi,
                            };

                            final selectedRoute = <Seichi>[];

                            for (final seichiId in routeSeichiIds) {
                              final seichi = seichiById[seichiId];

                              if (seichi == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('巡回ルートの目的地を取得できませんでした。'),
                                  ),
                                );
                                return;
                              }

                              selectedRoute.add(seichi);
                            }

                            if (selectedRoute.isEmpty) {
                              return;
                            }

                            Navigator.of(context).pop();

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) {
                                return;
                              }

                              _startRecommendedRoute(selectedRoute);
                            });
                          },
                          onShowOnMap: isCurrent
                              ? (seichi) {
                                  Navigator.of(context).pop();

                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) {
                                      return;
                                    }

                                    _moveCameraToSeichi(seichi);
                                  });
                                }
                              : null,

                          primaryActionLabel: primaryActionLabel,

                          onPrimaryAction: primaryActionLabel == null
                              ? null
                              : () async {
                                  await _selectEvent(event);
                                },

                          onSelectAnotherEvent: () async {
                            Navigator.of(context).pop();

                            await _showEventSelector();
                          },
                        ),
                      ),
                    );

                    if (changed == true && mounted) {
                      setState(() {});
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyPage() {
    return MyPage(
      displayName: _displayName,
      avatarKey: _avatarKey,
      myRank: _myEventRank,
      levelProgress: _levelProgress,
      eventAchievements: _eventAchievements,
      count: _getCollectedCount(),
      total: _seichiList.length,
      currentEventName: _currentEventName,
      nextDestinationName: _nextSeichi?.name,
      nextDestinationCard: _nextSeichi?.card,
      nextDestinationIcon: _nextSeichi?.icon,
      nextDestinationDistance: _nextDistance,
      onShowNextDestination: () {
        if (_nextSeichi == null) {
          return;
        }

        _focusNextDestinationOnMapOpen = true;

        setState(() {
          _selectedTab = 0;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          if (_mapController != null && _focusNextDestinationOnMapOpen) {
            _focusNextDestinationOnMapOpen = false;
            _moveCameraToNextSeichi();
          }
        });
      },
      onShowEventExplore: () async {
        final result = await Navigator.of(context).push<Object?>(
          MaterialPageRoute(
            builder: (_) => EventExplorePage(
              events: _events,
              currentPosition: _currentPosition,
              currentEventId: _currentEventId,
              currentCollectedCount: _getCollectedCount(),
              currentTotalCount: _seichiList.length,
              currentNextSeichiId: _nextSeichi?.id,
              onSetNextDestination: _setNextDestination,
              onShowOnMap: (seichi) {
                Navigator.of(context).pop(seichi);
              },
              onStartRecommendedRoute: _startRecommendedRoute,
            ),
          ),
        );

        if (result == null) {
          return;
        }

        if (result is Seichi) {
          await _moveCameraToSeichi(result);
          return;
        }

        if (result is! String || result.isEmpty || result == _currentEventId) {
          return;
        }

        final selectedEventId = result;

        Event? selectedEvent;

        for (final event in _events) {
          if (event.id == selectedEventId) {
            selectedEvent = event;
            break;
          }
        }

        if (selectedEvent == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('選択したクエスト情報を取得できません。')),
            );
          }
          return;
        }

        await _selectEvent(selectedEvent);
      },
      onShowFavoriteEvents: () async {
        final result = await Navigator.of(context).push<Object?>(
          MaterialPageRoute(
            builder: (_) => EventExplorePage(
              events: _events,
              currentPosition: _currentPosition,
              initialFavoriteOnly: true,
              currentEventId: _currentEventId,
              currentCollectedCount: _getCollectedCount(),
              currentTotalCount: _seichiList.length,
              currentNextSeichiId: _nextSeichi?.id,
              onSetNextDestination: _setNextDestination,
              onShowOnMap: (seichi) {
                Navigator.of(context).pop(seichi);
              },
              onStartRecommendedRoute: _startRecommendedRoute,
            ),
          ),
        );

        if (result == null) {
          return;
        }

        if (result is Seichi) {
          await _moveCameraToSeichi(result);
          return;
        }

        if (result is! String || result.isEmpty || result == _currentEventId) {
          return;
        }

        final selectedEventId = result;

        Event? selectedEvent;

        for (final event in _events) {
          if (event.id == selectedEventId) {
            selectedEvent = event;
            break;
          }
        }

        if (selectedEvent == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('選択したクエスト情報を取得できません。')),
            );
          }
          return;
        }

        await _selectEvent(selectedEvent);
      },
      onShowParticipatingEvents: () async {
        final selectedEventId = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) =>
                ParticipatingEventsPage(currentEventId: _currentEventId),
          ),
        );

        if (selectedEventId == null ||
            selectedEventId.isEmpty ||
            selectedEventId == _currentEventId) {
          return;
        }

        Event? selectedEvent;

        for (final event in _events) {
          if (event.id == selectedEventId) {
            selectedEvent = event;
            break;
          }
        }

        if (selectedEvent == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('選択したクエスト情報を取得できません。')),
            );
          }
          return;
        }

        await _selectEvent(selectedEvent);
      },
      onShowCurrentEvent: () async {
        Event? currentEvent;

        for (final event in _events) {
          if (event.id == _currentEventId) {
            currentEvent = event;
            break;
          }
        }

        if (currentEvent == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('現在のクエスト情報を取得できません。')));
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailPage(
              event: currentEvent!,
              currentPosition: _currentPosition,
              collectedCount: _getCollectedCount(),
              totalCount: _seichiList.length,
              currentNextSeichiId: _nextSeichi?.id,
              onSetNextDestination: _setNextDestination,
              onStartRecommendedRoute: (route) {
                Navigator.of(context).pop();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }

                  _startRecommendedRoute(route);
                });
              },
              onShowOnMap: (seichi) {
                Navigator.of(context).pop();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }

                  _moveCameraToSeichi(seichi);
                });
              },
              onSelectAnotherEvent: () async {
                Navigator.of(context).pop();
                await _showEventSelector();
              },
            ),
          ),
        );
      },
      onSelectEvent: _showEventSelector,
      onShowRanking: () {
        setState(() {
          _selectedTab = 3;
        });
      },
      onShowAchievements: () {
        setState(() {
          _selectedTab = 1;
        });
      },
      onShowAdventureLog: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AdventureLogPage()));
      },
      onShowSyncStatus: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SyncStatusPage(
              loadPendingCount: _historyService.pendingPlaceVisitCount,
              syncNow: () async {
                final syncedRows = await _historyService
                    .syncPendingPlaceVisits();

                await _applyCollectedRows(syncedRows);
                await _loadCloudHistory();
                await _loadCollectionEventNames();
                await _loadMyEventRank();

                _updateNextDestination();

                if (mounted) {
                  setState(() {});
                }

                return _historyService.pendingPlaceVisitCount();
              },
            ),
          ),
        );
      },
      onShowProfile: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ProfilePage()));

        await _loadDisplayName();
        await _loadMyEventRank();
        _updateNextDestination();
        await _checkStampDistance();
      },
      onShowAccount: () async {
        final accountChanged = await Navigator.of(context)
            .push<bool>(MaterialPageRoute(builder: (_) => const AccountPage()));

        if (accountChanged != true) {
          return;
        }

        await _ensureCloudUser();

        _manualNextSeichiId = null;
        _activeRecommendedRoute.clear();
        _isRecommendedRouteLoaded = false;

        await _loadDisplayName();
        await _loadEventAchievements();
        await _loadSavedStamps();

        final syncedRows = await _historyService.syncPendingPlaceVisits();

        await _applyCollectedRows(syncedRows);
        await _loadCloudHistory();
        await _loadManualNextDestination();
        await _loadRecommendedRoute();

        if (_activeRecommendedRoute.isNotEmpty) {
          _manualNextSeichiId = _activeRecommendedRoute.first.id;
        }
        await _loadCollectionEventNames();
        await _loadMyEventRank();

        _updateNextDestination();

        if (mounted) {
          setState(() {});
        }
      },
      onShowNotifications: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
        );
      },
      onShowAbout: _showAbout,
      onShowSettings: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppSettingsPage(
              onResetEventCollectionHistory:
                  _resetCurrentEventCollectionHistory,
              onTestQuestComplete: () async {
                await _showQuestCompleteDialog(totalCount: _seichiList.length);
              },
              onTestRecommendedRouteNext: _testRecommendedRouteNext,
            ),
          ),
        );
      },
    );
  }
  // ============================================================
  // ページヘッダー
  // ============================================================

  // ============================================================
  // アプリ情報
  // ============================================================

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: '聖地クエスト',
      applicationVersion: '1.0.0',
      applicationLegalese: '上毛かるた × 群馬',
      children: const [
        SizedBox(height: 12),
        Text(
          '群馬県内の聖地を巡りながら、'
          '上毛かるたの世界を楽しむ聖地巡礼アプリです。',
        ),
      ],
    );
  }

  // ============================================================
  // 現在のページ
  // ============================================================

  Widget _buildCurrentPage() {
    switch (_selectedTab) {
      case 0:
        return _buildMapPage();

      case 1:
        return _buildQuestPage();

      case 2:
        return CollectionPage(
          seichiList: _seichiList,
          collectedIds: _collectedIds,
          eventNamesByCard: _collectionEventNamesByCard,
          collectionFilter: _collectionFilter,
          onFilterChanged: (value) {
            setState(() {
              _collectionFilter = value;
            });
          },
          onMoveToSeichi: _moveCameraToSeichi,
          onSetNextDestination: _setNextDestination,
        );

      case 3:
        return _buildRankingPage();

      case 4:
        return _buildMyPage();

      default:
        return _buildMapPage();
    }
  }

  // ============================================================
  // Loading
  // ============================================================

  Widget _buildLoading() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 42, height: 42, child: CircularProgressIndicator()),
            SizedBox(height: 20),
            Text(
              '聖地クエストを起動中…',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: _buildLoading());
    }

    return Scaffold(
      extendBody: true,
      body: _buildCurrentPage(),

      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: QuestUiTokens.ink.withValues(alpha: 0.46),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.42),
                      width: 1.0,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: QuestUiTokens.ink.withValues(alpha: 0.055),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    height: 72,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    indicatorColor: Colors.white.withValues(alpha: 0.18),
                    indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        QuestUiTokens.controlRadius,
                      ),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.42),
                        width: 0.9,
                      ),
                    ),
                    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
                      states,
                    ) {
                      final selected = states.contains(WidgetState.selected);

                      return IconThemeData(
                        size: selected ? 27 : 24,
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.72),
                      );
                    }),
                    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                      states,
                    ) {
                      final selected = states.contains(WidgetState.selected);

                      return TextStyle(
                        fontSize: selected ? 11.5 : 10.5,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.72),
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 3),
                        ],
                      );
                    }),
                  ),
                  child: NavigationBar(
                    selectedIndex: _selectedTab,
                    onDestinationSelected: (index) {
                      setState(() {
                        _selectedTab = index;
                      });
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.map_outlined),
                        selectedIcon: Icon(Icons.map_rounded),
                        label: 'マップ',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.flag_outlined),
                        selectedIcon: Icon(Icons.flag_rounded),
                        label: 'クエスト',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.workspace_premium_outlined),
                        selectedIcon: Icon(Icons.workspace_premium_rounded),
                        label: 'スタンプ',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.leaderboard_outlined),
                        selectedIcon: Icon(Icons.leaderboard_rounded),
                        label: 'ランキング',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: 'マイページ',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();

    _sonarController.dispose();

    _mapController = null;

    super.dispose();
  }
}

// ============================================================
// スタンプ円形リング
// ============================================================

// ============================================================
// ソナー描画
// ============================================================
