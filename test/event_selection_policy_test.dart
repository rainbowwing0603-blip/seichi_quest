import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/models/event.dart';
import 'package:seichi_quest/services/event_selection_policy.dart';

void main() {
  Event event(String id, String slug) {
    return Event(
      id: id,
      slug: slug,
      name: id,
      description: '',
      isActive: true,
    );
  }

  group('EventSelectionPolicy', () {
    test('保存済みイベントを最優先する', () {
      final events = [
        event('jomo', 'jomo-karuta-gunma'),
        event('saved', 'another-event'),
      ];

      expect(
        EventSelectionPolicy.select(
          events: events,
          savedEventId: 'saved',
        ).id,
        'saved',
      );
    });

    test('保存済みIDが無効なら上毛かるたを選ぶ', () {
      final events = [
        event('other', 'another-event'),
        event('jomo', 'jomo-karuta-gunma'),
      ];

      expect(
        EventSelectionPolicy.select(
          events: events,
          savedEventId: 'missing',
        ).id,
        'jomo',
      );
    });

    test('上毛かるたもなければ先頭を選ぶ', () {
      final events = [
        event('first', 'first-event'),
        event('second', 'second-event'),
      ];

      expect(
        EventSelectionPolicy.select(events: events).id,
        'first',
      );
    });

    test('イベントが空なら従来どおりエラーにする', () {
      expect(
        () => EventSelectionPolicy.select(events: const <Event>[]),
        throwsException,
      );
    });
  });
}
