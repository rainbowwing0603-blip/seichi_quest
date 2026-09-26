import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/widgets/quest_ui.dart';

void main() {
  group('QuestUiTokens', () {
    test('keeps the established MAP UI palette stable', () {
      expect(QuestUiTokens.primary, const Color(0xFF5968E8));
      expect(QuestUiTokens.primaryDeep, const Color(0xFF403A9F));
      expect(QuestUiTokens.cyan, const Color(0xFF25A9C7));
      expect(QuestUiTokens.ink, const Color(0xFF102A43));
      expect(QuestUiTokens.mutedInk, const Color(0xFF60758A));
      expect(QuestUiTokens.success, const Color(0xFF2BAA76));
      expect(QuestUiTokens.warning, const Color(0xFFE49B35));
      expect(QuestUiTokens.danger, const Color(0xFFD94B5B));
      expect(QuestUiTokens.neutral, const Color(0xFF7A8794));
    });

    test('shared theme is built from the common primary token', () {
      final theme = buildQuestTheme();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, isNot(equals(Colors.transparent)));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF7F5FB));
      expect(theme.progressIndicatorTheme.color, QuestUiTokens.primary);
    });
  });
}
