import 'package:shared_preferences/shared_preferences.dart';

/// 初回チュートリアルの永続化だけを担当する。
///
/// 画面遷移や位置情報初期化はUI層に残し、保存方式をMap画面から分離する。
class OnboardingService {
  OnboardingService({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String _completedKey = 'onboarding_completed_v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<bool> isCompleted() async {
    final preferences = await _prefs();
    return preferences.getBool(_completedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final preferences = await _prefs();
    final saved = await preferences.setBool(_completedKey, true);

    if (!saved) {
      throw StateError('チュートリアルの完了状態を保存できませんでした。');
    }
  }
}
