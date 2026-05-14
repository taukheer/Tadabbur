import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';

class NotificationService {
  final LocalStorageService _storage;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Last error encountered while (re)scheduling the daily reminder.
  /// `null` when the most recent attempt succeeded.
  String? lastScheduleError;

  NotificationService(this._storage);

  /// Initialize the notification plugin and timezone data.
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('[NotificationService] Timezone: $tzName');
    } catch (e) {
      debugPrint('[NotificationService] Timezone detection failed: $e');
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
      }
    }

    _initialized = true;
  }

  /// Check whether the OS will actually deliver notifications for this
  /// app. Returns `true` when permissions are granted (or unknown on
  /// platforms where the API doesn't expose state — we err on the side
  /// of "enabled" to avoid false banners), `false` when explicitly
  /// denied.
  ///
  /// Used by the home screen to show a soft "Notifications are off"
  /// banner so users who skipped/denied the permission prompt have a
  /// recovery path without digging into system settings blind.
  Future<bool> areNotificationsEnabled() async {
    await init();
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (android == null) return true;
        final enabled = await android.areNotificationsEnabled();
        return enabled ?? true;
      }
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (ios == null) return true;
        final settings = await ios.checkPermissions();
        // `isEnabled` is null on older iOS; treat as enabled.
        return settings?.isEnabled ?? true;
      }
    } catch (e) {
      debugPrint(
        '[NotificationService] areNotificationsEnabled failed: $e',
      );
    }
    return true;
  }

  /// Request notification permissions (iOS + Android 13+).
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

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        await android.requestExactAlarmsPermission();
        return granted ?? true;
      }
    }

    return true;
  }

  /// Schedule the daily reminder from scratch. Cancels any prior
  /// schedule, saves the preference, shows an immediate confirmation
  /// toast, and arms tomorrow's (or today's) reminder with fresh
  /// content based on the user's progress.
  Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
  }) async {
    await init();

    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    await _storage.setNotificationTime(timeStr);

    await _plugin.cancelAll();

    // Immediate confirmation toast so the user knows the reminder was
    // accepted. Uses the same channel as the scheduled alert.
    await _plugin.show(
      1,
      'Reminder set',
      'You\'ll receive your daily ayah at $timeStr',
      _notifDetails(
        body: 'You\'ll receive your daily ayah at $timeStr',
        bigText: 'You\'ll receive your daily ayah at $timeStr.',
      ),
    );

    await _armDaily(hour, minute);
  }

  /// Re-arm the daily reminder on app launch or after an ayah is
  /// completed. Safe to call as often as you want.
  ///
  /// Because `alarmClock` is a one-shot schedule mode (combining it
  /// with `matchDateTimeComponents` crashes flutter_local_notifications
  /// 18.x), we re-arm every app launch and every time the user's
  /// progress changes so the notification body stays fresh.
  ///
  /// When [forceReplace] is true any pending daily alarms are cancelled
  /// and re-scheduled — use this after a state change (e.g. user
  /// completed today's ayah) so future reminders reflect the new count
  /// and next ayah.
  Future<void> ensureDailyScheduled({bool forceReplace = false}) async {
    await init();
    final scheduled = getScheduledTime();
    if (scheduled == null) {
      return;
    }

    if (!forceReplace) {
      try {
        final pending = await _plugin.pendingNotificationRequests();
        // Check the first horizon slot. If it's present we assume the
        // full multi-day batch is intact and skip re-arming.
        final hasDaily = pending.any((p) => p.id == _dailyIdBase);
        if (hasDaily) {
          return;
        }
      } catch (e) {
        debugPrint(
          '[NotificationService] ensureDailyScheduled: check failed: $e',
        );
      }
    } else {
      await _cancelDailyBatch();
    }

    await _armDaily(scheduled.hour, scheduled.minute, silent: true);
  }

  /// Notification ID range for the daily reminder batch. We schedule
  /// [_dailyHorizonDays] alarms upfront (one per day) using IDs
  /// [_dailyIdBase] .. [_dailyIdBase] + [_dailyHorizonDays] - 1.
  ///
  /// Why pre-schedule: the OS one-shot alarm fires once and is then
  /// gone. If we relied solely on app-launch re-arming, a user who
  /// ignored Day 1's notification would receive nothing on Day 2+
  /// until they opened the app — silently dropping the daily cadence.
  /// Pre-scheduling 14 days of alarms (well under iOS's 64-pending
  /// cap) lets users miss up to two weeks without the reminder going
  /// dark. Each alarm carries the same body because Option B
  /// (user-paced progression) keeps `currentVerseKey` pinned until the
  /// user explicitly completes the verse — every "next" notification
  /// should point at the same unread verse, not auto-advance.
  static const int _dailyIdBase = 100;
  static const int _dailyHorizonDays = 14;

  Future<void> _cancelDailyBatch() async {
    for (var i = 0; i < _dailyHorizonDays; i++) {
      try {
        await _plugin.cancel(_dailyIdBase + i);
      } catch (_) {}
    }
    // Also cancel the legacy single-alarm id (0) from earlier builds
    // so migrating users don't end up with a stale duplicate.
    try {
      await _plugin.cancel(0);
    } catch (_) {}
  }

  /// Core scheduling primitive. Schedules [_dailyHorizonDays] daily
  /// alarms upfront, each at the user's chosen (hour, minute). All
  /// share the same body because Option B doesn't auto-advance the
  /// verse — re-arming happens when the user completes today's ayah,
  /// which cancels the batch and re-queues with the new verseKey.
  Future<void> _armDaily(int hour, int minute, {bool silent = false}) async {
    final progress = _storage.getProgress();
    final totalAyat = progress?.totalAyatCompleted ?? 0;
    final nextVerseKey = progress?.currentVerseKey ?? '1:1';
    final msg = buildMessage(dayNumber: totalAyat + 1, verseKey: nextVerseKey);

    if (!silent) {
      debugPrint(
        '[NotificationService] Arming $_dailyHorizonDays-day batch '
        'starting at $hour:$minute (local tz: ${tz.local.name}) '
        'for $nextVerseKey',
      );
    }

    try {
      final firstFire = _nextInstanceOfTime(hour, minute);
      for (var i = 0; i < _dailyHorizonDays; i++) {
        final fireTime = firstFire.add(Duration(days: i));
        await _plugin.zonedSchedule(
          _dailyIdBase + i,
          msg.title,
          msg.body,
          fireTime,
          _notifDetails(body: msg.body, bigText: msg.bigText),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      lastScheduleError = null;
    } catch (e, st) {
      lastScheduleError = e.toString();
      debugPrint('[NotificationService] _armDaily FAILED: $e\n$st');
      if (!silent) rethrow;
    }
  }

  /// Build the [NotificationDetails] used for both immediate and
  /// scheduled posts. The shade preview stays tight (single-line
  /// [body]) while [bigText] is revealed when the user pulls the
  /// notification down — giving the notification a real collapsed →
  /// expanded gradient rather than a wall of text in both states.
  NotificationDetails _notifDetails({
    required String body,
    required String bigText,
  }) {
    return NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: body,
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
        styleInformation: BigTextStyleInformation(bigText),
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(scheduled, tz.local);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
    await _storage.setNotificationTime('');
  }

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

  /// Build the daily reminder copy for the user's current progress.
  ///
  /// Returns three layers:
  /// - [title]: the notification headline. Always specific — either the
  ///   ayah reference ("At-Tur · 52:2") or a milestone hook ("One week
  ///   with the Quran"). Never the generic app name.
  /// - [body]: single-line shade preview. Short on purpose — the pull-
  ///   down card reveals the richer text.
  /// - [bigText]: the expanded body shown after the user pulls the
  ///   notification down. Two beats: the invitation + one line of
  ///   identity reinforcement.
  ///
  /// Copy principles: identity over instruction ("you're someone who
  /// returns" vs. "please come back"), specificity over vague prompts
  /// (the actual ayah reference vs. "your ayah"), and no trailing
  /// marketing — the tone is a quiet nudge, not an engagement push.
  ({String title, String body, String bigText}) buildMessage({
    required int dayNumber,
    required String verseKey,
  }) {
    final surahName = surahNameFromKey(verseKey);
    final ayahRef = '$surahName · $verseKey';

    // Milestones: the title carries the celebration, the body carries
    // the specific ayah so the two lines say different things.
    switch (dayNumber) {
      case 1:
        return (
          title: 'Your first ayah',
          body: 'Begin with $ayahRef',
          bigText: 'Begin with $ayahRef.\n\n'
              'One breath. One ayah. That\'s all this is.',
        );
      case 2:
        return (
          title: 'You came back',
          body: 'Day 2 · $ayahRef',
          bigText: 'Day 2 · $ayahRef.\n\n'
              'Coming back on day two is what makes a life of showing up.',
        );
      case 3:
        return (
          title: 'The habit is forming',
          body: 'Day 3 · $ayahRef',
          bigText: 'Day 3 · $ayahRef.\n\n'
              'This is how habits build — quietly, daily, no announcement.',
        );
      case 7:
        return (
          title: 'One week with the Quran',
          body: 'Day 7 · $ayahRef',
          bigText: 'Seven days of showing up.\n\n'
              'You\'re someone who returns. $ayahRef today.',
        );
      case 14:
        return (
          title: 'Two weeks — this is becoming you',
          body: 'Day 14 · $ayahRef',
          bigText: 'Day 14 · $ayahRef.\n\n'
              'This is who you are now — the one who keeps coming back.',
        );
      case 30:
        return (
          title: 'A month with the Quran',
          body: 'Day 30 · $ayahRef',
          bigText: 'Thirty days of showing up.\n\n'
              'This is who you are now. $ayahRef today.',
        );
      case 100:
        return (
          title: 'Day 100 · SubhanAllah',
          body: ayahRef,
          bigText: '100 days with the Quran.\n\n'
              'Today: $ayahRef. Keep showing up.',
        );
      case 365:
        return (
          title: 'One year with the Quran',
          body: 'Day 365 · $ayahRef',
          bigText: 'A full year of returning to the Book.\n\n'
              'Your spiritual autobiography. $ayahRef today.',
        );
    }

    // Non-milestone days: title = ayah reference (the what), so the
    // body and bigText must say something *else* — day count + a
    // rotating identity hook. bigText never repeats the title; the
    // first line stands alone next to the ayah ref in the expanded
    // view.
    final String bodyHook;
    final String bigHook;
    if (dayNumber > 30) {
      const hooks = [
        'you always return',
        'one quiet minute',
        'this is who you are',
      ];
      bodyHook = hooks[dayNumber % hooks.length];
      bigHook = 'Day $dayNumber with the Quran.\n\n'
          'The habit is part of you now.';
    } else if (dayNumber > 7) {
      const hooks = [
        'sit with today\'s ayah',
        'your daily ayah',
        'one quiet minute',
      ];
      bodyHook = hooks[dayNumber % hooks.length];
      bigHook = 'Day $dayNumber with the Quran.\n\n'
          'You keep coming back.';
    } else {
      const hooks = [
        'a quiet minute',
        'one breath, one ayah',
        'your daily ayah',
      ];
      bodyHook = hooks[dayNumber % hooks.length];
      bigHook = 'Day $dayNumber with the Quran.\n\n'
          'A quiet minute is all today asks.';
    }

    return (
      title: ayahRef,
      body: 'Day $dayNumber · $bodyHook',
      bigText: bigHook,
    );
  }

}
