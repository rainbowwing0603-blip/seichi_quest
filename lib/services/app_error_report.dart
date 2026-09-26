import 'app_logger.dart';

/// 問い合わせ時に画面と開発ログを対応付ける固定コード。
/// 番号は変更・再利用せず、新しい失敗箇所には新しい番号を割り当てる。
abstract final class AppErrorCodes {
  static const startup = 'SQ-START-01';
  static const spots = 'SQ-MAP-01';
  static const locationDisabled = 'SQ-GPS-01';
  static const locationDenied = 'SQ-GPS-02';
  static const locationDeniedForever = 'SQ-GPS-03';
  static const locationUnavailable = 'SQ-GPS-04';
  static const locationStream = 'SQ-GPS-05';
  static const eventSwitch = 'SQ-EVENT-01';
  static const ranking = 'SQ-RANK-01';
  static const announcements = 'SQ-NEWS-01';
  static const syncStatus = 'SQ-SYNC-01';
  static const syncRetry = 'SQ-SYNC-02';
  static const adventureLog = 'SQ-LOG-01';
  static const profileLoad = 'SQ-PROFILE-01';
  static const profileSave = 'SQ-PROFILE-02';
  static const eventDetail = 'SQ-DETAIL-01';
  static const eventExplore = 'SQ-EVENT-02';
  static const resetHistory = 'SQ-SYNC-03';
  static const accountAuth = 'SQ-AUTH-01';
  static const weatherFetch = 'SQ-WEATHER-01';
}

abstract final class AppErrorReport {
  static String message(
    String code,
    String description, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (error != null) {
      appDebugPrint('[$code] $error${stackTrace == null ? '' : '\n$stackTrace'}');
    }
    return '$description\nエラーコード: $code';
  }
}
