import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  AppSettingsService({SharedPreferences? preferences})
      : _providedPreferences = preferences;

  final SharedPreferences? _providedPreferences;

  Future<SharedPreferences> _preferences() async {
    return _providedPreferences ?? SharedPreferences.getInstance();
  }

  Future<bool> isAutoNextDestinationEnabled() async {
    final preferences = await _preferences();
    return preferences.getBool('setting_auto_next_destination') ?? true;
  }

  Future<bool> isStampNotificationEnabled() async {
    final preferences = await _preferences();
    return preferences.getBool('setting_stamp_notification') ?? true;
  }
}
