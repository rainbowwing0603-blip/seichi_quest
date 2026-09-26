import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/announcement.dart';
import 'package:seichi_quest/widgets/announcement_carousel_dialog.dart';

void main() {
  testWidgets('swiping records only announcements actually shown', (tester) async {
    final viewed = <String>[];
    final announcements = List.generate(
      3,
      (index) => Announcement(
        id: 'notice-$index',
        title: 'お知らせ $index',
        body: '内容 $index',
        category: 'general',
        priority: 0,
        publishFrom: DateTime(2026, 9, 26),
        showOnStartup: true,
        isRead: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnouncementCarouselDialog(
            announcements: announcements,
            onViewed: viewed.add,
          ),
        ),
      ),
    );
    expect(viewed, ['notice-0']);

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(viewed, ['notice-0', 'notice-1']);
  });
}
