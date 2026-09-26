import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/policies/quest_event_presentation_policy.dart';
import 'package:seichi_quest/widgets/quest_ui.dart';

void main() {
  const policy = QuestEventPresentationPolicy();

  group('QuestEventPresentationPolicy', () {
    test('現在選択中を最優先する', () {
      final value = policy.resolve(
        isSelected: true,
        hasParticipationRecord: true,
        isParticipating: true,
      );

      expect(value.state, QuestParticipationState.selected);
      expect(value.label, '選択中');
      expect(value.color, QuestUiTokens.primary);
      expect(value.primaryActionLabel, isNull);
    });

    test('参加中イベントには選択アクションを出す', () {
      final value = policy.resolve(
        isSelected: false,
        hasParticipationRecord: true,
        isParticipating: true,
      );

      expect(value.state, QuestParticipationState.participating);
      expect(value.label, '参加中');
      expect(value.color, QuestUiTokens.success);
      expect(value.primaryActionLabel, 'このクエストを選ぶ');
    });

    test('過去参加には再参加アクションを出す', () {
      final value = policy.resolve(
        isSelected: false,
        hasParticipationRecord: true,
        isParticipating: false,
      );

      expect(value.state, QuestParticipationState.previous);
      expect(value.label, '過去に参加');
      expect(value.color, QuestUiTokens.warning);
      expect(value.primaryActionLabel, '再参加して選ぶ');
    });

    test('未参加には参加アクションを出す', () {
      final value = policy.resolve(
        isSelected: false,
        hasParticipationRecord: false,
        isParticipating: false,
      );

      expect(value.state, QuestParticipationState.notParticipating);
      expect(value.label, '未参加');
      expect(value.color, QuestUiTokens.neutral);
      expect(value.primaryActionLabel, '参加して選ぶ');
    });

    test('既存ラベルから同じpresentationを復元できる', () {
      expect(
        policy.fromLabel('参加中').state,
        QuestParticipationState.participating,
      );
      expect(
        policy.fromLabel('過去に参加').state,
        QuestParticipationState.previous,
      );
      expect(
        policy.fromLabel('未知').state,
        QuestParticipationState.notParticipating,
      );
    });
  });
}
