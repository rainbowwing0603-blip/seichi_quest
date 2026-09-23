import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/account_refresh_coordinator.dart';

void main() {
  const coordinator = AccountRefreshCoordinator();

  test('同期依存処理の順序を維持する', () async {
    final calls = <String>[];

    await coordinator.run(
      ensureCloudUser: () async => calls.add('user'),
      resetDestinationState: () async => calls.add('reset'),
      loadDisplayName: () async => calls.add('profile'),
      loadEventAchievements: () async => calls.add('achievements'),
      startCollectionSync: () async => calls.add('sync'),
      applyPendingRows: () async => calls.add('apply'),
      mergeCloudHistory: () async => calls.add('merge'),
      loadManualNextDestination: () async => calls.add('manual'),
      loadRecommendedRoute: () async => calls.add('route'),
      loadMyEventRank: () async => calls.add('rank'),
      finish: () async => calls.add('finish'),
    );

    expect(
      calls.where(
        (call) => <String>{
          'user',
          'reset',
          'achievements',
          'sync',
          'apply',
          'merge',
          'finish',
        }.contains(call),
      ),
      <String>[
        'user',
        'reset',
        'achievements',
        'sync',
        'apply',
        'merge',
        'finish',
      ],
    );
  });

  test('プロフィールと復元系処理を待てる範囲で並列化する', () async {
    final profile = Completer<void>();
    final manual = Completer<void>();
    final route = Completer<void>();
    final rank = Completer<void>();
    final started = <String>[];
    var finished = false;

    final future = coordinator.run(
      ensureCloudUser: () async {},
      resetDestinationState: () async {},
      loadDisplayName: () {
        started.add('profile');
        return profile.future;
      },
      loadEventAchievements: () async {},
      startCollectionSync: () async {},
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
      finish: () async {
        finished = true;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(started, contains('profile'));

    profile.complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, containsAll(<String>['manual', 'route', 'rank']));
    expect(finished, isFalse);

    manual.complete();
    route.complete();
    rank.complete();
    await future;

    expect(finished, isTrue);
  });
}
