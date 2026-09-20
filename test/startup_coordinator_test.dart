import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/startup_coordinator.dart';

void main() {
  const coordinator = StartupCoordinator();

  test('起動処理を既存の依存順で実行する', () async {
    final calls = <String>[];

    Future<void> step(String name) async {
      calls.add(name);
    }

    await coordinator.run(
      ensureCloudUser: () => step('ensureCloudUser'),
      loadDisplayName: () => step('loadDisplayName'),
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
      loadMyEventRank: () => step('loadMyEventRank'),
      loadLevelProgress: () => step('loadLevelProgress'),
    );

    expect(calls, <String>[
      'ensureCloudUser',
      'loadDisplayName',
      'loadCurrentEvent',
      'loadEventAchievements',
      'startCollectionSync',
      'loadSeichi',
      'applyCollectedRows',
      'mergeCloudCollectionHistory',
      'loadManualNextDestination',
      'loadRecommendedRoute',
      'restoreRecommendedRouteDestination',
      'loadMyEventRank',
      'loadLevelProgress',
    ]);
  });

  test('失敗した処理より後ろは実行しない', () async {
    final calls = <String>[];

    await expectLater(
      coordinator.run(
        ensureCloudUser: () async => calls.add('ensureCloudUser'),
        loadDisplayName: () async => calls.add('loadDisplayName'),
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
        loadMyEventRank: () async => calls.add('loadMyEventRank'),
        loadLevelProgress: () async => calls.add('loadLevelProgress'),
      ),
      throwsStateError,
    );

    expect(calls, <String>[
      'ensureCloudUser',
      'loadDisplayName',
      'loadCurrentEvent',
    ]);
  });
}
