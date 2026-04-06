import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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

    // Set local timezone from device's native timezone (e.g. "Asia/Kolkata")
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('[NotificationService] Timezone: $tzName');
    } catch (e) {
      debugPrint('[NotificationService] Timezone detection failed: $e');
      // Fallback: match by UTC offset
      try {
        final offset = DateTime.now().timeZoneOffset;
        final match = tz.timeZoneDatabase.locations.values.where(
          (loc) => loc.currentTimeZone.offset == offset.inMilliseconds,
        );
        if (match.isNotEmpty) {
          tz.setLocalLocation(match.first);
          debugPrint('[NotificationService] Fallback tz: ${tz.local.name}');
        }
      } catch (_) {}
    }

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

  /// Request notification permissions (iOS + Android 13+).
  Future<bool> requestPermission() async {
    // iOS
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

    // Android 13+ needs POST_NOTIFICATIONS permission
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        // Also request exact alarms for reliable scheduling
        await android.requestExactAlarmsPermission();
        return granted ?? true;
      }
    }

    return true;
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

    // Get the message
    final totalAyat = _storage.getProgress()?.totalAyatCompleted ?? 0;
    final msg = getMessageForDay(totalAyat + 1);

    // First: show an immediate confirmation notification
    await _plugin.show(
      1,
      'Reminder set',
      'You\'ll receive your daily ayah at $timeStr',
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          'daily_ayah_v2',
          'Daily Ayah Reminder',
          channelDescription: 'Your daily ayah reminder',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.reminder,
          fullScreenIntent: false,
        ),
      ),
    );

    // Schedule using periodicallyShowWithDuration as a workaround for Samsung
    // Also schedule with zonedSchedule for other devices
    final scheduledTime = _nextInstanceOfTime(hour, minute);
    debugPrint('[NotificationService] Scheduling at: $scheduledTime (local tz: ${tz.local.name})');

    const notifDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'daily_ayah_v2',
        'Daily Ayah Reminder',
        channelDescription: 'Your daily ayah reminder',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        fullScreenIntent: false,
      ),
    );

    await _plugin.zonedSchedule(
      0,
      msg.title,
      msg.body,
      scheduledTime,
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Get the next occurrence of the given time.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    // Build from device's DateTime.now() to get correct local time
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    // Convert device local DateTime to TZDateTime
    return tz.TZDateTime.from(scheduled, tz.local);
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
