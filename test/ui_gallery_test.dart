import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/quest_item.dart';
import 'package:seichi_quest/widgets/app_settings_page.dart';
import 'package:seichi_quest/widgets/collection_page.dart';
import 'package:seichi_quest/widgets/my_page.dart';
import 'package:seichi_quest/widgets/onboarding_page.dart';
import 'package:seichi_quest/widgets/quest_page.dart';
import 'package:seichi_quest/widgets/quest_spot_detail_sheet.dart';
import 'package:seichi_quest/widgets/quest_ui.dart';
import 'package:seichi_quest/widgets/sync_status_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const screenshotKey = Key('ui-gallery-capture');
  const item = QuestItem(
    id: 'demo',
    eventContentId: 'demo',
    contentId: '',
    placeId: 'demo-place',
    contentKey: 'け',
    title: '群馬県庁',
    latitude: 36.391,
    longitude: 139.060,
    radiusMeters: 200,
    description: '群馬県庁の説明',
    icon: '🏢',
    displayOrder: 1,
    isActive: true,
    contentMetadata: <String, dynamic>{'card': 'け', 'reading': 'け'},
  );

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(screenshotKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('Unable to render $name');
    final file = File('build/ui_gallery/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List());
  }

  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotKey,
        child: MaterialApp(
          theme: questTheme(),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('render representative screens at phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    void noop() {}
    Future<void> asyncNoop() async {}

    await show(
      tester,
      MyPage(
        displayName: 'テストユーザー',
        avatarKey: null,
        myRank: 3,
        levelProgress: null,
        eventAchievements: const [],
        count: 1,
        total: 44,
        currentEventName: '上毛かるた',
        nextDestinationName: '群馬県庁',
        nextDestinationIcon: '🏢',
        nextDestinationDistance: 1200,
        onShowNextDestination: noop,
        onShowAchievements: noop,
        onShowRanking: noop,
        onShowAdventureLog: noop,
        onShowSyncStatus: noop,
        onShowProfile: noop,
        onShowAccount: noop,
        onShowNotifications: noop,
        onShowAnnouncements: noop,
        unreadAnnouncementCount: 2,
        onShowSettings: noop,
        onShowAbout: noop,
      ),
    );
    await capture(tester, 'my_page');

    await show(
      tester,
      QuestPage(
        nextSeichi: item,
        nextDistance: 1200,
        collectedCount: 1,
        total: 44,
        eventAchievements: const [],
        onShowDestination: noop,
        onExploreEvents: noop,
      ),
    );
    await capture(tester, 'quest_page');

    await show(
      tester,
      CollectionPage(
        eventId: 'demo-event',
        seichiList: const [item],
        collectedIds: const {},
        eventNamesByContentKey: const {},
        collectionFilter: 0,
        onFilterChanged: (_) {},
        onMoveToSeichi: (_) async {},
        onSetNextDestination: (_) {},
      ),
    );
    await capture(tester, 'collection_page');

    await show(
      tester,
      const QuestSpotDetailSheet(item: item, collected: false),
    );
    await capture(tester, 'spot_detail');

    await show(
      tester,
      SyncStatusPage(loadPendingCount: () async => 2, syncNow: () async => 0),
    );
    await capture(tester, 'sync_status');

    await show(
      tester,
      AppSettingsPage(
        onResetEventCollectionHistory: asyncNoop,
        onTestQuestComplete: asyncNoop,
        onTestRecommendedRouteNext: asyncNoop,
        onShowOnboarding: asyncNoop,
      ),
    );
    await capture(tester, 'settings');

    await show(tester, OnboardingPage(onComplete: asyncNoop));
    await capture(tester, 'onboarding');
  });
}
