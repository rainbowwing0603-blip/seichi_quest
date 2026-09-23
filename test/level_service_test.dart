import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/level_service.dart';

void main() {
  const service = LevelService();

  group('LevelService XP計算', () {
    test('聖地獲得数からXPを計算できる', () {
      expect(service.xpFromCollectedCount(0), 0);
      expect(service.xpFromCollectedCount(1), 100);
      expect(service.xpFromCollectedCount(3), 300);
      expect(service.xpFromCollectedCount(7), 700);
      expect(service.xpFromCollectedCount(12), 1200);
    });

    test('負の獲得数は0XPとして扱う', () {
      expect(service.xpFromCollectedCount(-1), 0);
    });
  });

  group('LevelService レベル境界', () {
    test('各レベルに必要な累計XPが正しい', () {
      expect(service.xpRequiredForLevel(1), 0);
      expect(service.xpRequiredForLevel(2), 300);
      expect(service.xpRequiredForLevel(3), 700);
      expect(service.xpRequiredForLevel(4), 1200);
      expect(service.xpRequiredForLevel(5), 1800);
      expect(service.xpRequiredForLevel(6), 2500);
    });

    test('XPからレベルを正しく判定できる', () {
      expect(service.levelFromXp(0), 1);
      expect(service.levelFromXp(299), 1);

      expect(service.levelFromXp(300), 2);
      expect(service.levelFromXp(699), 2);

      expect(service.levelFromXp(700), 3);
      expect(service.levelFromXp(1199), 3);

      expect(service.levelFromXp(1200), 4);
      expect(service.levelFromXp(1799), 4);

      expect(service.levelFromXp(1800), 5);
    });
  });

  group('LevelService 進捗計算', () {
    test('Lv.2の途中経過を正しく計算できる', () {
      final progress = service.progressFromXp(500);

      expect(progress.totalXp, 500);
      expect(progress.level, 2);
      expect(progress.currentLevelXp, 300);
      expect(progress.nextLevelXp, 700);
      expect(progress.xpIntoLevel, 200);
      expect(progress.xpNeededForNextLevel, 400);
      expect(progress.progress, 0.5);
    });

    test('負のXPは0XPとして扱う', () {
      final progress = service.progressFromXp(-100);

      expect(progress.totalXp, 0);
      expect(progress.level, 1);
      expect(progress.progress, 0.0);
    });
  });
}
