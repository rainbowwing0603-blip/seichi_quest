import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/startup_coordinator.dart';

void main() {
  const coordinator = StartupCoordinator();

  test('起動必須処理は地図表示に必要なデータまでで完了する', () async {
    final calls = <String>[];

    Future<void> step(String name) async {
      calls.add(name);
    }

    final result = await coordinator.runCritical(
      ensureCloudUser: () => step('ensureCloudUser'),
      loadCurrentEvent: () => step('loadCurrentEvent'),
      startCollectionSync: () async {
        calls.add('startCollectionSync');
        return <Map<String, dynamic>>[
          <String, dynamic>{'card': 'あ'},
        ];
      },
      loadSeichi: () => step('loadSeichi'),
    );

    expect(result.pendingCollectedRows.single['card'], 'あ');
    expect(calls, <String>[
      'ensureCloudUser',
      'loadCurrentEvent',
      'startCollectionSync',
      'loadSeichi',
    ]);
  });

  test('起動必須処理の失敗後は後続を実行しない', () async {
    final calls = <String>[];

    await expectLater(
      coordinator.runCritical(
        ensureCloudUser: () async => calls.add('ensureCloudUser'),
        loadCurrentEvent: () async {
          calls.add('loadCurrentEvent');
          throw StateError('event load failed');
        },
        startCollectionSync: () async {
          calls.add('startCollectionSync');
          return <Map<String, dynamic>>[];
        },
        loadSeichi: () async => calls.add('loadSeichi'),
      ),
      throwsStateError,
    );

    expect(calls, <String>['ensureCloudUser', 'loadCurrentEvent']);
  });

  test('イベント確定後は獲得履歴とスポットを同時に読み込む', () async {
    final syncGate = Completer<List<Map<String, dynamic>>>();
    final spotGate = Completer<void>();
    final started = <String>[];

    final startup = coordinator.runCritical(
      ensureCloudUser: () async {},
      loadCurrentEvent: () async {},
      startCollectionSync: () {
        started.add('sync');
        return syncGate.future;
      },
      loadSeichi: () {
        started.add('spots');
        return spotGate.future;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(started, <String>['sync', 'spots']);
    syncGate.complete(<Map<String, dynamic>>[]);
    var completed = false;
    startup.then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    spotGate.complete();
    await startup;
    expect(completed, isTrue);
  });

  test('画面表示後の復元処理は既存の依存順を保つ', () async {
    final calls = <String>[];

    Future<void> step(String name) async {
      calls.add(name);
    }

    await coordinator.runPostRender(
      pendingCollectedRows: <Map<String, dynamic>>[
        <String, dynamic>{'card': 'あ'},
      ],
      loadEventAchievements: () => step('loadEventAchievements'),
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
      'applyCollectedRows',
      'mergeCloudCollectionHistory',
      'loadManualNextDestination',
      'loadRecommendedRoute',
      'restoreRecommendedRouteDestination',
      'loadEventAchievements',
    ]);
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
