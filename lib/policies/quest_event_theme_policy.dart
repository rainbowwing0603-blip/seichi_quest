import 'package:flutter/material.dart';

import '../models/event.dart';
import '../widgets/quest_ui.dart';

/// Event-level visual overrides. Today these resolve to the shared Quest
/// palette; keeping the boundary explicit lets future collaborations add
/// event-specific branding without branching inside common widgets.
class QuestEventTheme {
  const QuestEventTheme({
    required this.primary,
    required this.primaryDeep,
    required this.accent,
  });

  final Color primary;
  final Color primaryDeep;
  final Color accent;

  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[primary, primaryDeep],
      );
}

class QuestEventThemePolicy {
  const QuestEventThemePolicy();

  static const QuestEventTheme sharedTheme = QuestEventTheme(
    primary: QuestUiTokens.primary,
    primaryDeep: QuestUiTokens.primaryDeep,
    accent: QuestUiTokens.cyan,
  );

  QuestEventTheme resolve(Event event) {
    return QuestEventTheme(
      primary: _parseHex(event.themePrimaryHex) ?? sharedTheme.primary,
      primaryDeep:
          _parseHex(event.themePrimaryDeepHex) ?? sharedTheme.primaryDeep,
      accent: _parseHex(event.themeAccentHex) ?? sharedTheme.accent,
    );
  }

  Color? _parseHex(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final normalized = raw.startsWith('#') ? raw.substring(1) : raw;
    if (normalized.length != 6 && normalized.length != 8) return null;

    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return null;

    final argb = normalized.length == 6 ? 0xFF000000 | parsed : parsed;
    return Color(argb);
  }
}
