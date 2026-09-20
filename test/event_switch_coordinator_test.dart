import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/event_switch_coordinator.dart';

void main() {
  const coordinator = EventSwitchCoordinator();

  test('依存する同期処理は既存順序を維持する', () async {
    final calls = <String>[];

    await coordinator.run(
      loadEventAchievements: () async => calls.add('achievements'),
      startCollectionSync: () async => calls.add('sync'),
      loadSeichi: () async => calls.add('seichi'),
      applyPendingRows: () async => calls.add('apply'),
      mergeCloudHistory: () async => calls.add('merge'),
      loadManualNextDestination: () async => calls.add('manual'),
      loadRecommendedRoute: () async => calls.add('route'),
      loadMyEventRank: () async => calls.add('rank'),
      activateEvent: () async => calls.add('activate'),
    );

    expect(
      calls.take(5),
      <String>['achievements', 'sync', 'seichi', 'apply', 'merge'],
    );
    expect(calls.last, 'activate');
  });

  test('独立した復元処理は並列開始し全完了後にイベントを有効化する', () async {
    final started = <String>[];
    final manual = Completer<void>();
    final route = Completer<void>();
    final rank = Completer<void>();
    var activated = false;

    final future = coordinator.run(
      loadEventAchievements: () async {},
      startCollectionSync: () async {},
      loadSeichi: () async {},
      applyPendingRows: () async {},
      mergeCloudHistory: () async {},
      loadManualNextDestination: () {
        started.add('manual');
        return manual.future;
      },
      loadRecommendedRoute: () {
        started.add('route');
        return route.future;
      },
      loadMyEventRank: () {
        started.add('rank');
        return rank.future;
      },
      activateEvent: () async {
        activated = true;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(started, <String>['manual', 'route', 'rank']);
    expect(activated, isFalse);

    manual.complete();
    route.complete();
    rank.complete();
    await future;

    expect(activated, isTrue);
  });
}
