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

  /// Last error encountered while (re)scheduling the daily reminder.
  /// `null` when the most recent attempt succeeded. Surface this from
  /// the Settings screen so users can tell when their reminder isn't
  /// actually armed.
  String? lastScheduleError;

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

    // Pre-create the notification channel on Android so it shows up
    // in Samsung's Settings → Apps → Tadabbur → Notifications list
    // even before the first notification fires. Samsung sometimes
    // silently drops alarms from channels that were only auto-created
    // lazily by zonedSchedule.
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        const channel = AndroidNotificationChannel(
          'daily_ayah_v3',
          'Daily Ayah Reminder',
          description: 'Your daily ayah reminder',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await android.createNotificationChannel(channel);
        debugPrint('[NotificationService] channel daily_ayah_v3 created');

        // Verify exact alarms are actually permitted. On Android 12+
        // this requires SCHEDULE_EXACT_ALARM, which Samsung may revoke.
        try {
          final canExact = await android.canScheduleExactNotifications();
          debugPrint(
            '[NotificationService] canScheduleExactNotifications: $canExact',
          );
        } catch (e) {
          debugPrint(
            '[NotificationService] canScheduleExactNotifications check failed: $e',
          );
        }
      }
    }

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

    final scheduledTime = _nextInstanceOfTime(hour, minute);
    debugPrint(
      '[NotificationService] Scheduling daily at: $scheduledTime '
      '(local tz: ${tz.local.name})',
    );

    const notifDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'daily_ayah_v3',
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

    // Samsung's "Put unused apps to sleep" kills alarms scheduled
    // with exactAllowWhileIdle + matchDateTimeComponents before their
    // BroadcastReceiver can fire, so the notification never posts.
    // `alarmClock` mode registers the alarm at the system alarm-clock
    // level (same API used by the actual Alarm Clock app), which
    // survives battery optimization.
    //
    // alarmClock is one-shot only (combining it with
    // matchDateTimeComponents crashes flutter_local_notifications
    // 18.x). We work around that by rescheduling on every app launch
    // via `ensureDailyScheduled()` — if the stored notification time
    // exists and no future alarm is pending, we re-arm it for the
    // next occurrence.
    try {
      await _plugin.zonedSchedule(
        0,
        msg.title,
        msg.body,
        scheduledTime,
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      lastScheduleError = null;
      debugPrint('[NotificationService] zonedSchedule (alarmClock) returned');
    } catch (e, st) {
      lastScheduleError = e.toString();
      debugPrint(
        '[NotificationService] zonedSchedule FAILED: $e\n$st',
      );
      rethrow;
    }

    // Verify the scheduled notification was actually registered with
    // the OS. If this list is empty after scheduling, the schedule
    // call silently failed — usually a permission or channel issue.
    try {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint(
        '[NotificationService] Pending notifications after schedule: '
        '${pending.length} — IDs: ${pending.map((p) => p.id).toList()}',
      );
      for (final p in pending) {
        debugPrint(
          '[NotificationService]   - id=${p.id} title=${p.title} body=${p.body}',
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] pendingNotificationRequests failed: $e');
    }
  }

  /// Schedule a one-shot test notification [seconds] from now.
  /// Used to verify the whole pipeline (permissions, channels, alarms)
  /// without waiting for tomorrow morning. Call from a settings debug
  /// button or a dev action.
  Future<void> scheduleTestNotification({int seconds = 60}) async {
    await init();
    final fireAt =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    debugPrint(
      '[NotificationService] Test notification scheduled for: $fireAt',
    );

    try {
      await _plugin.zonedSchedule(
        99,
        'Tadabbur test',
        'If you see this, notifications are working.',
        fireAt,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          android: AndroidNotificationDetails(
            'daily_ayah_v3',
            'Daily Ayah Reminder',
            channelDescription: 'Your daily ayah reminder',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
        '[NotificationService] Test notification scheduled — expect it in ${seconds}s',
      );
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint(
        '[NotificationService] Pending after test schedule: ${pending.length}',
      );
    } catch (e, st) {
      debugPrint('[NotificationService] test schedule FAILED: $e\n$st');
    }
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

  /// Re-arms the daily reminder on app launch. Call from main.dart
  /// after services are initialized.
  ///
  /// We use `AndroidScheduleMode.alarmClock` for the daily reminder
  /// because it's the only mode Samsung reliably fires after the app
  /// is backgrounded. alarmClock is one-shot (can't combine with
  /// `matchDateTimeComponents`), so every app launch we look at the
  /// stored notification time and, if there's no pending alarm yet
  /// (or the last one already fired), schedule the next occurrence.
  Future<void> ensureDailyScheduled() async {
    await init();
    final scheduled = getScheduledTime();
    if (scheduled == null) {
      debugPrint('[NotificationService] ensureDailyScheduled: none set');
      return;
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      final hasDaily = pending.any((p) => p.id == 0);
      if (hasDaily) {
        debugPrint(
          '[NotificationService] ensureDailyScheduled: daily already pending',
        );
        return;
      }
    } catch (e) {
      debugPrint(
        '[NotificationService] ensureDailyScheduled: check failed: $e',
      );
    }

    debugPrint(
      '[NotificationService] ensureDailyScheduled: re-arming daily at '
      '${scheduled.hour}:${scheduled.minute}',
    );
    // Re-run the scheduling logic without blowing away the stored
    // preference or showing the "Reminder set" confirmation toast
    // again. We just quietly re-post the zonedSchedule.
    final scheduledTime =
        _nextInstanceOfTime(scheduled.hour, scheduled.minute);
    final totalAyat = _storage.getProgress()?.totalAyatCompleted ?? 0;
    final msg = getMessageForDay(totalAyat + 1);

    const notifDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'daily_ayah_v3',
        'Daily Ayah Reminder',
        channelDescription: 'Your daily ayah reminder',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        0,
        msg.title,
        msg.body,
        scheduledTime,
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      lastScheduleError = null;
      debugPrint(
        '[NotificationService] ensureDailyScheduled: re-armed for $scheduledTime',
      );
    } catch (e) {
      lastScheduleError = e.toString();
      debugPrint(
        '[NotificationService] ensureDailyScheduled: re-arm failed: $e',
      );
    }
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

  /// Identity-based notification messages — reinforce the habit, not the app.
  ({String title, String body}) getMessageForDay(int dayNumber,
      {String? theme}) {
    final themeHook =
        theme != null ? ' Today\'s ayah is about $theme.' : '';

    // Milestone days — celebrate identity
    switch (dayNumber) {
      case 1:
        return (
          title: 'Tadabbur',
          body: 'Your first ayah is waiting.$themeHook',
        );
      case 2:
        return (
          title: 'Day 2',
          body: 'You came back. That matters.$themeHook',
        );
      case 3:
        return (
          title: 'Day 3',
          body: 'You\'re building something.$themeHook',
        );
      case 7:
        return (
          title: 'One week',
          body: 'Seven days. You\'re someone who shows up.$themeHook',
        );
      case 14:
        return (
          title: 'Two weeks',
          body: 'This is becoming part of who you are.$themeHook',
        );
      case 30:
        return (
          title: 'Day 30',
          body: 'A month of showing up. This is you now.$themeHook',
        );
      case 100:
        return (
          title: 'Day 100',
          body: '100 days with the Quran. SubhanAllah.$themeHook',
        );
      case 365:
        return (
          title: 'One year',
          body: 'Your spiritual autobiography.$themeHook',
        );
    }

    // Identity-reinforcing messages for regular days
    if (dayNumber > 30) {
      final messages = [
        'Day $dayNumber. You\'re consistent.',
        'Your ayah is ready. You always show up.',
        'Day $dayNumber with the Quran.',
      ];
      return (
        title: 'Tadabbur',
        body: messages[dayNumber % messages.length] + themeHook,
      );
    }

    if (dayNumber > 7) {
      final messages = [
        'Day $dayNumber. Keep going.',
        'Your next ayah is waiting for you.',
        'Day $dayNumber. You\'re building a habit.',
      ];
      return (
        title: 'Tadabbur',
        body: messages[dayNumber % messages.length] + themeHook,
      );
    }

    // First week — gentle encouragement
    final messages = [
      'Your ayah for today is waiting.',
      'A quiet moment with the Quran.',
      'Sit with today\'s ayah.',
    ];
    return (
      title: 'Tadabbur',
      body: messages[dayNumber % messages.length] + themeHook,
    );
  }
}
