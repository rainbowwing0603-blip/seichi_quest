import 'dart:math' as math;

import 'dart:ui';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
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
import 'widgets/event_explore_page.dart';
import 'widgets/sync_status_page.dart';
import 'widgets/notification_settings_page.dart';
import 'widgets/app_settings_page.dart';
import 'widgets/quest_ui.dart';
import 'widgets/onboarding_page.dart';
import 'widgets/license_page.dart';
import 'models/quest_item.dart';
import 'models/achievement.dart';
import 'models/content_block.dart';
import 'models/event.dart';
import 'services/level_service.dart' show LevelProgress;
import 'services/location_service.dart';
import 'services/marker_cache_revision.dart';
import 'services/next_destination_service.dart';
import 'services/notification_service.dart';
import 'services/onboarding_service.dart';
import 'services/stamp_eligibility_policy.dart';
import 'services/string_set_equality.dart';
import 'services/stamp_cache_service.dart';
import 'models/real_world_state.dart';
import 'services/external_navigation_service.dart';
import 'services/weather_service.dart';
import 'services/weather_refresh_policy.dart';
import 'services/content_block_service.dart';
import 'services/content_block_presentation_policy.dart';
import 'widgets/content_block_renderer.dart';

import 'services/app_logger.dart';
import 'services/collection_sync_service.dart';
import 'services/collection_apply_policy.dart';
import 'services/collection_display_policy.dart';
import 'services/collection_progress_policy.dart';
import 'services/event_service.dart';
import 'services/event_switch_coordinator.dart';
import 'services/destination_persistence_service.dart';
import 'services/recommended_route_policy.dart';
import 'services/progression_service.dart';
import 'services/profile_service.dart';
import 'services/session_service.dart';
import 'services/secondary_refresh_coordinator.dart';
import 'services/startup_coordinator.dart';
import 'services/quest_item_service.dart';
import 'services/account_refresh_coordinator.dart';
import 'services/app_settings_service.dart';
import 'services/interstitial_ad_service.dart';

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

  await supabase.Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const SeichiQuestApp());

  // 広告と通知は初回フレームの表示には不要。
  // Google Maps と同時にネイティブSDKを初期化すると起動直後の
  // main thread 負荷が集中するため、最初の描画後へ逃がす。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeDeferredPlatformServices());
  });
}

Future<void> _initializeDeferredPlatformServices() async {
  try {
    await MobileAds.instance.initialize();
  } catch (error) {
    appDebugPrint('[STARTUP] Mobile Ads init failed: $error');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (error) {
    appDebugPrint('[STARTUP] notification init failed: $error');
  }
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
        fontFamily: 'NotoSansJP',
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const CollectionApplyPolicy _collectionApplyPolicy =
      CollectionApplyPolicy();
  static const CollectionDisplayPolicy _collectionDisplayPolicy =
      CollectionDisplayPolicy();
  static const CollectionProgressPolicy _collectionProgressPolicy =
      CollectionProgressPolicy();

  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSubscription;

  static const LocationService _locationService = LocationService();

  Position? _currentPosition;

  // スタンプ判定に使用した直前のGPS位置。
  // GPSの急跳びによる誤獲得を防ぐために使用する。
  Position? _lastStampCheckPosition;

  final WeatherService _weatherService = WeatherService();
  static const WeatherRefreshPolicy _weatherRefreshPolicy =
      WeatherRefreshPolicy();
  RealWorldState? _realWorldState;
  DateTime? _lastWeatherFetchAt;
  Position? _lastWeatherFetchPosition;
  bool _isWeatherFetchInProgress = false;

  List<QuestItem> _seichiList = [];
  final Set<String> _collectedIds = {};
  final Map<String, Set<String>> _collectionEventNamesByContentKey = {};

  final CollectionHistoryService _historyService = CollectionHistoryService();
  static const NextDestinationService _nextDestinationService =
      NextDestinationService();
  final EventService _eventService = EventService();
  static const EventSwitchCoordinator _eventSwitchCoordinator =
      EventSwitchCoordinator();
  final ProgressionService _progressionService = ProgressionService();
  final ProfileService _profileService = ProfileService();
  final SessionService _sessionService = SessionService();
  static const SecondaryRefreshCoordinator _secondaryRefreshCoordinator =
      SecondaryRefreshCoordinator();
  static const StartupCoordinator _startupCoordinator = StartupCoordinator();
  final QuestItemService _questItemService = QuestItemService();
  static const AccountRefreshCoordinator _accountRefreshCoordinator =
      AccountRefreshCoordinator();
  final AppSettingsService _appSettingsService = AppSettingsService();
  final DestinationPersistenceService _destinationPersistenceService =
      DestinationPersistenceService();
  final StampCacheService _stampCacheService = StampCacheService();
  final ContentBlockService _contentBlockService = ContentBlockService();
  static const ContentBlockPresentationPolicy _contentBlockPresentationPolicy =
      ContentBlockPresentationPolicy();
  static const ExternalNavigationService _externalNavigationService =
      ExternalNavigationService();
  late final CollectionSyncService _collectionSyncService =
      CollectionSyncService(
        historyService: _historyService,
        stampCacheService: _stampCacheService,
      );

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

  final OnboardingService _onboardingService = OnboardingService();
  bool _isOnboardingReady = false;
  bool _shouldShowOnboarding = false;

  String? _errorMessage;
  String? _errorActionLabel;
  Future<void> Function()? _errorAction;

  // スタンプ獲得可否とは別に、地図やNEXT表示にも影響するほど
  // 現在地の精度が低い状態を表す。
  bool _hasVeryLowLocationAccuracy = false;

  // 低精度警告をユーザーが閉じた状態。
  // GPS精度そのものとは分離して管理する。
  bool _isLowAccuracyWarningDismissed = false;
  BitmapDescriptor? _uncollectedMarkerIcon;
  BitmapDescriptor? _collectedMarkerIcon;
  BitmapDescriptor? _nextMarkerIcon;
  Set<Marker>? _staticMarkerCache;
  String? _staticMarkerCacheNextId;
  BitmapDescriptor? _staticMarkerCacheUncollectedIcon;
  BitmapDescriptor? _staticMarkerCacheCollectedIcon;
  final MarkerCacheRevision _markerCacheRevision = MarkerCacheRevision();
  int _staticMarkerCacheRevision = -1;
  QuestItem? _nextSeichi;
  double? _nextDistance;
  bool _isQuestHudCollapsed = false;

  bool _focusNextDestinationOnMapOpen = false;
  QuestItem? _pendingMapSeichi;

  // ユーザーが「次の目的地にする」で指定した聖地。
  // 未指定時は従来どおり、現在地から最も近い未獲得聖地を自動選択する。
  String? _manualNextSeichiId;

  // おすすめ巡回ルート開始中の未完了ルート。
  // 先頭要素が現在のNEXT目的地になる。
  final List<QuestItem> _activeRecommendedRoute = <QuestItem>[];

  // 現在のユーザー・イベントについて、
  // おすすめルートの永続化状態を読み込み済みかどうか。
  bool _isRecommendedRouteLoaded = false;

  bool _justCollected = false;
  String? _collectedName;

  bool _isCollecting = false;

  late AnimationController _sonarController;
  int _lastMarkerAnimationFrame = -1;

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

  // ============================================================
  // 初期化
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _sonarController.addListener(_onMarkerAnimationTick);

    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }

    if (!_isOnboardingReady || _shouldShowOnboarding) {
      return;
    }

    if (_positionSubscription == null) {
      unawaited(_initializeLocation());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_uncollectedMarkerIcon == null ||
        _collectedMarkerIcon == null ||
        _nextMarkerIcon == null) {
      // 初回フレームとネイティブMap生成に画像デコードを重ねない。
      // 読み込み完了までは既存のdefault markerへ自然にフォールバックする。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted &&
              (_uncollectedMarkerIcon == null ||
                  _collectedMarkerIcon == null ||
                  _nextMarkerIcon == null)) {
            unawaited(_loadMapMarkerIcons());
          }
        });
      });
    }
  }

  Future<void> _loadCurrentEvent() async {
    try {
      final selection = await _eventService.loadCurrentEvent();

      _events = selection.events;
      _currentEventId = selection.currentEvent.id;
      _currentEventName = selection.currentEvent.name;
    } catch (e) {
      appDebugPrint('現在のイベント取得エラー: $e');
      rethrow;
    }
  }

  Future<void> _loadEventAchievements() async {
    try {
      final eventId = _currentEventId;

      if (eventId == null || eventId.isEmpty) {
        throw Exception('イベントIDが未取得のため、チャレンジを読み込めません。');
      }

      _eventAchievements = await _progressionService.loadEventAchievements(
        eventId,
      );
    } catch (error) {
      _eventAchievements = <Achievement>[];
      appDebugPrint('[ACHIEVEMENTS] load failed: $error');
    }
  }

  Future<void> _loadMapMarkerIcons() async {
    try {
      final configuration = createLocalImageConfiguration(context);

      final icons = await Future.wait<BitmapDescriptor>([
        BitmapDescriptor.asset(
          configuration,
          'assets/map_markers/marker_uncollected.png',
          width: 36,
          height: 48,
        ),
        BitmapDescriptor.asset(
          configuration,
          'assets/map_markers/marker_collected.png',
          width: 36,
          height: 48,
        ),
        BitmapDescriptor.asset(
          configuration,
          'assets/map_markers/marker_next.png',
          width: 42,
          height: 56,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _markerCacheRevision.markChanged();
        _uncollectedMarkerIcon = icons[0];
        _collectedMarkerIcon = icons[1];
        _nextMarkerIcon = icons[2];
      });

      appDebugPrint('[MARKER] crystal icons loaded');
    } catch (error) {
      appDebugPrint('[MARKER] crystal icon load failed: $error');
    }
  }

  Future<void> _initialize() async {
    final onboardingCompletedFuture = _onboardingService.isCompleted();

    appDebugPrint('[STARTUP] critical start');
    final criticalResult = await _startupCoordinator.runCritical(
      ensureCloudUser: _ensureCloudUser,
      loadCurrentEvent: _loadCurrentEvent,
      startCollectionSync: () async {
        final result = await _startCollectionSync();
        return result.pendingCollectedRows;
      },
      loadSeichi: _loadSeichi,
    );
    appDebugPrint('[STARTUP] critical complete');

    final onboardingCompleted = await onboardingCompletedFuture;

    if (!mounted) {
      return;
    }

    setState(() {
      _isOnboardingReady = true;
      _shouldShowOnboarding = !onboardingCompleted;
    });

    unawaited(
      _runPostRenderStartup(
        pendingCollectedRows: criticalResult.pendingCollectedRows,
      ),
    );

    unawaited(
      _startupCoordinator.runDeferred(
        loadDisplayName: _loadDisplayName,
        loadMyEventRank: _loadMyEventRank,
        loadLevelProgress: _loadLevelProgress,
      ),
    );

    // 全画面広告の事前ロードは地図初期化と競合させない。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          InterstitialAdService.instance.preload();
        }
      });
    });

    if (onboardingCompleted) {
      await _initializeLocation();
    }
  }

  Future<void> _runPostRenderStartup({
    required List<Map<String, dynamic>> pendingCollectedRows,
  }) async {
    try {
      appDebugPrint('[STARTUP] post-render start');
      await _startupCoordinator.runPostRender(
        pendingCollectedRows: pendingCollectedRows,
        loadEventAchievements: _loadEventAchievements,
        applyCollectedRows: _applyCollectedRows,
        mergeCloudCollectionHistory: _mergeCloudCollectionHistory,
        loadManualNextDestination: _loadManualNextDestination,
        loadRecommendedRoute: _loadRecommendedRoute,
        restoreRecommendedRouteDestination: () {
          if (_activeRecommendedRoute.isNotEmpty) {
            _manualNextSeichiId = _activeRecommendedRoute.first.id;
          }
        },
      );

      if (!mounted) {
        return;
      }

      _updateNextDestination();
      appDebugPrint('[STARTUP] post-render complete');
    } catch (error) {
      appDebugPrint('[STARTUP] post-render failed: $error');
    }
  }

  Future<void> _showOnboardingFromSettings() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (tutorialContext) {
          return OnboardingPage(
            onComplete: () async {
              if (tutorialContext.mounted) {
                Navigator.of(tutorialContext).pop();
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    await _onboardingService.markCompleted();

    if (!mounted) {
      return;
    }

    setState(() {
      _shouldShowOnboarding = false;
    });

    await _initializeLocation();
  }

  Future<void> _loadLevelProgress() async {
    try {
      final levelProgress = await _progressionService.loadLevelProgress();

      if (!mounted) {
        return;
      }

      final currentLevelProgress = _levelProgress;
      final levelProgressChanged =
          currentLevelProgress == null ||
          currentLevelProgress.totalXp != levelProgress.totalXp ||
          currentLevelProgress.level != levelProgress.level ||
          currentLevelProgress.currentLevelXp != levelProgress.currentLevelXp ||
          currentLevelProgress.nextLevelXp != levelProgress.nextLevelXp ||
          currentLevelProgress.xpIntoLevel != levelProgress.xpIntoLevel ||
          currentLevelProgress.xpNeededForNextLevel !=
              levelProgress.xpNeededForNextLevel ||
          currentLevelProgress.progress != levelProgress.progress;

      if (levelProgressChanged) {
        setState(() {
          _levelProgress = levelProgress;
        });
      }

      appDebugPrint(
        '[LEVEL] '
        'xp=${levelProgress.totalXp} '
        'level=${levelProgress.level}',
      );
    } catch (error) {
      appDebugPrint('[LEVEL] load failed: $error');
    }
  }

  Future<void> _loadDisplayName() async {
    try {
      final profile = await _profileService.loadCurrentProfile();

      if (!mounted) {
        return;
      }

      final nextDisplayName = profile?.displayName;
      final nextAvatarKey = profile?.avatarKey;

      if (_displayName != nextDisplayName || _avatarKey != nextAvatarKey) {
        setState(() {
          _displayName = nextDisplayName;
          _avatarKey = nextAvatarKey;
        });
      }
    } catch (error) {
      appDebugPrint('[PROFILE] display name load failed: $error');
    }
  }

  Future<void> _ensureCloudUser() async {
    await _sessionService.ensureCloudUser();
  }

  Future<void> _loadMyEventRank() async {
    final eventId = _currentEventId;

    if (eventId == null || eventId.isEmpty) {
      if (mounted && _myEventRank != null) {
        setState(() {
          _myEventRank = null;
        });
      }
      return;
    }

    try {
      final rank = await _progressionService.loadMyEventRank(eventId);

      if (!mounted) {
        return;
      }

      if (_myEventRank != rank) {
        setState(() {
          _myEventRank = rank;
        });
      }
    } catch (error) {
      appDebugPrint('[RANK] load failed: $error');

      if (!mounted) {
        return;
      }

      if (_myEventRank != null) {
        setState(() {
          _myEventRank = null;
        });
      }
    }
  }

  Future<void> _resetCurrentEventCollectionHistory() async {
    final eventId = _currentEventId;

    if (eventId == null || eventId.isEmpty) {
      throw Exception('現在のイベントIDが取得できません。');
    }

    await _historyService.resetEventCollectionHistory(eventId: eventId);

    if (!mounted) {
      return;
    }

    setState(() {
      _collectedIds.clear();
      _markerCacheRevision.markChanged();
      _manualNextSeichiId = null;
      _activeRecommendedRoute.clear();
    });

    await _saveManualNextDestination();
    await _saveRecommendedRoute();
    await _saveStamps();
    await _loadCollectionEventNames();

    _updateNextDestination();
    await _checkStampDistance();
    await _loadMyEventRank();
  }

  Future<CollectionSyncStartResult> _startCollectionSync() async {
    final eventId = _currentEventId;
    final userId = _sessionService.currentUserId;

    if (eventId == null || eventId.isEmpty) {
      throw Exception('イベントIDが未取得のため、獲得履歴を同期できません。');
    }

    if (userId == null) {
      throw Exception('ユーザーIDが未取得のため、獲得履歴を同期できません。');
    }

    final result = await _collectionSyncService.start(
      userId: userId,
      eventId: eventId,
    );

    final localCollectedIdsChanged = !haveSameStringValues(
      _collectedIds,
      result.localCollectedIds,
    );

    if (localCollectedIdsChanged) {
      _collectedIds
        ..clear()
        ..addAll(result.localCollectedIds);
      _markerCacheRevision.markChanged();
    }

    return result;
  }

  Future<void> _mergeCloudCollectionHistory() async {
    final eventId = _currentEventId;
    final userId = _sessionService.currentUserId;

    if (eventId == null || eventId.isEmpty || userId == null) {
      return;
    }

    final mergedIds = await _collectionSyncService.mergeCloudHistory(
      userId: userId,
      eventId: eventId,
      collectedIds: _collectedIds,
    );

    if (!haveSameStringValues(_collectedIds, mergedIds)) {
      _collectedIds
        ..clear()
        ..addAll(mergedIds);
      _markerCacheRevision.markChanged();
    }

    await _loadCollectionEventNames();
  }

  Future<void> _loadCollectionEventNames() async {
    try {
      final history = await _historyService.loadCollectionDisplayHistory();

      final next = _collectionDisplayPolicy.eventNamesByContentKey(history);

      _collectionEventNamesByContentKey
        ..clear()
        ..addAll(next);
    } catch (_) {
      // 表示用履歴の取得失敗時は、既に保持している情報を維持する。
    }
  }

  // ============================================================
  // 保存済みスタンプ
  // ============================================================

  Future<void> _saveManualNextDestination() async {
    final eventId = _currentEventId;
    final userId = _sessionService.currentUserId;

    if (eventId == null || eventId.isEmpty || userId == null) {
      return;
    }

    final seichiId = _manualNextSeichiId;

    await _destinationPersistenceService.saveManualDestination(
      userId: userId,
      eventId: eventId,
      seichiId: seichiId,
    );

    if (seichiId == null || seichiId.isEmpty) {
      appDebugPrint('[NEXT-PERSIST] cleared: event=$eventId');
      return;
    }

    appDebugPrint('[NEXT-PERSIST] saved: event=$eventId seichi=$seichiId');
  }

  Future<void> _loadManualNextDestination() async {
    final eventId = _currentEventId;
    final userId = _sessionService.currentUserId;

    if (eventId == null || eventId.isEmpty || userId == null) {
      _manualNextSeichiId = null;
      return;
    }

    final savedId = await _destinationPersistenceService.loadManualDestination(
      userId: userId,
      eventId: eventId,
    );

    if (savedId == null || savedId.isEmpty) {
      _manualNextSeichiId = null;
      return;
    }

    final isValid = _seichiList.any(
      (seichi) => seichi.id == savedId && !_collectedIds.contains(seichi.id),
    );

    if (!isValid) {
      _manualNextSeichiId = null;

      await _destinationPersistenceService.clearManualDestination(
        userId: userId,
        eventId: eventId,
      );

      appDebugPrint(
        '[NEXT-PERSIST] invalid saved destination removed: '
        'event=$eventId seichi=$savedId',
      );
      return;
    }

    _manualNextSeichiId = savedId;

    appDebugPrint('[NEXT-PERSIST] restored: event=$eventId seichi=$savedId');
  }

  Future<void> _saveRecommendedRoute() async {
    final eventId = _currentEventId;
    final userId = _sessionService.currentUserId;

    if (eventId == null || eventId.isEmpty || userId == null) {
      return;
    }

    final routeIds = _activeRecommendedRoute
        .where((seichi) => !_collectedIds.contains(seichi.id))
        .map((seichi) => seichi.id)
        .toList(growable: false);

    await _destinationPersistenceService.saveRecommendedRoute(
      userId: userId,
      eventId: eventId,
      seichiIds: routeIds,
    );

    if (routeIds.isEmpty) {
      appDebugPrint('[ROUTE-PERSIST] cleared: event=$eventId');
      return;
    }

    appDebugPrint('[ROUTE-PERSIST] saved: event=$eventId ids=$routeIds');
  }

  void _saveRecommendedRouteInBackground() {
    _saveRecommendedRoute().catchError((Object error) {
      appDebugPrint('[ROUTE-PERSIST] save failed: $error');
    });
  }

  Future<void> _loadRecommendedRoute() async {
    final eventId = _currentEventId;
    final userId = _sessionService.currentUserId;

    _isRecommendedRouteLoaded = false;
    _activeRecommendedRoute.clear();

    if (eventId == null || eventId.isEmpty || userId == null) {
      return;
    }

    final savedIds = await _destinationPersistenceService.loadRecommendedRoute(
      userId: userId,
      eventId: eventId,
    );

    if (savedIds == null || savedIds.isEmpty) {
      _isRecommendedRouteLoaded = true;
      return;
    }

    final seichiById = <String, QuestItem>{
      for (final seichi in _seichiList) seichi.id: seichi,
    };

    final restoredRoute = <QuestItem>[];

    for (final id in savedIds) {
      final seichi = seichiById[id];

      if (seichi == null || _collectedIds.contains(id)) {
        continue;
      }

      restoredRoute.add(seichi);
    }

    if (restoredRoute.isEmpty) {
      await _destinationPersistenceService.clearRecommendedRoute(
        userId: userId,
        eventId: eventId,
      );

      appDebugPrint(
        '[ROUTE-PERSIST] invalid or completed route removed: '
        'event=$eventId',
      );
      _isRecommendedRouteLoaded = true;
      return;
    }

    _activeRecommendedRoute.addAll(restoredRoute);

    if (restoredRoute.length != savedIds.length) {
      await _destinationPersistenceService.saveRecommendedRoute(
        userId: userId,
        eventId: eventId,
        seichiIds: restoredRoute.map((item) => item.id).toList(growable: false),
      );
    }

    _isRecommendedRouteLoaded = true;

    if (kDebugMode) {
      appDebugPrint(
        '[ROUTE-PERSIST] loaded: '
        'event=$eventId '
        'ids=${_activeRecommendedRoute.map((item) => item.id).toList()}',
      );
    }
  }

  Future<void> _saveStamps() async {
    if (_currentEventId == null || _currentEventId!.isEmpty) {
      throw Exception('イベントIDが未取得のため、獲得スタンプを保存できません。');
    }

    final userId = _sessionService.currentUserId;

    if (userId == null) {
      throw Exception('ユーザーIDが未取得のため、獲得スタンプを保存できません。');
    }

    await _stampCacheService.save(
      userId: userId,
      eventId: _currentEventId!,
      collectedIds: _collectedIds,
    );
  }

  // ============================================================
  // アプリ設定
  // ============================================================

  Future<bool> _isAutoNextDestinationEnabled() {
    return _appSettingsService.isAutoNextDestinationEnabled();
  }

  // ============================================================
  // 有効な獲得数
  // ============================================================

  int _getCollectedCount() {
    return _collectionProgressPolicy.validCollectedCount(
      seichiList: _seichiList,
      collectedIds: _collectedIds,
    );
  }

  // ============================================================
  // Supabaseから聖地取得
  // ============================================================

  Future<void> _loadSeichi({bool manageLoadingState = true}) async {
    try {
      if (mounted && manageLoadingState) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _errorActionLabel = null;
          _errorAction = null;
        });
      }

      final eventId = _currentEventId;

      if (eventId == null || eventId.isEmpty) {
        throw Exception('イベントIDが未取得のため、聖地を読み込めません。');
      }

      final list = await _questItemService.loadActiveItems(eventId);

      if (!mounted) {
        return;
      }

      setState(() {
        _seichiList = list;
        _markerCacheRevision.markChanged();
        if (manageLoadingState) {
          _isLoading = false;
        }
      });

      // 自動次目的地設定がONの場合のみ更新する。
      if (await _isAutoNextDestinationEnabled()) {
        _updateNextDestination();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '聖地データを取得できませんでした。\n$e';
        _errorActionLabel = null;
        _errorAction = null;
        if (manageLoadingState) {
          _isLoading = false;
        }
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

    final result = await _locationService.getInitialPosition();

    if (!mounted) {
      return;
    }

    final position = result.position;

    if (position == null) {
      switch (result.failure) {
        case LocationStartFailure.serviceDisabled:
          setState(() {
            _isLoadingLocation = false;
            _errorMessage =
                '位置情報サービスがOFFになっています。\n'
                '端末の位置情報をONにしてください。';
            _errorActionLabel = '位置情報設定を開く';
            _errorAction = () async {
              await _locationService.openLocationSettings();
            };
          });
        case LocationStartFailure.permissionDenied:
          setState(() {
            _isLoadingLocation = false;
            _errorMessage = '位置情報の利用が許可されていません。';
            _errorActionLabel = '再試行';
            _errorAction = _initializeLocation;
          });
        case LocationStartFailure.permissionDeniedForever:
          setState(() {
            _isLoadingLocation = false;
            _errorMessage =
                '位置情報の利用が永久に拒否されています。\n'
                '端末の設定から位置情報を許可してください。';
            _errorActionLabel = 'アプリ設定を開く';
            _errorAction = () async {
              await _locationService.openAppSettings();
            };
          });
        case LocationStartFailure.unavailable:
        case null:
          setState(() {
            _isLoadingLocation = false;
            _errorMessage =
                '現在地を取得できませんでした。\n'
                '${result.error ?? '不明なエラー'}';
            _errorActionLabel = '再試行';
            _errorAction = _initializeLocation;
          });
      }

      return;
    }

    setState(() {
      _currentPosition = position;
      _isLoadingLocation = false;
      _hasVeryLowLocationAccuracy = position.accuracy > 500.0;
      _isLowAccuracyWarningDismissed = false;
      _errorMessage = null;
      _errorActionLabel = null;
      _errorAction = null;
    });

    _updateNextDestination();

    // 天気APIは現在地表示・GPS監視開始の必須条件ではない。
    // 先に地図と位置ストリームを使える状態にし、通信はバックグラウンドで行う。
    await _moveCameraToCurrentLocation();
    _startLocationStream();
    unawaited(_updateWeatherIfNeeded(position, force: true));
  }

  // ============================================================
  // 現在地監視
  // ============================================================

  Future<void> _updateWeatherIfNeeded(
    Position position, {
    bool force = false,
  }) async {
    if (_isWeatherFetchInProgress) {
      return;
    }

    final shouldFetch = _weatherRefreshPolicy.shouldFetch(
      force: force,
      now: DateTime.now(),
      lastFetchAt: _lastWeatherFetchAt,
      lastPosition: _lastWeatherFetchPosition,
      currentPosition: position,
      distanceBetween: (from, to) => _locationService.distanceBetween(
        startLatitude: from.latitude,
        startLongitude: from.longitude,
        endLatitude: to.latitude,
        endLongitude: to.longitude,
      ),
    );

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

    _positionSubscription = _locationService.getPositionStream().listen(
      (position) {
        if (!mounted) {
          return;
        }

        final hasVeryLowLocationAccuracy = position.accuracy > 500.0;
        final accuracyStateChanged =
            _hasVeryLowLocationAccuracy != hasVeryLowLocationAccuracy;

        if (accuracyStateChanged) {
          setState(() {
            _currentPosition = position;
            _hasVeryLowLocationAccuracy = hasVeryLowLocationAccuracy;

            if (!hasVeryLowLocationAccuracy) {
              _isLowAccuracyWarningDismissed = false;
            }
          });
        } else {
          _currentPosition = position;
        }

        _updateNextDestination();
        _updateWeatherIfNeeded(position);
        _checkStampDistance();
      },
      onError: (error) {
        _positionSubscription = null;

        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage = '位置情報の監視でエラーが発生しました。\n$error';
          _errorActionLabel = '再試行';
          _errorAction = _initializeLocation;
        });
      },
    );
  }

  // ============================================================
  // 最寄りの未獲得聖地
  // ============================================================

  void _updateNextDestination() {
    if (kDebugMode) {
      appDebugPrint(
        '[ROUTE-NEXT] UPDATE START '
        'manual=$_manualNextSeichiId '
        'active=${_activeRecommendedRoute.map((item) => '${item.contentKey}:${item.id}').toList()} '
        'collected=${_collectedIds.length}',
      );
    }

    final result = _nextDestinationService.findNextDestination(
      position: _currentPosition,
      seichiList: _seichiList,
      collectedIds: _collectedIds,
      manualNextSeichiId: _manualNextSeichiId,
    );

    if (kDebugMode) {
      appDebugPrint(
        '[ROUTE-NEXT] SERVICE RESULT '
        'next=${result.seichi == null ? null : '${result.seichi!.contentKey}:${result.seichi!.name}:${result.seichi!.id}'} '
        'distance=${result.distance}',
      );
    }

    if (result.seichi == null && _manualNextSeichiId != null) {
      _manualNextSeichiId = null;
    }

    if (!mounted) {
      return;
    }

    final nextChanged =
        _nextSeichi?.id != result.seichi?.id ||
        _nextDistance != result.distance;

    if (nextChanged) {
      setState(() {
        _nextSeichi = result.seichi;
        _nextDistance = result.distance;
      });
    }

    _syncMarkerAnimation();

    if (kDebugMode) {
      appDebugPrint(
        '[ROUTE-NEXT] UPDATE END '
        'next=${_nextSeichi == null ? null : '${_nextSeichi!.contentKey}:${_nextSeichi!.name}:${_nextSeichi!.id}'} '
        'manual=$_manualNextSeichiId '
        'distance=$_nextDistance',
      );
    }
  }

  Future<void> _setNextDestination(QuestItem seichi) async {
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

    QuestSnackBar.show(
      context,
      message: '${seichi.name} を次の目的地に設定しました。',
      type: QuestNoticeType.success,
    );
  }

  Future<void> _testRecommendedRouteNext() async {
    if (_activeRecommendedRoute.isEmpty) {
      if (!mounted) {
        return;
      }

      QuestSnackBar.show(
        context,
        message: 'テストできる巡回ルートが開始されていません。',
        type: QuestNoticeType.warning,
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

      QuestSnackBar.show(
        context,
        message:
            'テスト: ${previousSeichi.name} の次で巡回ルート終了です。',
        type: QuestNoticeType.info,
      );
      return;
    }

    final nextSeichi = _activeRecommendedRoute.first;
    _manualNextSeichiId = nextSeichi.id;
    _updateNextDestination();

    if (!mounted) {
      return;
    }

    QuestSnackBar.show(
      context,
      message:
          'テスト: ${previousSeichi.name} → '
          '${nextSeichi.name}',
      type: QuestNoticeType.info,
    );
  }

  void _startRecommendedRoute(List<QuestItem> route) {
    if (route.isEmpty) {
      return;
    }

    final routeState = RecommendedRoutePolicy.start(
      route: route,
      collectedIds: _collectedIds,
    );

    if (routeState.route.isEmpty) {
      return;
    }

    final firstSeichi = routeState.route.first;

    _activeRecommendedRoute
      ..clear()
      ..addAll(routeState.route);

    _manualNextSeichiId = routeState.manualNextSeichiId;
    _updateNextDestination();

    _saveRecommendedRouteInBackground();

    _moveCameraToSeichi(firstSeichi);

    QuestSnackBar.show(
      context,
      message:
          '巡回ルートを開始しました。最初の目的地は '
          '${firstSeichi.name} です。',
      type: QuestNoticeType.success,
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
    final previousPosition = _lastStampCheckPosition;

    if (previousPosition != null) {
      final elapsedSeconds =
          position.timestamp
              .difference(previousPosition.timestamp)
              .inMilliseconds /
          1000.0;

      if (elapsedSeconds > 0) {
        final movedDistance = _locationService.distanceBetween(
          startLatitude: previousPosition.latitude,
          startLongitude: previousPosition.longitude,
          endLatitude: position.latitude,
          endLongitude: position.longitude,
        );

        if (!StampEligibilityPolicy.isPlausibleMovement(
          movedDistanceMeters: movedDistance,
          elapsedSeconds: elapsedSeconds,
        )) {
          return;
        }
      }
    }

    _lastStampCheckPosition = position;
    if (kDebugMode) {
      appDebugPrint(
        '[STAMP_GPS] '
        'lat=${position.latitude}, '
        'lon=${position.longitude}, '
        'accuracy=${position.accuracy}m, '
        'timestamp=${position.timestamp}, '
        'seichiCount=${_seichiList.length}',
      );
    }

    QuestItem? nearestSeichi;
    double nearestDistance = double.infinity;
    QuestItem? collectibleSeichi;

    for (final seichi in _seichiList) {
      if (_collectedIds.contains(seichi.id)) {
        continue;
      }

      final distance = _locationService.distanceBetween(
        startLatitude: position.latitude,
        startLongitude: position.longitude,
        endLatitude: seichi.latitude,
        endLongitude: seichi.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestSeichi = seichi;
      }

      if (collectibleSeichi == null &&
          StampEligibilityPolicy.hasSufficientAccuracy(
            accuracyMeters: position.accuracy,
            stampRadiusMeters: seichi.stampRadiusMeters,
          ) &&
          StampEligibilityPolicy.isWithinStampRadius(
            distanceMeters: distance,
            stampRadiusMeters: seichi.stampRadiusMeters,
          )) {
        collectibleSeichi = seichi;
      }
    }

    if (kDebugMode && nearestSeichi != null) {
      appDebugPrint(
        '[STAMP_DISTANCE] '
        'name=${nearestSeichi.name}, '
        'contentKey=${nearestSeichi.contentKey}, '
        'distance=${nearestDistance.toStringAsFixed(1)}m, '
        'radius=${nearestSeichi.stampRadiusMeters}m, '
        'accuracy=${position.accuracy}m',
      );
    }

    if (collectibleSeichi != null) {
      await _collectStamp(collectibleSeichi);
    }
  }

  // ============================================================
  // スタンプ獲得
  // ============================================================

  Future<void> _collectStamp(QuestItem seichi) async {
    if (_isCollecting || _collectedIds.contains(seichi.id)) {
      return;
    }

    appDebugPrint(
      '[STAMP_COLLECT] name=${seichi.name}, contentKey=${seichi.contentKey}, id=${seichi.id}',
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

    final applyPlan = _collectionApplyPolicy.plan(
      currentEventId: currentEventId,
      collectedRows: collectedRows,
      seichiList: _seichiList,
      collectedIds: _collectedIds,
      eventAchievements: _eventAchievements,
    );

    final newlyCollectedSeichi = applyPlan.newlyCollectedSeichi;

    if (newlyCollectedSeichi.isEmpty) {
      return;
    }

    InterstitialAdService.instance.markStampCollected();

    _collectedIds
      ..clear()
      ..addAll(applyPlan.newCollectedIds);
    _markerCacheRevision.markChanged();

    if (kDebugMode) {
      appDebugPrint(
        '[ROUTE-NEXT] COLLECTED '
        'new=${newlyCollectedSeichi.map((item) => '${item.contentKey}:${item.name}:${item.id}').toList()} '
        'activeBefore=${_activeRecommendedRoute.map((item) => '${item.contentKey}:${item.id}').toList()} '
        'manualBefore=$_manualNextSeichiId',
      );
    }

    final routeState = RecommendedRoutePolicy.advanceAfterCollection(
      activeRoute: _activeRecommendedRoute,
      manualNextSeichiId: _manualNextSeichiId,
      collectedIds: _collectedIds,
      newlyCollectedIds: newlyCollectedSeichi.map((item) => item.id).toSet(),
    );

    _activeRecommendedRoute
      ..clear()
      ..addAll(routeState.route);
    _manualNextSeichiId = routeState.manualNextSeichiId;

    if (kDebugMode) {
      appDebugPrint(
        '[ROUTE-NEXT] AFTER ROUTE ADVANCE '
        'active=${_activeRecommendedRoute.map((item) => '${item.contentKey}:${item.id}').toList()} '
        'manual=$_manualNextSeichiId',
      );
    }

    await _saveManualNextDestination();
    if (_isRecommendedRouteLoaded) {
      await _saveRecommendedRoute();
    } else {
      appDebugPrint('[ROUTE-PERSIST] save skipped: route state not loaded yet');
    }
    await _saveStamps();

    final previousLevel = _levelProgress?.level;

    await _secondaryRefreshCoordinator.refreshAfterCollection(
      loadCollectionEventNames: _loadCollectionEventNames,
      loadMyEventRank: _loadMyEventRank,
      loadLevelProgress: _loadLevelProgress,
    );

    final newLevel = _levelProgress?.level;

    final didLevelUp =
        showLevelUp &&
        previousLevel != null &&
        newLevel != null &&
        newLevel > previousLevel;

    final didCompleteQuest = applyPlan.didCompleteQuest;
    final newlyUnlockedAchievements = applyPlan.newlyUnlockedAchievements;

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
        _collectedName = '${item.name}を獲得！';
      });

      if (await _appSettingsService.isStampNotificationEnabled()) {
        try {
          final notificationGranted = await NotificationService.instance
              .requestPermission();

          if (notificationGranted) {
            await NotificationService.instance.showStampCollected(
              seichiName: item.name,
            );
          }
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
        return QuestDialog(
          icon: Icons.auto_awesome_rounded,
          title: 'LEVEL UP!',
          subtitle: '新しいレベルに到達しました',
          actionLabel: '冒険を続ける',
          actionIcon: Icons.explore_rounded,
          onAction: () {
            Navigator.of(dialogContext).pop();
          },
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: QuestUiTokens.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: QuestUiTokens.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Lv.$previousLevel  →  Lv.$newLevel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: QuestUiTokens.primaryDeep,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    '累計 ${progress.totalXp} XP',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: QuestUiTokens.mutedInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  Future<void> _showAchievementUnlockDialog(Achievement achievement) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return QuestDialog(
          iconText: achievement.icon,
          title: '実績解除！',
          subtitle: achievement.title,
          actionLabel: 'OK',
          actionIcon: Icons.check_rounded,
          onAction: () {
            Navigator.of(dialogContext).pop();
          },
          content: Text(
            achievement.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 14,
              height: 1.55,
            ),
          ),
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
        return QuestDialog(
          icon: Icons.emoji_events_rounded,
          accentColor: Colors.amber.shade700,
          title: 'QUEST COMPLETE',
          subtitle: eventName != null && eventName.isNotEmpty
              ? eventName
              : 'すべてのスポットを制覇しました',
          actionLabel: 'コンプリート！',
          actionIcon: Icons.check_circle_outline_rounded,
          onAction: () {
            Navigator.of(dialogContext).pop();
          },
          content: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: QuestUiTokens.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: QuestUiTokens.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$totalCount / $totalCount',
                      style: const TextStyle(
                        color: QuestUiTokens.primaryDeep,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '全スポット制覇！',
                      style: TextStyle(
                        color: QuestUiTokens.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'すべてのスポットを巡り、スタンプを集めました。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: QuestUiTokens.mutedInk,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
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
      final launched = await _externalNavigationService.openDirections(
        latitude: seichi.latitude,
        longitude: seichi.longitude,
      );

      if (launched || !mounted) {
        return;
      }

      QuestSnackBar.show(
        context,
        message: 'ナビを起動できませんでした。',
        type: QuestNoticeType.error,
      );
    } catch (error) {
      appDebugPrint('[NAVIGATION] launch failed: $error');

      if (!mounted) {
        return;
      }

      QuestSnackBar.show(
        context,
        message: 'ナビを起動できませんでした。',
        type: QuestNoticeType.error,
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

  Future<void> _moveCameraToSeichi(QuestItem seichi) async {
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
      _syncMarkerAnimation();

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
    final nextId = _nextSeichi?.id;

    // 静止Markerの再構築要否は、毎buildで全IDをソート・連結せず
    // 明示的なデータ世代と参照状態で判定する。
    final shouldRebuildStaticMarkers =
        _staticMarkerCache == null ||
        !_markerCacheRevision.isCurrent(_staticMarkerCacheRevision) ||
        _staticMarkerCacheNextId != nextId ||
        !identical(_staticMarkerCacheUncollectedIcon, _uncollectedMarkerIcon) ||
        !identical(_staticMarkerCacheCollectedIcon, _collectedMarkerIcon);

    if (shouldRebuildStaticMarkers) {
      final staticMarkers = <Marker>{};

      for (final seichi in _seichiList) {
        final collected = _collectedIds.contains(seichi.id);
        final isNext = !collected && seichi.id == nextId;

        // NEXTだけはアニメーションするため静止キャッシュから除外する。
        if (isNext) {
          continue;
        }

        final markerIcon = collected
            ? _collectedMarkerIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  )
            : _uncollectedMarkerIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  );

        staticMarkers.add(
          Marker(
            markerId: MarkerId(seichi.id),
            position: LatLng(seichi.latitude, seichi.longitude),
            icon: markerIcon,
            alpha: 0.78,
            anchor: const Offset(0.5, 0.94),
            zIndexInt: 1,
            infoWindow: InfoWindow(
              title: '${seichi.icon} ${seichi.name}',
              snippet: collected
                  ? '🏆 スタンプ獲得済み'
                  : '到達半径 ${seichi.stampRadiusMeters}m',
            ),
            onTap: () {
              _showSeichiDetails(seichi);
            },
          ),
        );
      }

      _staticMarkerCache = staticMarkers;
      _staticMarkerCacheRevision = _markerCacheRevision.value;
      _staticMarkerCacheNextId = nextId;
      _staticMarkerCacheUncollectedIcon = _uncollectedMarkerIcon;
      _staticMarkerCacheCollectedIcon = _collectedMarkerIcon;
    }

    final markers = <Marker>{...?_staticMarkerCache};

    final nextSeichi = _nextSeichi;

    if (nextSeichi != null && !_collectedIds.contains(nextSeichi.id)) {
      final animationValue = _sonarController.value;
      final wave = math.sin(animationValue * math.pi * 2);
      final nextAnchorY = 0.94 + (wave * 0.035);

      markers.add(
        Marker(
          markerId: MarkerId(nextSeichi.id),
          position: LatLng(nextSeichi.latitude, nextSeichi.longitude),
          icon:
              _nextMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          alpha: 0.90,
          anchor: Offset(0.5, nextAnchorY),
          zIndexInt: 2,
          infoWindow: InfoWindow(
            title: '${nextSeichi.icon} ${nextSeichi.name}',
            snippet:
                '✨ NEXT ・ 到達半径 ${nextSeichi.stampRadiusMeters}m',
          ),
          onTap: () {
            _showSeichiDetails(nextSeichi);
          },
        ),
      );
    }

    return markers;
  }

  // ============================================================
  // 聖地詳細
  // ============================================================

  void _showSeichiDetails(QuestItem seichi) {
    final position = _currentPosition;
    final contentId = seichi.contentId.trim();

    final Future<List<ContentBlock>>? contentBlocksFuture = contentId.isEmpty
        ? null
        : _contentBlockService.loadForContent(contentId);

    double? distance;

    if (position != null) {
      distance = _locationService.distanceBetween(
        startLatitude: position.latitude,
        startLongitude: position.longitude,
        endLatitude: seichi.latitude,
        endLongitude: seichi.longitude,
      );
    }

    final collected = _collectedIds.contains(seichi.id);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.98),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            border: Border.all(
                              color: colorScheme.primary.withValues(
                                alpha: 0.20,
                              ),
                            ),
                          ),
                          child: Text(
                            seichi.icon,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                seichi.name,
                                style: const TextStyle(
                                  color: QuestUiTokens.ink,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        QuestStatusChip(
                          label: collected ? '獲得済み' : '未獲得',
                          icon: collected
                              ? Icons.verified_rounded
                              : Icons.lock_outline_rounded,
                          accentColor: collected
                              ? const Color(0xFF2BAA76)
                              : QuestUiTokens.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder(
                      future: contentBlocksFuture,
                      builder: (context, snapshot) {
                        final presentation = _contentBlockPresentationPolicy
                            .resolve(snapshot.data ?? const []);

                        if (snapshot.hasError) {
                          appDebugPrint(
                            '[CONTENT_BLOCKS] detail load failed: '
                            '${snapshot.error}',
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (presentation.showLegacyDescription)
                              QuestGlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (presentation.showLegacyDescription)
                                      Text(
                                        seichi.description.isEmpty
                                            ? '説明は登録されていません。'
                                            : seichi.description,
                                        style: const TextStyle(
                                          color: QuestUiTokens.ink,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          height: 1.55,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (presentation.blocks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: QuestGlassCard(
                                  child: ContentBlockRenderer(
                                    blocks: presentation.blocks,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    QuestGlassCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                ),
                                child: Icon(
                                  Icons.radar_rounded,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '到達判定',
                                  style: TextStyle(
                                    color: QuestUiTokens.mutedInk,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${seichi.stampRadiusMeters}m',
                                style: const TextStyle(
                                  color: QuestUiTokens.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          if (distance != null) ...[
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.near_me_rounded,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    '現在地から',
                                    style: TextStyle(
                                      color: QuestUiTokens.mutedInk,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDistance(distance),
                                  style: const TextStyle(
                                    color: QuestUiTokens.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    QuestPrimaryButton(
                      label: 'このスポットを地図で見る',
                      icon: Icons.navigation_rounded,
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _moveCameraToSeichi(seichi);
                      },
                    ),
                    if (!collected) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _setNextDestination(seichi);
                          },
                          icon: const Icon(Icons.flag_rounded),
                          label: const Text('次の目的地にする'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            side: BorderSide(
                              color: colorScheme.primary.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                QuestUiTokens.controlRadius,
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
      errorMessage:
          _errorMessage ??
          (_hasVeryLowLocationAccuracy && !_isLowAccuracyWarningDismissed
              ? '位置情報の精度が低くなっています。スタンプ獲得や次の目的地の表示を正確にするため、端末の「正確な位置情報」をONにしてください。'
              : null),
      errorActionLabel: _errorMessage != null
          ? _errorActionLabel
          : (_hasVeryLowLocationAccuracy && !_isLowAccuracyWarningDismissed
                ? 'アプリ設定を開く'
                : null),
      onErrorAction: _errorMessage != null
          ? _errorAction
          : (_hasVeryLowLocationAccuracy && !_isLowAccuracyWarningDismissed
                ? _locationService.openAppSettings
                : null),
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
          if (_errorMessage != null) {
            _errorMessage = null;
            _errorActionLabel = null;
            _errorAction = null;
          } else if (_hasVeryLowLocationAccuracy) {
            _isLowAccuracyWarningDismissed = true;
          }
        });
      },
      isQuestHudCollapsed: _isQuestHudCollapsed,
      onToggleQuestHud: () {
        setState(() {
          _isQuestHudCollapsed = !_isQuestHudCollapsed;
        });
      },
    );
  }
  // ============================================================
  // クエスト画面
  // ============================================================

  Future<void> _showEventExplore({bool favoriteOnly = false}) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => EventExplorePage(
          events: _events,
          currentPosition: _currentPosition,
          initialFavoriteOnly: favoriteOnly,
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

    if (result is QuestItem) {
      await _moveCameraToSeichi(result);
      return;
    }

    if (result is! String || result.isEmpty || result == _currentEventId) {
      return;
    }

    Event? selectedEvent;

    for (final event in _events) {
      if (event.id == result) {
        selectedEvent = event;
        break;
      }
    }

    if (selectedEvent == null) {
      if (mounted) {
        QuestSnackBar.show(
          context,
          message: '選択したクエスト情報を取得できません。',
          type: QuestNoticeType.error,
        );
      }
      return;
    }

    await _selectEvent(selectedEvent);
  }

  Widget _buildQuestPage() {
    return QuestPage(
      nextSeichi: _nextSeichi,
      nextDistance: _nextDistance,
      collectedCount: _getCollectedCount(),
      total: _seichiList.length,
      onShowDestination: _moveCameraToNextSeichi,
      onExploreEvents: _showEventExplore,
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

        await _secondaryRefreshCoordinator.refreshProfileAndRank(
          loadDisplayName: _loadDisplayName,
          loadMyEventRank: _loadMyEventRank,
        );

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
          _errorActionLabel = null;
          _errorAction = null;
        });
      }

      _currentEventId = eventId;
      _currentEventName = eventName;

      _collectedIds.clear();
      _markerCacheRevision.markChanged();
      _eventAchievements.clear();
      _myEventRank = null;
      _manualNextSeichiId = null;
      _activeRecommendedRoute.clear();
      _isRecommendedRouteLoaded = false;

      CollectionSyncStartResult? syncResult;

      await _eventSwitchCoordinator.run(
        loadEventAchievements: _loadEventAchievements,
        startCollectionSync: () async {
          syncResult = await _startCollectionSync();
        },
        loadSeichi: () => _loadSeichi(manageLoadingState: false),
        applyPendingRows: () async {
          final result = syncResult;
          if (result == null) {
            throw StateError('イベント切替同期結果がありません。');
          }
          await _applyCollectedRows(result.pendingCollectedRows);
        },
        mergeCloudHistory: _mergeCloudCollectionHistory,
        loadManualNextDestination: _loadManualNextDestination,
        loadRecommendedRoute: _loadRecommendedRoute,
        loadMyEventRank: _loadMyEventRank,
        activateEvent: () => _eventService.activateEvent(eventId),
      );

      if (_activeRecommendedRoute.isNotEmpty) {
        _manualNextSeichiId = _activeRecommendedRoute.first.id;
      }

      _updateNextDestination();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      appDebugPrint('[EVENT] selected: id=$eventId, name=$eventName');
    } catch (e) {
      appDebugPrint('[EVENT] select error: $e');

      if (mounted) {
        setState(() {
          _errorMessage = 'クエストの切り替えに失敗しました。';
          _errorActionLabel = null;
          _errorAction = null;
          _isLoading = false;
        });
      }

      rethrow;
    }
  }

  Future<void> _showInterstitialAfterSafeScreen({
    required DateTime openedAt,
  }) async {
    if (!mounted) {
      return;
    }

    final screenStay = DateTime.now().difference(openedAt);

    await InterstitialAdService.instance.showIfEligible(screenStay: screenStay);
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
        _syncMarkerAnimation();

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
      onShowRanking: () {
        setState(() {
          _selectedTab = 3;
        });
        _syncMarkerAnimation();
      },
      onShowAchievements: () {
        setState(() {
          _selectedTab = 1;
        });
        _syncMarkerAnimation();
      },
      onShowAdventureLog: () async {
        final openedAt = DateTime.now();

        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AdventureLogPage()));

        await _showInterstitialAfterSafeScreen(openedAt: openedAt);
      },
      onShowSyncStatus: () async {
        final openedAt = DateTime.now();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SyncStatusPage(
              loadPendingCount: _historyService.pendingPlaceVisitCount,
              syncNow: () async {
                final syncResult = await _startCollectionSync();

                await _applyCollectedRows(syncResult.pendingCollectedRows);
                await _mergeCloudCollectionHistory();
                await _loadMyEventRank();

                _updateNextDestination();

                return _historyService.pendingPlaceVisitCount();
              },
            ),
          ),
        );

        await _showInterstitialAfterSafeScreen(openedAt: openedAt);
      },
      onShowProfile: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ProfilePage()));

        await _secondaryRefreshCoordinator.refreshProfileAndRank(
          loadDisplayName: _loadDisplayName,
          loadMyEventRank: _loadMyEventRank,
        );
        _updateNextDestination();
        await _checkStampDistance();
      },
      onShowAccount: () async {
        final accountChanged = await Navigator.of(context)
            .push<bool>(MaterialPageRoute(builder: (_) => const AccountPage()));

        if (accountChanged != true) {
          return;
        }

        CollectionSyncStartResult? syncResult;

        await _accountRefreshCoordinator.run(
          ensureCloudUser: _ensureCloudUser,
          resetDestinationState: () async {
            _manualNextSeichiId = null;
            _activeRecommendedRoute.clear();
            _isRecommendedRouteLoaded = false;
          },
          loadDisplayName: _loadDisplayName,
          loadEventAchievements: _loadEventAchievements,
          startCollectionSync: () async {
            syncResult = await _startCollectionSync();
          },
          applyPendingRows: () async {
            final result = syncResult;
            if (result == null) {
              throw StateError('アカウント更新の同期結果がありません。');
            }
            await _applyCollectedRows(result.pendingCollectedRows);
          },
          mergeCloudHistory: _mergeCloudCollectionHistory,
          loadManualNextDestination: _loadManualNextDestination,
          loadRecommendedRoute: _loadRecommendedRoute,
          loadMyEventRank: _loadMyEventRank,
          finish: () async {
            if (_activeRecommendedRoute.isNotEmpty) {
              _manualNextSeichiId = _activeRecommendedRoute.first.id;
            }
            _updateNextDestination();
          },
        );
      },
      onShowNotifications: () async {
        final openedAt = DateTime.now();

        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
        );

        await _showInterstitialAfterSafeScreen(openedAt: openedAt);
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
              onShowOnboarding: _showOnboardingFromSettings,
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return QuestDialog(
          icon: Icons.explore_rounded,
          title: '聖地クエスト',
          subtitle: 'Version 1.0.0',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: QuestStatusChip(
                  label: _currentEventName?.trim().isNotEmpty == true
                      ? _currentEventName!
                      : '位置情報クエスト',
                  icon: Icons.location_on_outlined,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '地域や作品、文化、店舗などをテーマにしたクエストを選び、'
                '現地のスポットを巡ってコレクションを集める位置情報アプリです。',
                style: TextStyle(
                  color: QuestUiTokens.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            ],
          ),
          actionLabel: '閉じる',
          onAction: () {
            Navigator.of(dialogContext).pop();
          },
          secondaryActionLabel: 'ライセンス',
          onSecondaryAction: () {
            Navigator.of(dialogContext).pop();

            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const QuestLicensePage()),
            );
          },
        );
      },
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
          eventId: _currentEventId,
          seichiList: _seichiList,
          collectedIds: _collectedIds,
          eventNamesByContentKey: _collectionEventNamesByContentKey,
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
    if (_isLoading || !_isOnboardingReady) {
      return Scaffold(body: _buildLoading());
    }

    if (_shouldShowOnboarding) {
      return OnboardingPage(onComplete: _completeOnboarding);
    }

    return Scaffold(
      // Keep page content above the banner/navigation area. This prevents
      // bottom actions from being covered when a banner is displayed.
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
                      _syncMarkerAnimation();
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

  void _syncMarkerAnimation() {
    final shouldAnimate = _nextSeichi != null && _selectedTab == 0;

    if (shouldAnimate) {
      if (!_sonarController.isAnimating) {
        _sonarController.repeat();
      }
      return;
    }

    if (_sonarController.isAnimating) {
      _sonarController.stop();
      _lastMarkerAnimationFrame = -1;
    }
  }

  void _onMarkerAnimationTick() {
    if (!mounted || _nextSeichi == null || _selectedTab != 0) {
      return;
    }

    // NEXTマーカーの「ふわふわ」は残しつつ、
    // Google MapへのMarker更新は約8fpsまでに抑える。
    // ソナー本体はMapPage側のAnimatedBuilderで滑らかに描画される。
    final frame = (_sonarController.value * 14).floor();

    if (frame == _lastMarkerAnimationFrame) {
      return;
    }

    _lastMarkerAnimationFrame = frame;
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
