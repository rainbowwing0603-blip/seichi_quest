import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/widgets/my_page.dart';
import 'package:seichi_quest/widgets/quest_ui.dart';

void main() {
  testWidgets('MyPage main cards fill the available content width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    void noop() {}

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyPage(
            displayName: 'テストユーザー',
            avatarKey: null,
            myRank: null,
            levelProgress: null,
            eventAchievements: const [],
            count: 0,
            total: 44,
            currentEventName: '上毛かるた',
            nextDestinationName: null,
            nextDestinationIcon: null,
            nextDestinationDistance: null,
            onShowNextDestination: noop,
            onShowAchievements: noop,
            onShowRanking: noop,
            onShowAdventureLog: noop,
            onShowSyncStatus: noop,
            onShowProfile: noop,
            onShowAccount: noop,
            onShowNotifications: noop,
            onShowAnnouncements: noop,
            unreadAnnouncementCount: 0,
            onShowSettings: noop,
            onShowLegal: noop,
            onShowAbout: noop,
          ),
        ),
      ),
    );

    for (final label in ['テストユーザー', '次の目的地を準備中', '実績', 'ランキング', '設定・管理']) {
      final card = find.ancestor(
        of: find.text(label),
        matching: find.byType(QuestGlassCard),
      );
      expect(card, findsOneWidget);
      expect(tester.getSize(card).width, 358);
    }
  });
}
