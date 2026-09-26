import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/real_world_state.dart';
import '../models/quest_item.dart';
import '../painters/sonar_painter.dart';
import '../services/app_error_report.dart';
import '../services/weather_safety_policy.dart';
import 'stamp_animation.dart';
import 'season_effect_overlay.dart';
import 'quest_ui.dart';
import 'weather_effect_overlay.dart';
import 'weather_safety_banner.dart';

class MapPage extends StatelessWidget {
  // Insets are relative to the usable body area. The Scaffold owns the
  // banner and bottom navigation heights, so this page must not duplicate them.
  static const double _bottomActionInset = 36;
  static const double _locationButtonInset = 101;

  static const String _nightMapStyle = r'''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#242f3e" }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#746855" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#242f3e" }
    ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#d59563" }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#d59563" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      { "color": "#263c3f" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#6b9a76" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      { "color": "#38414e" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#212a37" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#9ca5b3" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      { "color": "#746855" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#1f2835" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#f3d19c" }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      { "color": "#2f3948" }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#d59563" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      { "color": "#17263c" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#515c6d" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#17263c" }
    ]
  }
]
''';

  final GoogleMapController? mapController;
  final Position? currentPosition;
  final RealWorldState? realWorldState;
  final bool weatherUnavailable;
  final QuestItem? nextSeichi;
  final double? nextDistance;
  final Set<String> collectedIds;
  final bool isLoadingLocation;
  final String? errorMessage;
  final String? errorActionLabel;
  final Future<void> Function()? onErrorAction;
  final AnimationController sonarController;
  final bool justCollected;
  final String? collectedName;
  final int collectedCount;
  final int total;
  final LatLng defaultCenter;

  final Set<Marker> markers;

  final VoidCallback onMoveToCurrentLocation;
  final VoidCallback onMoveToNextSeichi;
  final VoidCallback onStartNavigation;
  final ValueChanged<GoogleMapController> onMapCreated;
  final VoidCallback onDismissError;
  final bool isQuestHudCollapsed;
  final VoidCallback? onToggleQuestHud;

  const MapPage({
    super.key,
    required this.mapController,
    required this.currentPosition,
    required this.realWorldState,
    this.weatherUnavailable = false,
    required this.nextSeichi,
    required this.nextDistance,
    required this.collectedIds,
    required this.isLoadingLocation,
    required this.errorMessage,
    required this.errorActionLabel,
    required this.onErrorAction,
    required this.sonarController,
    required this.justCollected,
    required this.collectedName,
    required this.collectedCount,
    required this.total,
    required this.defaultCenter,
    required this.markers,
    required this.onMoveToCurrentLocation,
    required this.onMoveToNextSeichi,
    required this.onStartNavigation,
    required this.onMapCreated,
    required this.onDismissError,
    this.isQuestHudCollapsed = false,
    this.onToggleQuestHud,
  });

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    }

    return '${(distance / 1000).toStringAsFixed(1)}km';
  }

  double _sonarIntensity() {
    final distance = nextDistance;

    if (distance == null) {
      return 0.15;
    }

    final radius = nextSeichi?.stampRadiusMeters ?? 200;

    if (distance <= radius) {
      return 1.0;
    }

    // ソナーの反応範囲は聖地ごとの獲得半径から自動計算する。
    // 小さい獲得半径でも最低1km先から反応するようにする。
    final calculatedSonarRange = radius * 5.0;
    final sonarRangeMeters = calculatedSonarRange < 1000.0
        ? 1000.0
        : calculatedSonarRange;

    final normalized = 1.0 - (distance / sonarRangeMeters);

    return normalized.clamp(0.1, 1.0);
  }

  Widget _buildQuestHud({required bool collapsed}) {
    final seichi = nextSeichi;
    final distance = nextDistance;
    final state = realWorldState;

    final weatherIcon = switch (state?.weather) {
      WeatherCondition.clear => Icons.wb_sunny_rounded,
      WeatherCondition.partlyCloudy => Icons.wb_cloudy_rounded,
      WeatherCondition.cloudy => Icons.cloud_rounded,
      WeatherCondition.rain => Icons.water_drop_rounded,
      WeatherCondition.heavyRain => Icons.thunderstorm_rounded,
      WeatherCondition.snow => Icons.ac_unit_rounded,
      WeatherCondition.fog => Icons.blur_on_rounded,
      WeatherCondition.thunderstorm => Icons.thunderstorm_rounded,
      WeatherCondition.unknown => Icons.cloud_outlined,
      null => Icons.cloud_outlined,
    };

    final weatherLabel = weatherUnavailable
        ? '更新待ち'
        : switch (state?.weather) {
            WeatherCondition.clear => '晴れ',
            WeatherCondition.partlyCloudy => '晴れ/曇り',
            WeatherCondition.cloudy => '曇り',
            WeatherCondition.rain => '雨',
            WeatherCondition.heavyRain => '大雨',
            WeatherCondition.snow => '雪',
            WeatherCondition.fog => '霧',
            WeatherCondition.thunderstorm => '雷雨',
            WeatherCondition.unknown || null => '天気確認中',
          };

    final seasonLabel = switch (state?.season) {
      Season.spring => '春',
      Season.summer => '夏',
      Season.autumn => '秋',
      Season.winter => '冬',
      null => '--',
    };

    final dayPhaseLabel = switch (state?.dayPhase) {
      DayPhase.morning => '朝',
      DayPhase.daytime => '昼',
      DayPhase.evening => '夕',
      DayPhase.night => '夜',
      null => '--',
    };

    final temperature = state?.temperatureCelsius;
    final temperatureLabel = temperature == null
        ? '--°'
        : '${temperature.round()}°';

    final intensity = _sonarIntensity();

    if (collapsed) {
      return SafeArea(
        bottom: false,
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(27),
              onTap: onToggleQuestHud,
              child: Container(
                constraints: const BoxConstraints(minHeight: 54),
                padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(27),
                  color: const Color(0xEEF8FAFF),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF102A43).withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF8994FF), Color(0xFF5968E8)],
                        ),
                      ),
                      child: Text(
                        seichi?.icon ?? '🧭',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NEXT QUEST',
                            style: TextStyle(
                              color: Color(0xFF596E82),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            seichi == null
                                ? (collectedCount >= total && total > 0
                                    ? '群馬の聖地を完全制覇！'
                                    : '次のスポットを探しています…')
                                : seichi.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF102A43),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (seichi != null && distance != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDistance(distance),
                        style: const TextStyle(
                          color: Color(0xFF60758A),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: '目的地カードを広げる',
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleQuestHud,
                      icon: const Icon(
                        Icons.expand_more_rounded,
                        color: Color(0xFF5968E8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      );
    }

    const primary = Color(0xFF5968E8);
    const primaryDeep = Color(0xFF403A9F);
    const cyan = Color(0xFF25A9C7);
    const ink = Color(0xFF102A43);
    const mutedInk = Color(0xFF60758A);

    return SafeArea(
      bottom: false,
      child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 18,
              right: 18,
              bottom: -7,
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.15),
                      blurRadius: 23,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xDDFBFDFF),
                    Color(0xD8F4F8FF),
                    Color(0xD8EEECFF),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ink.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                  BoxShadow(
                    color: primary.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  children: [
                    Positioned(
                      top: -65,
                      right: -42,
                      child: Container(
                        width: 175,
                        height: 175,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              primary.withValues(alpha: 0.18),
                              primary.withValues(alpha: 0.00),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -52,
                      bottom: -75,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              cyan.withValues(alpha: 0.13),
                              cyan.withValues(alpha: 0.00),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 32,
                      right: 32,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white,
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Container(
                                padding: const EdgeInsets.fromLTRB(7, 6, 11, 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xBFE2F8FC),
                                      Color(0xBFF3FCFF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: cyan.withValues(alpha: 0.22),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cyan.withValues(alpha: 0.14),
                                      blurRadius: 9,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      blurRadius: 2,
                                      offset: const Offset(-1, -1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 27,
                                      height: 27,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF42C8DC),
                                            Color(0xFF167B9B),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: cyan.withValues(alpha: 0.32),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        weatherIcon,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '$weatherLabel $temperatureLabel｜$seasonLabel・$dayPhaseLabel',
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Color(0xFF174B5E),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xBFECE8FF),
                                      Color(0xBFFAF8FF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: primary.withValues(alpha: 0.20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.15),
                                      blurRadius: 9,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      blurRadius: 2,
                                      offset: const Offset(-1, -1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF8173F5),
                                            Color(0xFF493BA7),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primary.withValues(
                                              alpha: 0.32,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      '$collectedCount / $total',
                                      style: const TextStyle(
                                        color: Color(0xFF3B3476),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: '目的地カードを小さくする',
                                visualDensity: VisualDensity.compact,
                                onPressed: onToggleQuestHud,
                                icon: const Icon(
                                  Icons.expand_less_rounded,
                                  color: Color(0xFF5968E8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primary.withValues(alpha: 0.02),
                                  primary.withValues(alpha: 0.20),
                                  cyan.withValues(alpha: 0.16),
                                  primary.withValues(alpha: 0.02),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (seichi == null)
                            Row(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(19),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF7C89FA),
                                        Color(0xFF5968E8),
                                        Color(0xFF403A9F),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.32),
                                        blurRadius: 14,
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
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 15,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              gradient: const LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [cyan, primary],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          const Text(
                                            'NEXT QUEST',
                                            style: TextStyle(
                                              color: Color(0xFF596E82),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.7,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        collectedCount >= total && total > 0
                                            ? '群馬の聖地を完全制覇！'
                                            : '次の聖地を探しています…',
                                        style: const TextStyle(
                                          color: ink,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            Row(
                              children: [
                                SizedBox(
                                  width: 66,
                                  height: 66,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              primary.withValues(alpha: 0.27),
                                              primary.withValues(alpha: 0.03),
                                            ],
                                          ),
                                        ),
                                      ),
                                      AnimatedBuilder(
                                        animation: sonarController,
                                        builder: (context, child) {
                                          return SizedBox(
                                            width: 64,
                                            height: 64,
                                            child: CustomPaint(
                                              painter: SonarPainter(
                                                progress: sonarController.value,
                                                intensity: intensity,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white,
                                              Color(0xFFE9E9FF),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primary.withValues(
                                                alpha: 0.34,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            seichi.icon,
                                            style: const TextStyle(
                                              fontSize: 25,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 15,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              gradient: const LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [cyan, primary],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          const Text(
                                            'NEXT QUEST',
                                            style: TextStyle(
                                              color: Color(0xFF596E82),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.7,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        seichi.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: ink,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.near_me_rounded,
                                            size: 13,
                                            color: primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              distance == null
                                                  ? '距離を計算中…'
                                                  : '現在地から ${_formatDistance(distance)}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: mutedInk,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(17),
                                    onTap: onMoveToNextSeichi,
                                    child: Container(
                                      width: 49,
                                      height: 49,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(17),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF8994FF),
                                            Color(0xFF5968E8),
                                            Color(0xFF403A9F),
                                          ],
                                          stops: [0.0, 0.50, 1.0],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryDeep.withValues(
                                              alpha: 0.38,
                                            ),
                                            blurRadius: 13,
                                            offset: const Offset(0, 7),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Positioned(
                                            top: 5,
                                            left: 10,
                                            right: 10,
                                            child: Container(
                                              height: 1,
                                              color: Colors.white.withValues(
                                                alpha: 0.60,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            Row(
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final progress = intensity.clamp(
                                        0.0,
                                        1.0,
                                      );
                                      final progressWidth =
                                          constraints.maxWidth * progress;

                                      return Container(
                                        height: 11,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0xFFDCE1EB),
                                              Color(0xFFEEF1F6),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.75,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: ink.withValues(
                                                alpha: 0.10,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 350,
                                              ),
                                              width: progressWidth,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    cyan,
                                                    primary,
                                                    primaryDeep,
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: primary.withValues(
                                                      alpha: 0.38,
                                                    ),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (progress > 0.02)
                                              Positioned(
                                                left: (progressWidth - 8).clamp(
                                                  0.0,
                                                  constraints.maxWidth - 16,
                                                ),
                                                top: -3,
                                                child: Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient:
                                                        const RadialGradient(
                                                          colors: [
                                                            Colors.white,
                                                            Color(0xFFE8E9FF),
                                                          ],
                                                        ),
                                                    border: Border.all(
                                                      color: primary,
                                                      width: 3,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: primary
                                                            .withValues(
                                                              alpha: 0.48,
                                                            ),
                                                        blurRadius: 9,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFFFFF),
                                        Color(0xFFF3F2FF),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                      color: primary.withValues(alpha: 0.14),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.08),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '到達 ${seichi.stampRadiusMeters}m',
                                    style: const TextStyle(
                                      color: mutedInk,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
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
            ),
          ],
        ),
    );
  }

  Widget _buildErrorCard() {
    if (errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: _bottomActionInset,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  const Color(0xFFF2F4FF).withValues(alpha: 0.88),
                  const Color(0xFFEAF8FC).withValues(alpha: 0.86),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: QuestUiTokens.primary.withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                const BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            QuestUiTokens.cyan.withValues(alpha: 0.20),
                            QuestUiTokens.primary.withValues(alpha: 0.16),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: QuestUiTokens.primaryDeep,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LOCATION ALERT',
                              style: TextStyle(
                                color: QuestUiTokens.primaryDeep,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: QuestUiTokens.ink,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onDismissError,
                      tooltip: '閉じる',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: QuestUiTokens.mutedInk,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                if (errorActionLabel != null && onErrorAction != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await onErrorAction!();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                QuestUiTokens.primary.withValues(alpha: 0.92),
                                QuestUiTokens.primaryDeep.withValues(alpha: 0.90),
                                QuestUiTokens.cyan.withValues(alpha: 0.78),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.76),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: QuestUiTokens.primary.withValues(
                                  alpha: 0.20,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                errorActionLabel!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
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
  }
  Widget _buildLocationButton() {
    return Positioned(
      right: 14,
      bottom: _locationButtonInset,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoadingLocation ? null : onMoveToCurrentLocation,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xB82B3448),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.88),
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x42000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: isLoadingLocation
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    if (nextSeichi == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: _bottomActionInset,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onMoveToNextSeichi,
                    borderRadius: BorderRadius.circular(19),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xB82B3448),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.84),
                          width: 1.3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x42000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                          SizedBox(width: 7),
                          Text(
                            '地図で見る',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Color(0x99000000), blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onStartNavigation,
                    borderRadius: BorderRadius.circular(19),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            QuestUiTokens.primary.withValues(alpha: 0.82),
                            QuestUiTokens.primaryDeep.withValues(alpha: 0.78),
                            QuestUiTokens.cyan.withValues(alpha: 0.68),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.86),
                          width: 1.3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x42000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'ナビ開始',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Color(0x99000000), blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentOverlay() {
    final state = realWorldState;

    if (state == null) {
      return const SizedBox.shrink();
    }

    if (state.dayPhase == DayPhase.evening) {
      return Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF725A9A).withValues(alpha: 0.08),
                  const Color(0xFFFF8A65).withValues(alpha: 0.10),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final color = switch (state.dayPhase) {
      DayPhase.morning => const Color(0xFFFFB86B),
      DayPhase.daytime => Colors.transparent,
      DayPhase.evening => Colors.transparent,
      DayPhase.night => const Color(0xFF17365D),
    };

    final opacity = switch (state.dayPhase) {
      DayPhase.morning => 0.065,
      DayPhase.daytime => 0.0,
      DayPhase.evening => 0.0,
      DayPhase.night => 0.0,
    };

    if (opacity == 0.0) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(color: color.withValues(alpha: opacity)),
      ),
    );
  }

  Widget _buildSeasonOverlay() {
    final state = realWorldState;

    if (state == null) {
      return const SizedBox.shrink();
    }

    final color = switch (state.season) {
      Season.spring => const Color(0xFFFFB7C5),
      Season.summer => const Color(0xFF55CFA3),
      Season.autumn => const Color(0xFFD98A3A),
      Season.winter => const Color(0xFFB7D9F2),
    };

    final opacity = switch (state.season) {
      Season.spring => 0.025,
      Season.summer => 0.025,
      Season.autumn => 0.05,
      Season.winter => 0.04,
    };

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(color: color.withValues(alpha: opacity)),
      ),
    );
  }

  Widget _buildMap() {
    LatLng initialTarget = defaultCenter;

    if (currentPosition != null) {
      initialTarget = LatLng(
        currentPosition!.latitude,
        currentPosition!.longitude,
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 10.5),
      mapType: MapType.normal,
      style: realWorldState?.dayPhase == DayPhase.night ? _nightMapStyle : null,
      myLocationEnabled: currentPosition != null,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: markers,
      onMapCreated: onMapCreated,
      onTap: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final safetyMessage = weatherUnavailable
        ? null
        : WeatherSafetyPolicy.message(realWorldState);
    return Stack(
      children: [
        _buildMap(),
        _buildEnvironmentOverlay(),
        _buildSeasonOverlay(),
        if (realWorldState != null)
          SeasonEffectOverlay(
            season: realWorldState!.season,
            dayPhase: realWorldState!.dayPhase,
            weather: realWorldState!.weather,
          ),
        if (realWorldState != null)
          WeatherEffectOverlay(
            weather: realWorldState!.weather,
            dayPhase: realWorldState!.dayPhase,
          ),
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(27),
                clipBehavior: Clip.antiAlias,
                child: AnimatedCrossFade(
                  firstChild: _buildQuestHud(collapsed: false),
                  secondChild: _buildQuestHud(collapsed: true),
                  crossFadeState: isQuestHudCollapsed
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 460),
                  reverseDuration: const Duration(milliseconds: 460),
                  sizeCurve: Curves.easeInOutCubicEmphasized,
                  firstCurve: const Threshold(0.98),
                  secondCurve: const Threshold(0.98),
                  alignment: Alignment.topCenter,
                ),
              ),
              if (safetyMessage != null) ...[
                const SizedBox(height: 8),
                WeatherSafetyBanner(message: safetyMessage),
              ],
              if (weatherUnavailable) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xF4F6F8FC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '天気を更新できませんでした。しばらくして再試行します。'
                    ' (${AppErrorCodes.weatherFetch})',
                    style: const TextStyle(
                      color: QuestUiTokens.mutedInk,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _buildLocationButton(),
        if (errorMessage == null) _buildNextButton(),
        _buildErrorCard(),
        StampAnimation(
          justCollected: justCollected,
          collectedName: collectedName,
          collectedCount: collectedCount,
          total: total,
        ),
      ],
    );
  }
}
