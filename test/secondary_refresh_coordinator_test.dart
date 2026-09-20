import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/secondary_refresh_coordinator.dart';

void main() {
  const coordinator = SecondaryRefreshCoordinator();

  test('獲得後の独立した補助更新を並列開始する', () async {
    final started = <String>[];
    final gates = <String, Completer<void>>{
      'history': Completer<void>(),
      'rank': Completer<void>(),
      'level': Completer<void>(),
    };

    final future = coordinator.refreshAfterCollection(
      loadCollectionEventNames: () {
        started.add('history');
        return gates['history']!.future;
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
    expect(started, <String>['history', 'rank', 'level']);

    for (final gate in gates.values) {
      gate.complete();
    }

    await future;
  });

  test('プロフィールと順位を並列更新する', () async {
    final started = <String>[];
    final profileGate = Completer<void>();
    final rankGate = Completer<void>();

    final future = coordinator.refreshProfileAndRank(
      loadDisplayName: () {
        started.add('profile');
        return profileGate.future;
      },
      loadMyEventRank: () {
        started.add('rank');
        return rankGate.future;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(started, <String>['profile', 'rank']);

    profileGate.complete();
    rankGate.complete();
    await future;
  });
}
