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
import 'widgets/my_page.dart';
import 'models/seichi.dart';
import 'painters/sonar_painter.dart';
import 'services/next_destination_service.dart';
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
  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSubscription;

  Position? _currentPosition;

  List<Seichi> _seichiList = [];

  final Set<String> _collectedIds = {};

  SharedPreferences? _preferences;

  final CollectionHistoryService _historyService =
      CollectionHistoryService();

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

  Future<void> _initialize() async {
    await _loadSavedStamps();
    await _ensureCloudUser();
    await _historyService.syncPending();
    await _loadCloudHistory();
    await _loadSeichi();
    await _initializeLocation();
  }

  Future<void> _ensureCloudUser() async {
    final client = supabase.Supabase.instance.client;

    if (client.auth.currentUser != null) {
      return;
    }

    try {
      await client.auth.signInAnonymously();
    } catch (_) {
      // オフライン、または匿名認証未有効時はローカル動作を継続する。
    }
  }

  Future<void> _loadCloudHistory() async {
    try {
      final history = await _historyService.loadHistory();
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

    final savedIds =
        _preferences?.getStringList(
              'collected_seichi_ids',
            ) ??
            [];

    _collectedIds
      ..clear()
      ..addAll(savedIds);
  }

  Future<void> _saveStamps() async {
    await _preferences?.setStringList(
      'collected_seichi_ids',
      _collectedIds.toList(),
    );
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
          .eq('is_active', true);

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

      _updateNextDestination();
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

      await _checkStampDistance();
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

    _isCollecting = true;

    try {
      _collectedIds.add(seichi.id);

      if (_manualNextSeichiId == seichi.id) {
        _manualNextSeichiId = null;
      }

      await _saveStamps();

      // スタンプ獲得自体はローカル保存を正として即時成立させる。
      // DB同期はオンラインならその場で行い、失敗時は端末キューに残す。
      final position = _currentPosition;
      await _ensureCloudUser();
      await _historyService.recordCollection(
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

      _updateNextDestination();

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

  double _sonarIntensity() {
    final distance = _nextDistance;

    if (distance == null) {
      return 0.15;
    }

    final radius =
        _nextSeichi?.stampRadiusMeters ?? 200;

    if (distance <= radius) {
      return 1.0;
    }

    final normalized =
        1.0 - (distance / 2000.0);

    return normalized.clamp(
      0.1,
      1.0,
    );
  }

  // ============================================================
  // エラー
  // ============================================================

  Widget _buildErrorCard() {
    if (_errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 95,
      child: Material(
        elevation: 8,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          padding:
              const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style:
                      const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                },
                icon:
                    const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 次の目的地カード
  // ============================================================

  Widget _buildNextDestinationCard() {
    final seichi = _nextSeichi;
    final distance = _nextDistance;

    if (seichi == null) {
      return Positioned(
        top: 14,
        left: 14,
        right: 14,
        child: _buildTopCard(
          child: Row(
            children: [
              const Icon(
                Icons.emoji_events,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getCollectedCount() >=
                          _seichiList.length &&
                      _seichiList.isNotEmpty
                      ? 'すべての聖地を制覇しました！'
                      : '次の聖地を探しています…',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final intensity =
        _sonarIntensity();

    return Positioned(
      top: 14,
      left: 14,
      right: 14,
      child: _buildTopCard(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation:
                      _sonarController,
                  builder:
                      (context, child) {
                    return SizedBox(
                      width: 50,
                      height: 50,
                      child: CustomPaint(
                        painter:
                            SonarPainter(
                          progress:
                              _sonarController
                                  .value,
                          intensity:
                              intensity,
                        ),
                        child:
                            Center(
                          child: Text(
                            seichi.icon,
                            style:
                                const TextStyle(
                              fontSize: 23,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT DESTINATION',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing:
                              1.5,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              Colors.grey,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        '${seichi.card}  ${seichi.name}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '目的地へ',
                  onPressed:
                      _moveCameraToNextSeichi,
                  icon: const Icon(
                    Icons
                        .navigation_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    distance == null
                        ? '距離を計算中…'
                        : '現在地から ${_formatDistance(distance)}',
                    style:
                        const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '到達 ${seichi.stampRadiusMeters}m',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              child:
                  LinearProgressIndicator(
                value: intensity,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard({
    required Widget child,
  }) {
    return Material(
      elevation: 8,
      borderRadius:
          BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              Colors.white.withValues(
            alpha: 0.96,
          ),
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }

  // ============================================================
  // スタンプ獲得演出
  // ============================================================

  Widget _buildStampAnimation() {
    if (!_justCollected) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child:
              TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0.7,
              end: 1.0,
            ),
            duration:
                const Duration(
              milliseconds: 500,
            ),
            builder: (
              context,
              scale,
              child,
            ) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Material(
              elevation: 16,
              borderRadius:
                  BorderRadius.circular(
                28,
              ),
              child: Container(
                width: 290,
                padding:
                    const EdgeInsets.all(
                  24,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    28,
                  ),
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Text(
                      '🏆',
                      style: TextStyle(
                        fontSize: 64,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    const Text(
                      '聖地到達！',
                      style:
                          TextStyle(
                        fontSize: 27,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      _collectedName ?? '',
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      '${_getCollectedCount()} / ${_seichiList.length} 聖地獲得',
                      style:
                          const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // コレクションバッジ
  // ============================================================

  Widget _buildCollectionBadge() {
    return Positioned(
      top: 145,
      right: 14,
      child: Material(
        elevation: 5,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 19,
              ),
              const SizedBox(width: 6),
              Text(
                '${_getCollectedCount()} / ${_seichiList.length}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 現在地ボタン
  // ============================================================

  Widget _buildLocationButton() {
    return Positioned(
      right: 14,
      bottom: 165,
      child: FloatingActionButton(
        heroTag: 'currentLocation',
        elevation: 6,
        onPressed:
            _moveCameraToCurrentLocation,
        child: _isLoadingLocation
            ? const SizedBox(
                width: 22,
                height: 22,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.my_location,
              ),
      ),
    );
  }

  // ============================================================
  // 次の目的地ボタン
  // ============================================================

  Widget _buildNextButton() {
    if (_nextSeichi == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 88,
      child: FilledButton.icon(
        onPressed:
            _moveCameraToNextSeichi,
        icon: const Icon(
          Icons.navigation_rounded,
        ),
        label: Text(
          '次の聖地へ  ${_nextSeichi!.card}',
        ),
        style:
            FilledButton.styleFrom(
          minimumSize:
              const Size.fromHeight(
            52,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Google Maps
  // ============================================================

  Widget _buildMap() {
    LatLng initialTarget =
        _defaultCenter;

    if (_currentPosition != null) {
      initialTarget = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

    return GoogleMap(
      initialCameraPosition:
          CameraPosition(
        target: initialTarget,
        zoom: 10.5,
      ),
      mapType: MapType.normal,
      myLocationEnabled:
          _currentPosition != null,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: _buildMarkers(),
      onMapCreated:
          (controller) {
        _mapController = controller;

        if (_currentPosition != null) {
          _moveCameraToCurrentLocation();
        }
      },
      onTap: (_) {},
    );
  }

  // ============================================================
  // マップ画面
  // ============================================================

  Widget _buildMapPage() {
    return Stack(
      children: [
        _buildMap(),
        _buildNextDestinationCard(),
        _buildCollectionBadge(),
        _buildLocationButton(),
        _buildNextButton(),
        _buildErrorCard(),
        _buildStampAnimation(),
      ],
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
      onShowDestination: _moveCameraToNextSeichi,
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

  Widget _buildMyPage() {
    return MyPage(
      count: _getCollectedCount(),
      total: _seichiList.length,
      onShowProfile: () {
        _showComingSoon('プロフィール機能');
      },
      onShowNotifications: () {
        _showComingSoon('通知設定');
      },
      onShowSettings: () {
        _showComingSoon('アプリ設定');
      },
      onShowAbout: _showAbout,
    );
  }
  // ============================================================
  // ページヘッダー
  // ============================================================

  void _showComingSoon(
    String title,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '$title は今後実装予定です。',
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

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

      case 2:
        return _buildQuestPage();

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
