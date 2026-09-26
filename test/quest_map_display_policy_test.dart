import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/quest_map_display_policy.dart';

void main() {
  const policy = QuestMapDisplayPolicy();

  test('near zoom shows individual spots', () {
    expect(policy.modeForZoom(10), QuestMapDisplayMode.spots);
    expect(policy.viewportLimitForZoom(10), 400);
  });

  test('middle zoom switches to clusters', () {
    expect(policy.modeForZoom(7), QuestMapDisplayMode.clusters);
    expect(policy.viewportLimitForZoom(7), 1000);
  });

  test('Japan-wide zoom switches to regional progress', () {
    expect(policy.modeForZoom(5), QuestMapDisplayMode.regionalProgress);
    expect(policy.viewportLimitForZoom(5), 0);
  });

  test('display mode boundaries are deterministic', () {
    expect(
      policy.modeForZoom(QuestMapDisplayPolicy.clustersMinZoom - 0.01),
      QuestMapDisplayMode.regionalProgress,
    );
    expect(
      policy.modeForZoom(QuestMapDisplayPolicy.clustersMinZoom),
      QuestMapDisplayMode.clusters,
    );
    expect(
      policy.modeForZoom(QuestMapDisplayPolicy.spotsMinZoom - 0.01),
      QuestMapDisplayMode.clusters,
    );
    expect(
      policy.modeForZoom(QuestMapDisplayPolicy.spotsMinZoom),
      QuestMapDisplayMode.spots,
    );
  });
}
