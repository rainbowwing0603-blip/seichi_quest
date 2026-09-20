import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/collection_display_policy.dart';

void main() {
  const policy = CollectionDisplayPolicy();

  test('札ごとにイベント名を重複なくまとめる', () {
    final result = policy.eventNamesByCard(<Map<String, dynamic>>[
      <String, dynamic>{'card': 'あ', 'event_name': 'イベントA'},
      <String, dynamic>{'card': 'あ', 'event_name': 'イベントA'},
      <String, dynamic>{'card': 'あ', 'event_name': 'イベントB'},
      <String, dynamic>{'card': 'い', 'event_name': 'イベントA'},
    ]);

    expect(result['あ'], <String>{'イベントA', 'イベントB'});
    expect(result['い'], <String>{'イベントA'});
  });

  test('表示に使えない履歴は除外する', () {
    final result = policy.eventNamesByCard(<Map<String, dynamic>>[
      <String, dynamic>{'card': '', 'event_name': 'イベントA'},
      <String, dynamic>{'card': 'あ', 'event_name': ''},
      <String, dynamic>{'card': null, 'event_name': 'イベントA'},
      <String, dynamic>{'card': 'い', 'event_name': null},
    ]);

    expect(result, isEmpty);
  });
}
