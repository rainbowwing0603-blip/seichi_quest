import '../models/quest_destination.dart';

class RouteAdvanceResult<T extends QuestDestination> {
  const RouteAdvanceResult({
    required this.route,
    required this.manualNextSeichiId,
  });

  final List<T> route;
  final String? manualNextSeichiId;
}

/// おすすめルートの開始・獲得後前進を純粋ロジックとして扱う。
abstract final class RecommendedRoutePolicy {
  static RouteAdvanceResult<T> start<T extends QuestDestination>({
    required Iterable<T> route,
    required Set<String> collectedIds,
  }) {
    final remaining = route
        .where((destination) => !collectedIds.contains(destination.id))
        .toList(growable: false);

    return RouteAdvanceResult<T>(
      route: remaining,
      manualNextSeichiId: remaining.isEmpty ? null : remaining.first.id,
    );
  }

  static RouteAdvanceResult<T>
      advanceAfterCollection<T extends QuestDestination>({
    required Iterable<T> activeRoute,
    required String? manualNextSeichiId,
    required Set<String> collectedIds,
    required Set<String> newlyCollectedIds,
  }) {
    final route = activeRoute
        .where((destination) => !collectedIds.contains(destination.id))
        .toList(growable: false);

    if (route.isNotEmpty) {
      return RouteAdvanceResult<T>(
        route: route,
        manualNextSeichiId: route.first.id,
      );
    }

    final shouldClearManual = manualNextSeichiId != null &&
        newlyCollectedIds.contains(manualNextSeichiId);

    return RouteAdvanceResult<T>(
      route: route,
      manualNextSeichiId: shouldClearManual ? null : manualNextSeichiId,
    );
  }
}
