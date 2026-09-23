import 'package:geolocator/geolocator.dart';

import '../models/quest_destination.dart';

class NextDestinationResult<T extends QuestDestination> {
  final T? destination;
  final double? distance;

  const NextDestinationResult({
    required this.destination,
    required this.distance,
  });

  T? get seichi => destination;
}

class NextDestinationService {
  const NextDestinationService();

  NextDestinationResult<T> findNextDestination<T extends QuestDestination>({
    required Position? position,
    required List<T> seichiList,
    required Set<String> collectedIds,
    String? manualNextSeichiId,
  }) {
    if (position == null || seichiList.isEmpty) {
      return NextDestinationResult<T>(
        destination: null,
        distance: null,
      );
    }

    T? target;
    double? targetDistance;

    if (manualNextSeichiId != null) {
      for (final destination in seichiList) {
        if (destination.id == manualNextSeichiId &&
            !collectedIds.contains(destination.id)) {
          target = destination;
          break;
        }
      }
    }

    if (target == null) {
      double? nearestDistance;

      for (final destination in seichiList) {
        if (collectedIds.contains(destination.id)) {
          continue;
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destination.latitude,
          destination.longitude,
        );

        if (nearestDistance == null || distance < nearestDistance) {
          target = destination;
          nearestDistance = distance;
          targetDistance = distance;
        }
      }
    }

    if (target != null && targetDistance == null) {
      targetDistance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        target.latitude,
        target.longitude,
      );
    }

    return NextDestinationResult<T>(
      destination: target,
      distance: targetDistance,
    );
  }
}
