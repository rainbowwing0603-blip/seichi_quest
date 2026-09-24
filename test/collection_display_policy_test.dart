import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/collection_display_policy.dart';

void main() {
  const policy = CollectionDisplayPolicy();

  test('contentKeyごとにイベント名を重複なくまとめる', () {
    final result = policy.eventNamesByContentKey(<Map<String, dynamic>>[
      <String, dynamic>{'content_key': 'spot-a', 'event_name': 'イベントA'},
      <String, dynamic>{'content_key': 'spot-a', 'event_name': 'イベントA'},
      <String, dynamic>{'content_key': 'spot-a', 'event_name': 'イベントB'},
      <String, dynamic>{'content_key': 'spot-b', 'event_name': 'イベントA'},
    ]);

    expect(result['spot-a'], <String>{'イベントA', 'イベントB'});
    expect(result['spot-b'], <String>{'イベントA'});
  });

  test('表示に使えない履歴は除外する', () {
    final result = policy.eventNamesByContentKey(<Map<String, dynamic>>[
      <String, dynamic>{'content_key': '', 'event_name': 'イベントA'},
      <String, dynamic>{'content_key': 'spot-a', 'event_name': ''},
      <String, dynamic>{'content_key': null, 'event_name': 'イベントA'},
      <String, dynamic>{'content_key': 'spot-b', 'event_name': null},
    ]);

    expect(result, isEmpty);
  });
}
