import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seichi_quest/services/story_preview_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late String user;
  late StoryPreviewService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 10, 5);
    user = 'alice';
    service = StoryPreviewService(serverTime: () async => now, userId: () => user);
  });
  test('preview expires at exactly one server hour and survives reopening', () async {
    await service.grant('story', expectedUserId: 'alice');
    now = now.add(const Duration(minutes: 59));
    final reopened = StoryPreviewService(serverTime: () async => now, userId: () => user);
    expect(await reopened.remaining('story'), isNotNull);
    now = now.add(const Duration(minutes: 1));
    expect(await reopened.remaining('story'), isNull);
  });
  test('preview is isolated by account and content', () async {
    await service.grant('story', expectedUserId: 'alice');
    expect(await service.remaining('other'), isNull);
    user = 'bob';
    expect(await service.remaining('story'), isNull);
    await expectLater(service.grant('story', expectedUserId: 'alice'), throwsStateError);
  });
  test('server failure never grants a preview', () async {
    final failing = StoryPreviewService(serverTime: () async => throw StateError('offline'), userId: () => user);
    await expectLater(failing.grant('story', expectedUserId: 'alice'), throwsStateError);
    expect(await service.remaining('story'), isNull);
  });
}
