import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/event.dart';
import 'package:seichi_quest/policies/quest_event_theme_policy.dart';
import 'package:seichi_quest/widgets/quest_ui.dart';

void main() {
  const policy = QuestEventThemePolicy();

  Event event(
    String slug, {
    String? primary,
    String? primaryDeep,
    String? accent,
  }) => Event(
        id: 'event-$slug',
        slug: slug,
        name: 'テストイベント',
        description: '',
        isActive: true,
        themePrimaryHex: primary,
        themePrimaryDeepHex: primaryDeep,
        themeAccentHex: accent,
      );

  group('QuestEventThemePolicy', () {
    test('イベント種別に依存せず共通テーマへ安全にフォールバックする', () {
      for (final slug in <String>[
        'jomo-karuta',
        'michinoeki-japan',
        'anime-collaboration',
        'store-campaign',
      ]) {
        final theme = policy.resolve(event(slug));

        expect(theme.primary, QuestUiTokens.primary);
        expect(theme.primaryDeep, QuestUiTokens.primaryDeep);
        expect(theme.accent, QuestUiTokens.cyan);
      }
    });

    test('有効なイベント色を個別に解決できる', () {
      final theme = policy.resolve(
        event(
          'custom',
          primary: '#123456',
          primaryDeep: '234567',
          accent: '#80123456',
        ),
      );

      expect(theme.primary, const Color(0xFF123456));
      expect(theme.primaryDeep, const Color(0xFF234567));
      expect(theme.accent, const Color(0x80123456));
    });

    test('不正または空のイベント色は項目ごとに共通テーマへ戻す', () {
      final theme = policy.resolve(
        event(
          'partial',
          primary: 'not-a-color',
          primaryDeep: '  ',
          accent: '#ABCDEF',
        ),
      );

      expect(theme.primary, QuestUiTokens.primary);
      expect(theme.primaryDeep, QuestUiTokens.primaryDeep);
      expect(theme.accent, const Color(0xFFABCDEF));
    });

    test('共通テーマから一貫したグラデーションを生成する', () {
      final theme = policy.resolve(event('generic'));

      expect(
        theme.primaryGradient.colors,
        <Object>[QuestUiTokens.primary, QuestUiTokens.primaryDeep],
      );
    });
  });
}
