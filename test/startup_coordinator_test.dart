import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/startup_coordinator.dart';

void main() {
  const coordinator = StartupCoordinator();

  test('起動必須処理を既存の依存順で実行する', () async {
    final calls = <String>[];

    Future<void> step(String name) async {
      calls.add(name);
    }

    await coordinator.runCritical(
      ensureCloudUser: () => step('ensureCloudUser'),
      loadCurrentEvent: () => step('loadCurrentEvent'),
      loadEventAchievements: () => step('loadEventAchievements'),
      startCollectionSync: () async {
        calls.add('startCollectionSync');
        return <Map<String, dynamic>>[
          <String, dynamic>{'card': 'あ'},
        ];
      },
      loadSeichi: () => step('loadSeichi'),
      applyCollectedRows: (rows) async {
        expect(rows.single['card'], 'あ');
        calls.add('applyCollectedRows');
      },
      mergeCloudCollectionHistory: () => step('mergeCloudCollectionHistory'),
      loadManualNextDestination: () => step('loadManualNextDestination'),
      loadRecommendedRoute: () => step('loadRecommendedRoute'),
      restoreRecommendedRouteDestination: () {
        calls.add('restoreRecommendedRouteDestination');
      },
    );

    expect(calls, <String>[
      'ensureCloudUser',
      'loadCurrentEvent',
      'loadEventAchievements',
      'startCollectionSync',
      'loadSeichi',
      'applyCollectedRows',
      'mergeCloudCollectionHistory',
      'loadManualNextDestination',
      'loadRecommendedRoute',
      'restoreRecommendedRouteDestination',
    ]);
  });

  test('必須処理の失敗後は後続を実行しない', () async {
    final calls = <String>[];

    await expectLater(
      coordinator.runCritical(
        ensureCloudUser: () async => calls.add('ensureCloudUser'),
        loadCurrentEvent: () async {
          calls.add('loadCurrentEvent');
          throw StateError('event load failed');
        },
        loadEventAchievements: () async => calls.add('loadEventAchievements'),
        startCollectionSync: () async => <Map<String, dynamic>>[],
        loadSeichi: () async => calls.add('loadSeichi'),
        applyCollectedRows: (_) async => calls.add('applyCollectedRows'),
        mergeCloudCollectionHistory: () async =>
            calls.add('mergeCloudCollectionHistory'),
        loadManualNextDestination: () async =>
            calls.add('loadManualNextDestination'),
        loadRecommendedRoute: () async => calls.add('loadRecommendedRoute'),
        restoreRecommendedRouteDestination: () =>
            calls.add('restoreRecommendedRouteDestination'),
      ),
      throwsStateError,
    );

    expect(calls, <String>['ensureCloudUser', 'loadCurrentEvent']);
  });

  test('表示を塞がない補助データは並列取得する', () async {
    final started = <String>[];
    final gates = <String, Completer<void>>{
      'profile': Completer<void>(),
      'rank': Completer<void>(),
      'level': Completer<void>(),
    };

    final future = coordinator.runDeferred(
      loadDisplayName: () {
        started.add('profile');
        return gates['profile']!.future;
      },
      loadMyEventRank: () {
        started.add('rank');
        return gates['rank']!.future;
      },
      loadLevelProgress: () {
        started.add('level');
        return gates['level']!.future;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(started, <String>['profile', 'rank', 'level']);

    for (final gate in gates.values) {
      gate.complete();
    }

    await future;
  });
}
