import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final androidGranted =
        await androidPlugin?.requestNotificationsPermission();

    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    final iosGranted =
        await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (iosGranted != null) {
      return iosGranted;
    }

    return androidGranted ?? true;
  }

  Future<void> showStampCollected({
    required String seichiName,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'stamp_collection',
      '聖地クエスト',
      channelDescription: '聖地獲得などのお知らせ',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: 1001,
      title: '聖地を獲得しました！',
      body: '$seichiName の聖地を獲得しました。',
      notificationDetails: details,
    );
  }
}