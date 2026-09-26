import 'package:flutter/material.dart';

import '../widgets/quest_ui.dart';

enum QuestParticipationState {
  selected,
  participating,
  previous,
  notParticipating,
}

class QuestEventPresentation {
  const QuestEventPresentation({
    required this.state,
    required this.label,
    required this.color,
    required this.icon,
    required this.primaryActionLabel,
  });

  final QuestParticipationState state;
  final String label;
  final Color color;
  final IconData icon;
  final String? primaryActionLabel;
}

/// Centralizes event participation presentation so pages do not encode the
/// same label/color/icon/action rules independently.
class QuestEventPresentationPolicy {
  const QuestEventPresentationPolicy();

  QuestEventPresentation resolve({
    required bool isSelected,
    required bool hasParticipationRecord,
    required bool isParticipating,
  }) {
    if (isSelected) {
      return const QuestEventPresentation(
        state: QuestParticipationState.selected,
        label: '選択中',
        color: QuestUiTokens.primary,
        icon: Icons.check_circle,
        primaryActionLabel: null,
      );
    }

    if (isParticipating) {
      return const QuestEventPresentation(
        state: QuestParticipationState.participating,
        label: '参加中',
        color: QuestUiTokens.success,
        icon: Icons.flag_outlined,
        primaryActionLabel: 'このクエストを選ぶ',
      );
    }

    if (hasParticipationRecord) {
      return const QuestEventPresentation(
        state: QuestParticipationState.previous,
        label: '過去に参加',
        color: QuestUiTokens.warning,
        icon: Icons.history_outlined,
        primaryActionLabel: '再参加して選ぶ',
      );
    }

    return const QuestEventPresentation(
      state: QuestParticipationState.notParticipating,
      label: '未参加',
      color: QuestUiTokens.neutral,
      icon: Icons.add_circle_outline,
      primaryActionLabel: '参加して選ぶ',
    );
  }

  QuestEventPresentation fromLabel(String label) {
    switch (label) {
      case '選択中':
        return resolve(
          isSelected: true,
          hasParticipationRecord: true,
          isParticipating: true,
        );
      case '参加中':
        return resolve(
          isSelected: false,
          hasParticipationRecord: true,
          isParticipating: true,
        );
      case '過去に参加':
        return resolve(
          isSelected: false,
          hasParticipationRecord: true,
          isParticipating: false,
        );
      default:
        return resolve(
          isSelected: false,
          hasParticipationRecord: false,
          isParticipating: false,
        );
    }
  }
}
