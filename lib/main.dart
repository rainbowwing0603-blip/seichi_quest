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
import 'widgets/notification_settings_page.dart';
import 'widgets/app_settings_page.dart';
import 'models/seichi.dart';
import 'models/achievement.dart';
import 'models/event.dart';
import 'services/achievement_service.dart';
import 'services/next_destination_service.dart';
import 'services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// ============================================================
// Supabase
// ============================================================

const supabaseUrl = 'https://wxlvhpmolrtcwryaazfb.supabase.co';

const supabasePublishableKey =
    'sb_publishable_F5e3RPpeUzlQG31-yv4FeA_fExmYk3w';

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
  const SeichiQuestApp({
    super.key,
    this.home,
  });

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
  State<SeichiMapPage> createState() =>
      _SeichiMapPageState();
}

class _SeichiMapPageState extends State<SeichiMapPage>
    with SingleTickerProviderStateMixin {
  static const AchievementService _achievementService =
      AchievementService();

  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSubscription;

  Position? _currentPosition;

  // スタンプ判定に使用した直前のGPS位置。
  // GPSの急跳びによる誤獲得を防ぐために使用する。
  Position? _lastStampCheckPosition;

  List<Seichi> _seichiList = [];
  final Set<String> _collectedIds = {};

  SharedPreferences? _preferences;

  final CollectionHistoryService _historyService =
      CollectionHistoryService();
  // 現在表示・獲得対象としているイベント。
  String? _currentEventId;
  String? _currentEventName;
  List<Event> _events = [];
  List<Achievement> _eventAchievements = [];

  bool _isLoading = true;
  bool _isLoadingLocation = false;

  String? _errorMessage;

  Seichi? _nextSeichi;
  double? _nextDistance;

  // ユーザーが「次の目的地にする」で指定した聖地。
  // 未指定時は従来どおり、現在地から最も近い未獲得聖地を自動選択する。
  String? _manualNextSeichiId;

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

  static const LatLng _defaultCenter = LatLng(
    36.3910,
    139.0600,
  );

  // 上毛かるたの札順。
  // Supabase側の登録順に依存せず、スタンプ帳を必ず札順で表示する。
  static const List<String> _jomoKarutaOrder = [
    'あ', 'い', 'う', 'え', 'お', 'か', 'き', 'く',
    'け', 'こ', 'さ', 'し', 'す', 'せ', 'そ', 'た',
    'ち', 'つ', 'て', 'と', 'な', 'に', 'ぬ', 'ね',
    'の', 'は', 'ひ', 'ふ', 'へ', 'ほ', 'ま', 'み',
    'む', 'め', 'も', 'や', 'ゆ', 'よ', 'ら', 'り',
    'る', 'れ', 'ろ', 'わ', 'を',
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
      duration: const Duration(
        milliseconds: 1800,
      ),
    )..repeat();

    _initialize();
  }

  Future<void> _loadCurrentEvent() async {
    try {
      final data = await supabase.Supabase.instance.client
          .from('events')
          .select(
            'id, slug, name, description, is_active, '
            'icon_url, cover_image_url, start_at, end_at, updated_at',
          )
          .eq('is_active', true)
          .order('created_at');

      final events = List<Map<String, dynamic>>.from(data)
          .map(Event.fromMap)
          .toList(growable: false);

      _events = events;

      Event? currentEvent;

      for (final event in events) {
        if (event.slug == 'jomo-karuta-gunma') {
          currentEvent = event;
          break;
        }
      }

      if (currentEvent == null) {
        throw Exception('現在のイベントが見つかりません。');
      }

      _currentEventId = currentEvent.id;
      _currentEventName = currentEvent.name;

      if (_currentEventId == null || _currentEventId!.isEmpty) {
        throw Exception('現在のイベントIDが取得できません。');
      }
    } catch (e) {
      debugPrint('現在のイベント取得エラー: $e');
      rethrow;
    }
  }
Future<void> _loadEventAchievements() async {
    if (_currentEventId == null ||
        _currentEventId!.isEmpty) {
      throw Exception(
        'イベントIDが未取得のため、チャレンジを読み込めません。',
      );
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

    final rows =
        List<Map<String, dynamic>>.from(data);

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

      final requiredCount =
          raw['required_count'] is int
              ? raw['required_count'] as int
              : int.tryParse(
                    raw['required_count']?.toString() ?? '',
                  ) ??
                  0;

      achievements.add(
        Achievement(
          id: id,
          title: raw['title']?.toString() ?? '',
          description:
              raw['description']?.toString() ?? '',
          icon: raw['icon']?.toString() ?? '',
          requiredCount: requiredCount,
        ),
      );
    }

    _eventAchievements = achievements;
  }

Future<void> _initialize() async {
    await _ensureCloudUser();
    await _loadCurrentEvent();
    await _loadEventAchievements();
    await _loadSavedStamps();
    await _historyService.syncPending();
    await _loadCloudHistory();
    await _loadSeichi();
    await _initializeLocation();
  }

  Future<void> _ensureCloudUser() async {
    final client = supabase.Supabase.instance.client;

    final existingUser = client.auth.currentUser;

    if (existingUser != null) {
      debugPrint(
        '[AUTH] existing user: ${existingUser.id}, '
        'anonymous=${existingUser.isAnonymous}',
      );
      return;
    }

    debugPrint(
      '[AUTH] no current user. Starting anonymous sign-in...',
    );

    try {
      final response = await client.auth.signInAnonymously();
      final user = response.user;

      if (user != null) {
        debugPrint(
          '[AUTH] anonymous sign-in success: ${user.id}, '
          'anonymous=${user.isAnonymous}',
        );
      } else {
        debugPrint('[AUTH] anonymous sign-in returned null user');
      }
    } on supabase.AuthException catch (error) {
      debugPrint(
        '[AUTH] anonymous sign-in failed: '
        'code=${error.statusCode}, message=${error.message}',
      );
    } catch (error) {
      debugPrint('[AUTH] anonymous sign-in failed: $error');
    }
  }
  Future<void> _resetCurrentEventCollectionHistory() async {
    final eventId = _currentEventId;

    if (eventId == null || eventId.isEmpty) {
      throw Exception('現在のイベントIDが取得できません。');
    }

    await _historyService.resetEventCollectionHistory(
      eventId: eventId,
    );

    _collectedIds.clear();
    _manualNextSeichiId = null;

    await _saveStamps();

    _updateNextDestination();
    await _checkStampDistance();

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
  }

  // ============================================================
  // 保存済みスタンプ
  // ============================================================

  Future<void> _loadSavedStamps() async {
    _preferences =
        await SharedPreferences.getInstance();

    if (_currentEventId == null || _currentEventId!.isEmpty) {
      throw Exception('イベントIDが未取得のため、獲得スタンプを読み込めません。');
    }

    final eventKey =
        'collected_seichi_ids_${_currentEventId!}';

    var savedIds =
        _preferences?.getStringList(eventKey);

    // 旧形式の保存データがある場合は、
    // 現在のイベント専用キーへ一度だけ移行する。
    if (savedIds == null) {
      final legacyIds =
          _preferences?.getStringList(
                'collected_seichi_ids',
              );

      if (legacyIds != null) {
        savedIds = legacyIds;

        await _preferences?.setStringList(
          eventKey,
          legacyIds,
        );
      }
    }

    _collectedIds
      ..clear()
      ..addAll(savedIds ?? []);
  }
Future<void> _saveStamps() async {
    if (_currentEventId == null || _currentEventId!.isEmpty) {
      throw Exception('イベントIDが未取得のため、獲得スタンプを保存できません。');
    }

    final eventKey =
        'collected_seichi_ids_${_currentEventId!}';

    await _preferences?.setStringList(
      eventKey,
      _collectedIds.toList(),
    );
  }

  // ============================================================
  // アプリ設定
  // ============================================================

  bool _isAutoNextDestinationEnabled() {
    return _preferences?.getBool(
          'setting_auto_next_destination',
        ) ??
        true;
  }

  // ============================================================
  // 有効な獲得数
  // ============================================================

  int _getCollectedCount() {
    if (_seichiList.isEmpty) {
      return 0;
    }

    final validIds = _seichiList
        .map((seichi) => seichi.id)
        .toSet();

    return _collectedIds
        .where(validIds.contains)
        .length;
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
            'stamp_radius_meters, description, icon, is_active',
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

      list.sort(
        (a, b) {
          final orderCompare =
              _cardOrderIndex(a.card)
                  .compareTo(_cardOrderIndex(b.card));

          if (orderCompare != 0) {
            return orderCompare;
          }

          return a.card.compareTo(b.card);
        },
      );

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
        _errorMessage =
            '聖地データを取得できませんでした。\n$e';
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
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

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

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoadingLocation = false;
          _errorMessage =
              '位置情報の利用が許可されていません。';
        });

        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
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

      final position =
          await Geolocator.getCurrentPosition(
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

      await _moveCameraToCurrentLocation();

      _startLocationStream();

    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLocation = false;
        _errorMessage =
            '現在地を取得できませんでした。\n$e';
      });
    }
  }

  // ============================================================
  // 現在地監視
  // ============================================================

  void _startLocationStream() {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        if (!mounted) {
          return;
        }

        setState(() {
          _currentPosition = position;
        });

        _updateNextDestination();
        _checkStampDistance();
      },
      onError: (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage =
              '位置情報の監視でエラーが発生しました。\n$error';
        });
      },
    );
  }

  // ============================================================
  // 最寄りの未獲得聖地
  // ============================================================

  void _updateNextDestination() {
    final result = const NextDestinationService()
        .findNextDestination(
      position: _currentPosition,
      seichiList: _seichiList,
      collectedIds: _collectedIds,
      manualNextSeichiId: _manualNextSeichiId,
    );

    if (result.seichi == null &&
        _manualNextSeichiId != null) {
      _manualNextSeichiId = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _nextSeichi = result.seichi;
      _nextDistance = result.distance;
    });
  }

  void _setNextDestination(Seichi seichi) {
    if (_collectedIds.contains(seichi.id)) {
      return;
    }

    setState(() {
      _manualNextSeichiId = seichi.id;
      _nextSeichi = seichi;
    });

    _updateNextDestination();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${seichi.card} ${seichi.name} を次の目的地に設定しました。',
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

    if (position == null ||
        _seichiList.isEmpty) {
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
        final movedDistance =
            Geolocator.distanceBetween(
          previousPosition.latitude,
          previousPosition.longitude,
          position.latitude,
          position.longitude,
        );

        final calculatedSpeed =
            movedDistance / elapsedSeconds;

        if (calculatedSpeed > maxPlausibleSpeedMps) {
          return;
        }
      }
    }

    _lastStampCheckPosition = position;
    debugPrint(
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

      final distance =
          Geolocator.distanceBetween(
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
      debugPrint(
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
      final distance =
          Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        seichi.latitude,
        seichi.longitude,
      );

      if (distance <=
          seichi.stampRadiusMeters) {
        await _collectStamp(seichi);
        break;
      }
    }
  }

  // ============================================================
  // スタンプ獲得
  // ============================================================

  Future<void> _collectStamp(
    Seichi seichi,
  ) async {
    if (_isCollecting ||
        _collectedIds.contains(seichi.id)) {
      return;
    }

    debugPrint('[STAMP_COLLECT] name=${seichi.name}, card=${seichi.card}, id=${seichi.id}');
    _isCollecting = true;

    try {
      final previousCollectedCount = _getCollectedCount();

      _collectedIds.add(seichi.id);

      final newCollectedCount = _getCollectedCount();

      if (_manualNextSeichiId == seichi.id) {
        _manualNextSeichiId = null;
      }

      await _saveStamps();
      final previousAchievements =
          _achievementService.getUnlockedAchievements(
        _eventAchievements,
        previousCollectedCount,
      );

      final newAchievements =
          _achievementService.getUnlockedAchievements(
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

      // スタンプ獲得自体はローカル保存を正として即時成立させる。
      // DB同期はオンラインならその場で行い、失敗時は端末キューに残す。
      final position = _currentPosition;
      await _ensureCloudUser();
      await _historyService.recordCollection(
        eventId: _currentEventId!,
        seichiId: seichi.id,
        collectedAt: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _justCollected = true;
        _collectedName = seichi.name;
      });

      // スタンプ獲得通知
      // 設定がONの場合のみ通知する。
      // 通知に失敗してもスタンプ獲得自体は成立済み。
      if (_preferences?.getBool('setting_stamp_notification') ?? true) {
        try {
          await NotificationService.instance.showStampCollected(
            seichiName: seichi.name,
          );
        } catch (_) {
          // 通知失敗時もスタンプ獲得状態は維持する。
        }
      }

      _updateNextDestination();
      for (final achievement in newlyUnlockedAchievements) {
        await _showAchievementUnlockDialog(achievement);
      }

      Future.delayed(
        const Duration(milliseconds: 2800),
        () {
          if (!mounted) {
            return;
          }

          setState(() {
            _justCollected = false;
            _collectedName = null;
          });
        },
      );
    } finally {
      _isCollecting = false;
    }
  }

  // ============================================================
  // カメラを現在地へ
  // ============================================================

  Future<void> _showAchievementUnlockDialog(
  Achievement achievement,
) async {
  if (!mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text(
          '🎉 実績解除！',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              achievement.icon,
              style: const TextStyle(
                fontSize: 56,
              ),
            ),
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
              style: const TextStyle(
                color: Colors.grey,
              ),
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
Future<void> _moveCameraToCurrentLocation() async {
    final position = _currentPosition;

    if (position == null ||
        _mapController == null) {
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            position.latitude,
            position.longitude,
          ),
          zoom: 13.5,
        ),
      ),
    );
  }

  // ============================================================
  // 次の聖地へ
  // ============================================================

  Future<void> _moveCameraToNextSeichi() async {
    final seichi = _nextSeichi;

    if (seichi == null ||
        _mapController == null) {
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            seichi.latitude,
            seichi.longitude,
          ),
          zoom: 16.0,
        ),
      ),
    );
  }

  // ============================================================
  // 特定聖地へ移動
  // ============================================================

  Future<void> _moveCameraToSeichi(
    Seichi seichi,
  ) async {
    if (_mapController == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _selectedTab = 0;
      });
    }

    await Future.delayed(
      const Duration(milliseconds: 100),
    );

    if (_mapController == null) {
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            seichi.latitude,
            seichi.longitude,
          ),
          zoom: 17,
        ),
      ),
    );
  }

  // ============================================================
  // マーカー
  // ============================================================

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final seichi in _seichiList) {
      final collected =
          _collectedIds.contains(seichi.id);

      debugPrint(
        '[MARKER] ${seichi.name} id=${seichi.id} collected=$collected',
      );

      markers.add(
        Marker(
          markerId: MarkerId(seichi.id),
          position: LatLng(
            seichi.latitude,
            seichi.longitude,
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(
            collected
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(
            title:
                '${seichi.icon} ${seichi.card} ${seichi.name}',
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

  void _showSeichiDetails(
    Seichi seichi,
  ) {
    final position = _currentPosition;

    double? distance;

    if (position != null) {
      distance =
          Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        seichi.latitude,
        seichi.longitude,
      );
    }

    final collected =
        _collectedIds.contains(seichi.id);



    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              4,
              24,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        seichi.icon,
                        style:
                            const TextStyle(
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            seichi.card,
                            style: TextStyle(
                              color:
                                  Theme.of(context)
                                      .colorScheme
                                      .primary,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            seichi.name,
                            style:
                                const TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (collected)
                      const Icon(
                        Icons.verified,
                        color: Colors.green,
                        size: 30,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (seichi.reading.isNotEmpty)
                  Text(
                    seichi.reading,
                    style:
                        const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  seichi.description.isEmpty
                      ? '説明は登録されていません。'
                      : seichi.description,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.radar,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '到達判定 ${seichi.stampRadiusMeters}m',
                    ),
                  ],
                ),
                if (distance != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '現在地から ${_formatDistance(distance)}',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _moveCameraToSeichi(
                        seichi,
                      );
                    },
                    icon: const Icon(
                      Icons.navigation,
                    ),
                    label: const Text(
                      'この聖地を地図で見る',
                    ),
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
                      icon: const Icon(
                        Icons.flag_rounded,
                      ),
                      label: const Text(
                        '次の目的地にする',
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
  // 距離表示
  // ============================================================

  String _formatDistance(
    double distance,
  ) {
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
      onMapCreated: (controller) {
        _mapController = controller;

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
    return RankingPage(
      myCount: _getCollectedCount(),
      total: _seichiList.length,
    );
  }
  // ============================================================
  // マイページ
  // ============================================================

  Future<void> _selectEvent(
    Event event,
  ) async {
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
      _manualNextSeichiId = null;

      await _loadEventAchievements();
      await _loadSavedStamps();
      await _loadCloudHistory();
      await _loadSeichi();

      _updateNextDestination();

      if (mounted) {
        setState(() {});
      }

      debugPrint(
        '[EVENT] selected: id=, name=',
      );
    } catch (e) {
      debugPrint(
        '[EVENT] select error: ',
      );

      if (mounted) {
        setState(() {
          _errorMessage =
              'クエストの切り替えに失敗しました。';
        });
      }

      rethrow;
    }
  }
  Future<void> _showEventSelector() async {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('選択できるクエストがありません。'),
        ),
      );
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
            padding: const EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24,
            ),
            children: [
              const Text(
                'クエストを選択',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._events.map(
                (event) {
                  final eventId =
                      event.id;
                  final eventName =
                      event.name;
                  final description =
                      event.description;
                  final isCurrent =
                      eventId == _currentEventId;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(
                      vertical: 4,
                    ),
                    leading: Icon(
                      isCurrent
                          ? Icons.check_circle
                          : Icons.explore_outlined,
                    ),
                    title: Text(eventName),
                    subtitle: description.isEmpty
                        ? null
                        : Text(description),
                    trailing: isCurrent
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();

                      try {
                        await _selectEvent(event);
                      } catch (_) {
                        // _selectEvent() 内でエラー表示済み
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildMyPage() {
    return MyPage(
      count: _getCollectedCount(),
      total: _seichiList.length,
      currentEventName: _currentEventName,
      onSelectEvent: _showEventSelector,
      onShowProfile: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ProfilePage(),
          ),
        );

        _updateNextDestination();
        await _checkStampDistance();
      },
      onShowNotifications: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NotificationSettingsPage(),
          ),
        );
      },
      onShowAbout: _showAbout,
      onShowSettings: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppSettingsPage(
  onResetEventCollectionHistory: _resetCurrentEventCollectionHistory,
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
      applicationName:
          '聖地クエスト',
      applicationVersion:
          '1.0.0',
      applicationLegalese:
          '上毛かるた × 群馬',
      children: const [
        SizedBox(
          height: 12,
        ),
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
      child:
          const Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child:
                  CircularProgressIndicator(),
            ),
            SizedBox(
              height: 20,
            ),
            Text(
              '聖地クエストを起動中…',
              style:
                  TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w600,
              ),
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
  Widget build(
    BuildContext context,
  ) {
    if (_isLoading) {
      return Scaffold(
        body:
            _buildLoading(),
      );
    }

    return Scaffold(
      body:
          _buildCurrentPage(),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) {
              setState(() {
                _selectedTab = index;
              });
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'マップ'),
              NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'クエスト'),
              NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'スタンプ'),
              NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'ランキング'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'マイページ'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription
        ?.cancel();

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
