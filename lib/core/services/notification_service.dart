import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:tadabbur/core/services/local_storage_service.dart';

class NotificationService {
  final LocalStorageService _storage;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  NotificationService(this._storage);

  /// Initialize the notification plugin and timezone data.
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Request notification permissions (iOS).
  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true; // Android doesn't need runtime permission for basic notifications
  }

  /// Schedule a daily notification at the given hour and minute.
  /// Cancels any existing scheduled notification first.
  Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
  }) async {
    await init();

    // Save preference
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    await _storage.setNotificationTime(timeStr);

    // Cancel existing
    await _plugin.cancelAll();

    // Get the message for today
    final totalAyat = _storage.getProgress()?.totalAyatCompleted ?? 0;
    final msg = getMessageForDay(totalAyat + 1);

    // Schedule daily
    await _plugin.zonedSchedule(
      0, // notification ID
      msg.title,
      msg.body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          'daily_ayah',
          'Daily Ayah',
          channelDescription: 'Your daily ayah reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  /// Get the next occurrence of the given time.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
    await _storage.setNotificationTime('');
  }

  /// Get the stored notification time as (hour, minute), or null if not set.
  ({int hour, int minute})? getScheduledTime() {
    final timeStr = _storage.notificationTime;
    if (timeStr == null || timeStr.isEmpty || !timeStr.contains(':')) {
      return null;
    }
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }

  /// Day-specific notification messages.
  ({String title, String body}) getMessageForDay(int dayNumber,
      {String? theme}) {
    final themeHook =
        theme != null ? ' Today\'s ayah is about $theme.' : '';

    switch (dayNumber) {
      case 1:
        return (
          title: 'Tadabbur',
          body: 'Your ayah for today is waiting.$themeHook',
        );
      case 2:
        return (
          title: 'Tadabbur',
          body: 'Yesterday you started. Today you continue.$themeHook',
        );
      case 3:
        return (
          title: 'Tadabbur',
          body: 'Sit with today\'s ayah for a moment.$themeHook',
        );
      case 7:
        return (
          title: 'One week',
          body: '7 ayat. You\'ve built something real.$themeHook',
        );
      case 30:
        return (
          title: 'Day 30',
          body: 'This is a habit now.$themeHook',
        );
      default:
        final messages = [
          'Your ayah for today is waiting.',
          'Sit with today\'s ayah.',
          'A moment with the Quran awaits.',
          'Your daily ayah is ready.',
        ];
        return (
          title: 'Tadabbur',
          body: messages[dayNumber % messages.length] + themeHook,
        );
    }
  }
}
