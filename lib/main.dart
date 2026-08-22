import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  await supabase.Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );

  runApp(const SeichiQuestApp());
}

// ============================================================
// 聖地データ
// ============================================================

class Seichi {
  final String id;
  final String card;
  final String reading;
  final String name;
  final double latitude;
  final double longitude;
  final int stampRadiusMeters;
  final String description;
  final String icon;
  final bool isActive;

  const Seichi({
    required this.id,
    required this.card,
    required this.reading,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.stampRadiusMeters,
    required this.description,
    required this.icon,
    required this.isActive,
  });

  factory Seichi.fromMap(Map<String, dynamic> map) {
    return Seichi(
      id: map['id']?.toString() ?? '',
      card: map['card']?.toString() ?? '',
      reading: map['reading']?.toString() ?? '',
      name: map['name']?.toString() ?? '名称未設定',
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      stampRadiusMeters: _toInt(
        map['stamp_radius_meters'],
        fallback: 200,
      ),
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '📍',
      isActive: map['is_active'] == true,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  static int _toInt(
    dynamic value, {
    required int fallback,
  }) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }
}

// ============================================================
// アプリ本体
// ============================================================

class SeichiQuestApp extends StatelessWidget {
  const SeichiQuestApp({super.key});

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
      home: const SeichiMapPage(),
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
    'い', 'ろ', 'は', 'に', 'ほ', 'へ', 'と', 'ち',
    'り', 'ぬ', 'る', 'を', 'わ', 'か', 'よ', 'た',
    'れ', 'そ', 'つ', 'ね', 'な', 'ら', 'む', 'う',
    'の', 'お', 'く', 'や', 'ま', 'け', 'ふ', 'こ',
    'え', 'て', 'あ', 'さ', 'き', 'ゆ', 'め', 'み',
    'ひ', 'も', 'せ', 'す',
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
    await _loadSeichi();
    await _initializeLocation();
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
    final position = _currentPosition;

    if (position == null ||
        _seichiList.isEmpty) {
      return;
    }

    Seichi? target;

    // 手動指定された目的地がまだ未獲得なら、その目的地を優先する。
    if (_manualNextSeichiId != null) {
      for (final seichi in _seichiList) {
        if (seichi.id == _manualNextSeichiId &&
            !_collectedIds.contains(seichi.id)) {
          target = seichi;
          break;
        }
      }

      // 指定先を獲得済み・削除済みの場合は自動選択へ戻す。
      if (target == null) {
        _manualNextSeichiId = null;
      }
    }

    // 手動指定がない場合は、従来どおり最寄りの未獲得聖地。
    if (target == null) {
      double? nearestDistance;

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

        if (nearestDistance == null ||
            distance < nearestDistance) {
          target = seichi;
          nearestDistance = distance;
        }
      }
    }

    double? targetDistance;

    if (target != null) {
      targetDistance =
          Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        target.latitude,
        target.longitude,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _nextSeichi = target;
      _nextDistance = targetDistance;
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
              Colors.white.withOpacity(
            0.96,
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
  // スタンプ帳
  // ============================================================

  Widget _buildCollectionPage() {
    final total =
        _seichiList.length;

    final collected =
        _getCollectedCount();

    final remaining =
        math.max(
          0,
          total - collected,
        );

    final progress =
        total == 0
            ? 0.0
            : collected / total;

    List<Seichi> filteredList;

    switch (_collectionFilter) {
      case 1:
        filteredList = _seichiList
            .where(
              (seichi) =>
                  _collectedIds.contains(
                seichi.id,
              ),
            )
            .toList();
        break;

      case 2:
        filteredList = _seichiList
            .where(
              (seichi) =>
                  !_collectedIds.contains(
                seichi.id,
              ),
            )
            .toList();
        break;

      default:
        filteredList =
            List<Seichi>.from(
          _seichiList,
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
                          _collectedIds
                              .contains(
                        seichi.id,
                      );

                      return _buildCollectionCard(
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
                      .withOpacity(
                    0.16,
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
              const Expanded(
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
                          : '上毛かるた ${total}札',
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
                      .withOpacity(
                    0.16,
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
                      .withOpacity(
                0.20,
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
                _collectionFilter ==
                    0,
            onTap: () {
              setState(() {
                _collectionFilter =
                    0;
              });
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
                _collectionFilter ==
                    1,
            onTap: () {
              setState(() {
                _collectionFilter =
                    1;
              });
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
                _collectionFilter ==
                    2,
            onTap: () {
              setState(() {
                _collectionFilter =
                    2;
              });
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
                      .withOpacity(
                    0.06,
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
        _collectionFilter == 1;

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
                    .withOpacity(
                  0.08,
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
            const SizedBox(
              height: 8,
            ),
            Text(
              isCollectedFilter
                  ? '聖地へ向かってスタンプを集めよう！'
                  : 'すべての札を制覇しました。',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: Colors.grey,
                height: 1.5,
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
                      .withOpacity(
                    0.35,
                  )
                  : Colors.grey
                      .withOpacity(
                    0.12,
                  ),
              width:
                  collected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: collected
                    ? Colors.green
                        .withOpacity(
                      0.08,
                    )
                    : Colors.black
                        .withOpacity(
                      0.045,
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
                            .withOpacity(
                          0.10,
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
                  color: Colors.white.withOpacity(0.92),
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
          color: Colors.green.withOpacity(0.45),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.12),
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
                          .withOpacity(
                        0.08,
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

                      await _moveCameraToSeichi(
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
                        _setNextDestination(seichi);
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

  Widget _buildQuestPage() {
    final next =
        _nextSeichi;

    final count =
        _getCollectedCount();

    return SafeArea(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildPageHeader(
              title: 'クエスト',
              subtitle:
                  '次の聖地を目指そう',
              icon: Icons.flag,
            ),
            const SizedBox(
              height: 4,
            ),
            if (next != null)
              _buildQuestMainCard(
                next,
              )
            else
              _buildAllClearCard(),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'チャレンジ',
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            _buildMissionTile(
              icon:
                  Icons.location_on,
              title: '最初の聖地',
              subtitle:
                  '1つの聖地を獲得する',
              progress:
                  count > 0 ? 1 : 0,
              total: 1,
            ),
            _buildMissionTile(
              icon:
                  Icons.emoji_events,
              title: 'コレクター',
              subtitle:
                  '10個の聖地を獲得する',
              progress:
                  math.min(count, 10),
              total: 10,
            ),
            _buildMissionTile(
              icon: Icons.map,
              title: '群馬探訪',
              subtitle:
                  '25個の聖地を獲得する',
              progress:
                  math.min(count, 25),
              total: 25,
            ),
            _buildMissionTile(
              icon:
                  Icons.workspace_premium,
              title: '完全制覇',
              subtitle:
                  '44個すべての聖地を獲得する',
              progress:
                  math.min(count, 44),
              total: 44,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestMainCard(
    Seichi seichi,
  ) {
    final distance =
        _nextDistance;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        22,
      ),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFF24123D),
            Color(0xFF6A35C8),
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          28,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'NEXT QUEST',
            style:
                TextStyle(
              color:
                  Colors.white70,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Row(
            children: [
              Text(
                seichi.icon,
                style:
                    const TextStyle(
                  fontSize: 48,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      seichi.card,
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                      ),
                    ),
                    Text(
                      seichi.name,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 22,
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
            height: 20,
          ),
          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(
                0.12,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.near_me,
                  color:
                      Colors.white,
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    distance == null
                        ? '現在地を取得中…'
                        : '現在地から ${_formatDistance(distance)}',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          SizedBox(
            width: double.infinity,
            child:
                FilledButton(
              onPressed:
                  _moveCameraToNextSeichi,
              style:
                  FilledButton
                      .styleFrom(
                backgroundColor:
                    Colors.white,
                foregroundColor:
                    const Color(
                  0xFF6A35C8,
                ),
                minimumSize:
                    const Size
                        .fromHeight(
                  52,
                ),
              ),
              child:
                  const Text(
                '目的地を見る',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllClearCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        28,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),
      child:
          const Column(
        children: [
          Text(
            '🏆',
            style:
                TextStyle(
              fontSize: 64,
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            '完全制覇！',
            style:
                TextStyle(
              fontSize: 26,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          SizedBox(
            height: 8,
          ),
          Text(
            '登録されている聖地をすべて獲得しました。',
            textAlign:
                TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required int progress,
    required int total,
  }) {
    final ratio =
        total == 0
            ? 0.0
            : (progress / total)
                .clamp(
                0.0,
                1.0,
              )
                .toDouble();

    final completed =
        progress >= total;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color: completed
                  ? Colors.green
                      .withOpacity(
                    0.12,
                  )
                  : Colors
                      .deepPurple
                      .withOpacity(
                    0.08,
                  ),
              shape:
                  BoxShape.circle,
            ),
            child: Icon(
              completed
                  ? Icons.check
                  : icon,
              color: completed
                  ? Colors.green
                  : Colors
                      .deepPurple,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                ClipRRect(
                  borderRadius:
                      BorderRadius
                          .circular(
                    6,
                  ),
                  child:
                      LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Text(
            '$progress/$total',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ランキング画面
  // ============================================================

  Widget _buildRankingPage() {
    final myCount =
        _getCollectedCount();

    return SafeArea(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildPageHeader(
              title: 'ランキング',
              subtitle:
                  '聖地巡礼の記録',
              icon:
                  Icons.leaderboard,
            ),
            const SizedBox(
              height: 4,
            ),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                24,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              child:
                  Column(
                children: [
                  const Text(
                    'あなたの記録',
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    '$myCount / ${_seichiList.length}',
                    style:
                        const TextStyle(
                      fontSize: 42,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  const Text(
                    '聖地獲得数',
                    style:
                        TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'ランキング',
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            _buildRankingRow(
              rank: 1,
              name: '群馬マスター',
              count: 44,
              icon: '🥇',
            ),
            _buildRankingRow(
              rank: 2,
              name: '上毛探訪者',
              count: 32,
              icon: '🥈',
            ),
            _buildRankingRow(
              rank: 3,
              name: '聖地ハンター',
              count: 27,
              icon: '🥉',
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration:
                  BoxDecoration(
                color: Colors
                    .deepPurple
                    .withOpacity(
                  0.07,
                ),
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child:
                  const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      'オンラインランキングは今後実装予定です。',
                      style:
                          TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingRow({
    required int rank,
    required String name,
    required int count,
    required String icon,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Row(
        children: [
          Text(
            icon,
            style:
                const TextStyle(
              fontSize: 26,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Text(
            '$rank',
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Text(
              name,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // マイページ
  // ============================================================

  Widget _buildMyPage() {
    final count =
        _getCollectedCount();
    final total =
        _seichiList.length;

    return SafeArea(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          children: [
            const SizedBox(
              height: 12,
            ),
            Container(
              width: 94,
              height: 94,
              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFF6A35C8),
                    Color(0xFF9B72E8),
                  ],
                ),
                shape:
                    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors
                        .deepPurple
                        .withOpacity(
                      0.25,
                    ),
                    blurRadius: 18,
                    offset:
                        const Offset(
                      0,
                      8,
                    ),
                  ),
                ],
              ),
              child:
                  const Icon(
                Icons.person,
                color:
                    Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            const Text(
              'ゲストユーザー',
              style:
                  TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              '聖地クエスト冒険者',
              style:
                  TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            Row(
              children: [
                Expanded(
                  child:
                      _buildStatCard(
                    icon: Icons
                        .workspace_premium,
                    value:
                        '$count',
                    label:
                        '獲得聖地',
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      _buildStatCard(
                    icon:
                        Icons.map,
                    value:
                        '$total',
                    label:
                        '登録聖地',
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      _buildStatCard(
                    icon:
                        Icons.percent,
                    value: total == 0
                        ? '0%'
                        : '${(count / total * 100).round()}%',
                    label:
                        '達成率',
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 24,
            ),
            _buildSettingsTile(
              icon:
                  Icons.person_outline,
              title:
                  'プロフィール',
              subtitle:
                  'ユーザー情報を設定',
              onTap: () {
                _showComingSoon(
                  'プロフィール機能',
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons
                  .notifications_none,
              title:
                  '通知設定',
              subtitle:
                  'お知らせ・到達通知',
              onTap: () {
                _showComingSoon(
                  '通知設定',
                );
              },
            ),
            _buildSettingsTile(
              icon:
                  Icons.settings_outlined,
              title:
                  'アプリ設定',
              subtitle:
                  '各種設定',
              onTap: () {
                _showComingSoon(
                  'アプリ設定',
                );
              },
            ),
            _buildSettingsTile(
              icon:
                  Icons.info_outline,
              title:
                  '聖地クエストについて',
              subtitle:
                  'アプリ情報',
              onTap:
                  _showAbout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 8,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color:
                Colors.deepPurple,
            size: 23,
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            value,
            style:
                const TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            label,
            style:
                const TextStyle(
              fontSize: 11,
              color:
                  Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 4,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(
            color: Colors
                .deepPurple
                .withOpacity(
              0.08,
            ),
            shape:
                BoxShape.circle,
          ),
          child: Icon(
            icon,
            color:
                Colors.deepPurple,
          ),
        ),
        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style:
              const TextStyle(
            fontSize: 12,
          ),
        ),
        trailing:
            const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }

  // ============================================================
  // ページヘッダー
  // ============================================================

  Widget _buildPageHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        12,
        8,
        18,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF6A35C8),
                  Color(0xFF8B5CF6),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              icon,
              color:
                  Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 近日公開
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
  // 5メニュー切り替え
  // ============================================================

  void _onTabSelected(
    int index,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTab = index;
    });

    if (index == 0) {
      Future.delayed(
        const Duration(
          milliseconds: 150,
        ),
        () {
          if (mounted) {
            _moveCameraToCurrentLocation();
          }
        },
      );
    }
  }

  // ============================================================
  // 現在のページ
  // ============================================================

  Widget _buildCurrentPage() {
    switch (_selectedTab) {
      case 0:
        return _buildMapPage();

      case 1:
        return _buildCollectionPage();

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
  // BottomNavigationBar
  // ============================================================

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex:
          _selectedTab,
      onDestinationSelected:
          _onTabSelected,
      height: 72,
      backgroundColor:
          Colors.white,
      elevation: 10,
      indicatorColor:
          Colors.deepPurple
              .withOpacity(
        0.12,
      ),
      destinations:
          const [
        NavigationDestination(
          icon: Icon(
            Icons.map_outlined,
          ),
          selectedIcon:
              Icon(
            Icons.map,
          ),
          label: 'マップ',
        ),
        NavigationDestination(
          icon: Icon(
            Icons
                .workspace_premium_outlined,
          ),
          selectedIcon:
              Icon(
            Icons
                .workspace_premium,
          ),
          label: 'スタンプ帳',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.flag_outlined,
          ),
          selectedIcon:
              Icon(
            Icons.flag,
          ),
          label: 'クエスト',
        ),
        NavigationDestination(
          icon: Icon(
            Icons
                .leaderboard_outlined,
          ),
          selectedIcon:
              Icon(
            Icons.leaderboard,
          ),
          label: 'ランキング',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.person_outline,
          ),
          selectedIcon:
              Icon(
            Icons.person,
          ),
          label: 'マイページ',
        ),
      ],
    );
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
      bottomNavigationBar:
          _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // Dispose
  // ============================================================

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

class StampRingPainter
    extends CustomPainter {
  final bool large;

  const StampRingPainter({
    this.large = false,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        math.min(
          size.width,
          size.height,
        ) /
            2 -
        (large ? 12 : 8);

    final paint = Paint()
      ..style =
          PaintingStyle.stroke
      ..strokeWidth =
          large ? 2 : 1.4
      ..color =
          Colors.green.withOpacity(
        0.35,
      );

    canvas.drawCircle(
      center,
      radius,
      paint,
    );

    final innerPaint = Paint()
      ..style =
          PaintingStyle.stroke
      ..strokeWidth =
          large ? 1.2 : 1
      ..color =
          Colors.green.withOpacity(
        0.22,
      );

    canvas.drawCircle(
      center,
      radius -
          (large ? 7 : 5),
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant StampRingPainter
        oldDelegate,
  ) {
    return oldDelegate.large !=
        large;
  }
}

// ============================================================
// ソナー描画
// ============================================================

class SonarPainter
    extends CustomPainter {
  final double progress;
  final double intensity;

  const SonarPainter({
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final baseRadius =
        math.min(
          size.width,
          size.height,
        ) /
            2;

    final pulse =
        (progress * 2) % 1.0;

    for (int i = 0; i < 3; i++) {
      final localProgress =
          (pulse + i / 3) % 1.0;

      final radius =
          baseRadius *
              (0.35 +
                  localProgress *
                      0.65);

      final opacity =
          (1.0 -
                  localProgress) *
              intensity *
              0.55;

      final paint = Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors
            .deepPurple
            .withOpacity(
          opacity,
        );

      canvas.drawCircle(
        center,
        radius,
        paint,
      );
    }

    final centerPaint = Paint()
      ..style =
          PaintingStyle.fill
      ..color = Colors
          .deepPurple
          .withOpacity(
        0.12 +
            intensity * 0.18,
      );

    canvas.drawCircle(
      center,
      baseRadius * 0.35,
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant SonarPainter
        oldDelegate,
  ) {
    return oldDelegate.progress !=
            progress ||
        oldDelegate.intensity !=
            intensity;
  }
}