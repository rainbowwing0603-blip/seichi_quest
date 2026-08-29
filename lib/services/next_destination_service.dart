import 'package:geolocator/geolocator.dart';

import '../models/seichi.dart';

class NextDestinationResult {
  final Seichi? seichi;
  final double? distance;

  const NextDestinationResult({
    required this.seichi,
    required this.distance,
  });
}

class NextDestinationService {
  const NextDestinationService();

  NextDestinationResult findNextDestination({
    required Position? position,
    required List<Seichi> seichiList,
    required Set<String> collectedIds,
    String? manualNextSeichiId,
  }) {
    if (position == null || seichiList.isEmpty) {
      return const NextDestinationResult(
        seichi: null,
        distance: null,
      );
    }

    Seichi? target;

    // 手動指定された未取得の目的地を優先する。
    if (manualNextSeichiId != null) {
      for (final seichi in seichiList) {
        if (seichi.id == manualNextSeichiId &&
            !collectedIds.contains(seichi.id)) {
          target = seichi;
          break;
        }
      }
    }

    // 手動指定がない、または無効になった場合は最寄りの未取得聖地を選ぶ。
    if (target == null) {
      double? nearestDistance;

      for (final seichi in seichiList) {
        if (collectedIds.contains(seichi.id)) {
          continue;
        }

        final distance = Geolocator.distanceBetween(
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
      targetDistance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        target.latitude,
        target.longitude,
      );
    }

    return NextDestinationResult(
      seichi: target,
      distance: targetDistance,
    );
  }
}