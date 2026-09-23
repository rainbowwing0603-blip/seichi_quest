import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seichi_quest/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsService', () {
    test('設定未保存時は両方とも有効', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = AppSettingsService();

      expect(await service.isAutoNextDestinationEnabled(), isTrue);
      expect(await service.isStampNotificationEnabled(), isTrue);
    });

    test('保存済み設定値を返す', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'setting_auto_next_destination': false,
        'setting_stamp_notification': false,
      });
      final service = AppSettingsService();

      expect(await service.isAutoNextDestinationEnabled(), isFalse);
      expect(await service.isStampNotificationEnabled(), isFalse);
    });
  });
}
