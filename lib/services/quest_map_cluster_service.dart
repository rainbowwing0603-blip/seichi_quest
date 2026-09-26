import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/quest_item.dart';

class QuestMapCluster {
  const QuestMapCluster({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.items,
  });

  final String id;
  final double latitude;
  final double longitude;
  final List<QuestItem> items;

  int get count => items.length;
}

class QuestMapClusterService {
  const QuestMapClusterService();

  List<QuestMapCluster> build({
    required List<QuestItem> items,
    required double zoom,
  }) {
    if (items.isEmpty) return const [];

    // Geographic grid clustering keeps the implementation dependency-free.
    // The grid shrinks with zoom so clusters naturally split as the user zooms in.
    final cellDegrees = _cellDegreesForZoom(zoom);
    final buckets = <String, List<QuestItem>>{};

    for (final item in items) {
      final latCell = (item.latitude / cellDegrees).floor();
      final lonCell = (item.longitude / cellDegrees).floor();
      final key = '$latCell:$lonCell';
      (buckets[key] ??= <QuestItem>[]).add(item);
    }

    return buckets.entries.map((entry) {
      final bucket = entry.value;
      final latitude =
          bucket.fold<double>(0, (sum, item) => sum + item.latitude) /
              bucket.length;
      final longitude =
          bucket.fold<double>(0, (sum, item) => sum + item.longitude) /
              bucket.length;

      return QuestMapCluster(
        id: entry.key,
        latitude: latitude,
        longitude: longitude,
        items: List<QuestItem>.unmodifiable(bucket),
      );
    }).toList(growable: false);
  }

  double _cellDegreesForZoom(double zoom) {
    final normalized = zoom.clamp(6.0, 9.0);
    // zoom 6 -> ~2.0 degrees, zoom 9 -> ~0.25 degrees
    return 2.0 / math.pow(2.0, normalized - 6.0);
  }

  LatLngBounds boundsFor(QuestMapCluster cluster) {
    var south = cluster.items.first.latitude;
    var north = south;
    var west = cluster.items.first.longitude;
    var east = west;

    for (final item in cluster.items.skip(1)) {
      south = math.min(south, item.latitude);
      north = math.max(north, item.latitude);
      west = math.min(west, item.longitude);
      east = math.max(east, item.longitude);
    }

    const padding = 0.04;
    if ((north - south).abs() < padding) {
      north += padding;
      south -= padding;
    }
    if ((east - west).abs() < padding) {
      east += padding;
      west -= padding;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }
}
