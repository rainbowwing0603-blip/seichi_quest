import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/seichi.dart';
import '../painters/sonar_painter.dart';
import 'stamp_animation.dart';

class MapPage extends StatelessWidget {
  final GoogleMapController? mapController;
  final Position? currentPosition;
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
  final ValueChanged<GoogleMapController> onMapCreated;
  final VoidCallback onDismissError;

  const MapPage({
    super.key,
    required this.mapController,
    required this.currentPosition,
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

  Widget _buildNextDestinationCard() {
    final seichi = nextSeichi;
    final distance = nextDistance;

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
                  collectedCount >= total &&
                          total > 0
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
                      sonarController,
                  builder:
                      (context, child) {
                    return SizedBox(
                      width: 50,
                      height: 50,
                      child: CustomPaint(
                        painter:
                            SonarPainter(
                          progress:
                              sonarController
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
                      onMoveToNextSeichi,
                  icon: const Icon(
                    Icons.navigation_rounded,
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
                '$collectedCount / $total',
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
      child: FilledButton.icon(
        onPressed:
            onMoveToNextSeichi,
        icon: const Icon(
          Icons.navigation_rounded,
        ),
        label: Text(
          '次の聖地へ  ${nextSeichi!.card}',
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
        _buildNextDestinationCard(),
        _buildCollectionBadge(),
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