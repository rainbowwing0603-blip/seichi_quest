import 'package:flutter/material.dart';
import 'mission_page.dart';

/// Existing pages can launch missions without changing their internal logic.
Future<void> openMissionPage(
  BuildContext context, {
  required int collectedCount,
  required int visitedCount,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MissionPage(
        collectedCount: collectedCount,
        visitedCount: visitedCount,
      ),
    ),
  );
}
