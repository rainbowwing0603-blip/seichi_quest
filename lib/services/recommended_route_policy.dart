import '../models/seichi.dart';

class RouteAdvanceResult {
  const RouteAdvanceResult({
    required this.route,
    required this.manualNextSeichiId,
  });

  final List<Seichi> route;
  final String? manualNextSeichiId;
}

/// おすすめルートの開始・獲得後前進を純粋ロジックとして扱う。
abstract final class RecommendedRoutePolicy {
  static RouteAdvanceResult start({
    required Iterable<Seichi> route,
    required Set<String> collectedIds,
  }) {
    final remaining = route
        .where((seichi) => !collectedIds.contains(seichi.id))
        .toList(growable: false);

    return RouteAdvanceResult(
      route: remaining,
      manualNextSeichiId: remaining.isEmpty ? null : remaining.first.id,
    );
  }

  static RouteAdvanceResult advanceAfterCollection({
    required Iterable<Seichi> activeRoute,
    required String? manualNextSeichiId,
    required Set<String> collectedIds,
    required Set<String> newlyCollectedIds,
  }) {
    final route = activeRoute
        .where((seichi) => !collectedIds.contains(seichi.id))
        .toList(growable: false);

    if (route.isNotEmpty) {
      return RouteAdvanceResult(
        route: route,
        manualNextSeichiId: route.first.id,
      );
    }

    final shouldClearManual = manualNextSeichiId != null &&
        newlyCollectedIds.contains(manualNextSeichiId);

    return RouteAdvanceResult(
      route: route,
      manualNextSeichiId: shouldClearManual ? null : manualNextSeichiId,
    );
  }
}
