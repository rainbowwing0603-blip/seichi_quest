import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/widgets/quest_page.dart';
import 'package:seichi_quest/widgets/quest_ui.dart';

void main() {
  for (final state in [
    (total: 0, collected: 0, label: '準備中'),
    (total: 44, collected: 44, label: '完全制覇！'),
  ]) {
    testWidgets('QuestPage ${state.label} card fills content width', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestPage(
              nextSeichi: null,
              nextDistance: null,
              collectedCount: state.collected,
              total: state.total,
              eventAchievements: const [],
              onShowDestination: () {},
              onExploreEvents: () {},
            ),
          ),
        ),
      );

      final card = find.ancestor(
        of: find.text(state.label),
        matching: find.byType(QuestGlassCard),
      );
      expect(card, findsOneWidget);
      expect(tester.getSize(card).width, 358);
    });
  }
}
