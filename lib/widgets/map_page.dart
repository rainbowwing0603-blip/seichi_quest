import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/real_world_state.dart';
import '../models/seichi.dart';
import '../painters/sonar_painter.dart';
import 'stamp_animation.dart';
import 'weather_effect_overlay.dart';

class MapPage extends StatelessWidget {
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
  final Seichi? nextSeichi;
  final double? nextDistance;
  final Set<String> collectedIds;
  final bool isLoadingLocation;
  final String? errorMessage;
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

  const MapPage({
    super.key,
    required this.mapController,
    required this.currentPosition,
    required this.realWorldState,
    required this.nextSeichi,
    required this.nextDistance,
    required this.collectedIds,
    required this.isLoadingLocation,
    required this.errorMessage,
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

    final radius =
        nextSeichi?.stampRadiusMeters ?? 200;

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

  Widget _buildQuestHud() {
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
    final temperatureLabel =
        temperature == null ? '--°' : '${temperature.round()}°';

    final intensity = _sonarIntensity();

    const primary = Color(0xFF5968E8);
    const primaryDeep = Color(0xFF403A9F);
    const cyan = Color(0xFF25A9C7);
    const ink = Color(0xFF102A43);
    const mutedInk = Color(0xFF60758A);

    return Positioned(
      top: 14,
      left: 14,
      right: 14,
      child: SafeArea(
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
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  7,
                                  6,
                                  11,
                                  6,
                                ),
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
                                    Text(
                                      '$temperatureLabel  $seasonLabel・$dayPhaseLabel',
                                      style: const TextStyle(
                                        color: Color(0xFF174B5E),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  7,
                                  6,
                                  11,
                                  6,
                                ),
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
                                      color:
                                          primary.withValues(alpha: 0.15),
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
                                            color:
                                                primary.withValues(alpha: 0.32),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 15,
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
                                        color:
                                            primary.withValues(alpha: 0.32),
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
                                                colors: [
                                                  cyan,
                                                  primary,
                                                ],
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
                                                progress:
                                                    sonarController.value,
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
                                                colors: [
                                                  cyan,
                                                  primary,
                                                ],
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
                                        '${seichi.card}  ${seichi.name}',
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
                                      final progress =
                                          intensity.clamp(0.0, 1.0);
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
                                          borderRadius:
                                              BorderRadius.circular(20),
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
                                                gradient:
                                                    const LinearGradient(
                                                  colors: [
                                                    cyan,
                                                    primary,
                                                    primaryDeep,
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        primary.withValues(
                                                      alpha: 0.38,
                                                    ),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (progress > 0.02)
                                              Positioned(
                                                left: (progressWidth - 8)
                                                    .clamp(
                                                      0.0,
                                                      constraints.maxWidth -
                                                          16,
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
                                      color:
                                          primary.withValues(alpha: 0.14),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            primary.withValues(alpha: 0.08),
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
                  errorMessage!,
                  style:
                      const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismissError,
                icon:
                    const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }




  Widget _buildLocationButton() {
    return Positioned(
      right: 14,
      bottom: 165,
      child: FloatingActionButton(
        heroTag: 'currentLocation',
        elevation: 6,
        onPressed:
            onMoveToCurrentLocation,
        child: isLoadingLocation
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

  Widget _buildNextButton() {
    if (nextSeichi == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 88,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  onMoveToNextSeichi,
              icon: const Icon(
                Icons.map_rounded,
              ),
              label: const Text(
                '地図で見る',
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F3B78),
                backgroundColor: Colors.white.withValues(alpha: 0.88),
                side: BorderSide(
                  color: const Color(0xFF6F55A0).withValues(alpha: 0.45),
                  width: 1.2,
                ),
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
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed:
                  onStartNavigation,
              icon: const Icon(
                Icons.directions_rounded,
              ),
              label: const Text(
                'ナビ開始',
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
        child: ColoredBox(
          color: color.withValues(alpha: opacity),
        ),
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
        child: ColoredBox(
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }

  Widget _buildMap() {
    LatLng initialTarget =
        defaultCenter;

    if (currentPosition != null) {
      initialTarget = LatLng(
        currentPosition!.latitude,
        currentPosition!.longitude,
      );
    }

    return GoogleMap(
      initialCameraPosition:
          CameraPosition(
        target: initialTarget,
        zoom: 10.5,
      ),
      mapType: MapType.normal,
      style: realWorldState?.dayPhase == DayPhase.night
          ? _nightMapStyle
          : null,
      myLocationEnabled:
          currentPosition != null,
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
    return Stack(
      children: [
        _buildMap(),
        _buildEnvironmentOverlay(),
        _buildSeasonOverlay(),
        if (realWorldState != null)
          WeatherEffectOverlay(
            weather: realWorldState!.weather,
            dayPhase: realWorldState!.dayPhase,
          ),
        _buildQuestHud(),
        _buildLocationButton(),
        _buildNextButton(),
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
