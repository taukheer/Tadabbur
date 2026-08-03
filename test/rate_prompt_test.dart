// Exercises the review-prompt eligibility rules against the real
// RatePromptNotifier and a real LocalStorageService.
//
// This logic is close to untestable by hand: proving "asks after three
// days, then snoozes for a month, then gives up" on a device would take
// a month of wall-clock time and a lot of date fiddling. Everything the
// prompt decides is checked here instead.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadabbur/core/constants/app_constants.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';

JournalEntry _entryOn(DateTime day) => JournalEntry(
      id: day.toIso8601String(),
      verseKey: '36:1',
      arabicText: 'a',
      translationText: 't',
      tier: ReflectionTier.acknowledge,
      completedAt: day,
      streakDay: 1,
    );

/// Reflections on [n] distinct calendar days, ending today.
List<JournalEntry> _activeDays(int n) {
  final today = DateTime.now();
  return [
    for (var i = 0; i < n; i++)
      _entryOn(today.subtract(Duration(days: i))),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  Future<LocalStorageService> storage([
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    final s = LocalStorageService();
    await s.init();
    return s;
  }

  group('active-day counting', () {
    test('several reflections in one sitting are one day of practice', () {
      final today = DateTime(2026, 8, 3, 9);
      final entries = [
        _entryOn(today),
        _entryOn(today.add(const Duration(hours: 4))),
        _entryOn(today.add(const Duration(hours: 9))),
      ];
      expect(RatePromptNotifier.activeDayCount(entries), 1);
    });

    test('distinct days count separately regardless of time of day', () {
      final entries = [
        _entryOn(DateTime(2026, 8, 1, 23, 55)),
        _entryOn(DateTime(2026, 8, 2, 0, 5)),
        _entryOn(DateTime(2026, 8, 3, 12)),
      ];
      expect(RatePromptNotifier.activeDayCount(entries), 3);
    });

    test('an empty journal is zero days, not an error', () {
      expect(RatePromptNotifier.activeDayCount([]), 0);
    });
  });

  group('when the prompt appears', () {
    test('stays hidden below the active-day threshold', () async {
      final s = await storage();
      for (var days = 0; days < AppConstants.ratePromptMinActiveDays; days++) {
        expect(
          RatePromptNotifier(s, _activeDays(days)).state,
          isFalse,
          reason: '$days active days should not trigger the ask',
        );
      }
    });

    test('appears on the third day of practice', () async {
      final s = await storage();
      expect(AppConstants.ratePromptMinActiveDays, 3);
      expect(
        RatePromptNotifier(s, _activeDays(3)).state,
        isTrue,
      );
    });

    test('stays eligible beyond the threshold', () async {
      final s = await storage();
      expect(RatePromptNotifier(s, _activeDays(10)).state, isTrue);
    });
  });

  group('once answered', () {
    test('accepting retires the prompt permanently', () async {
      final s = await storage();
      final notifier = RatePromptNotifier(s, _activeDays(5));
      expect(notifier.state, isTrue);

      await notifier.markRated();
      expect(notifier.state, isFalse);
      expect(s.rateReviewDone, isTrue);

      // A fresh notifier — i.e. the next app launch — must agree.
      expect(RatePromptNotifier(s, _activeDays(50)).state, isFalse);
    });

    test('"not now" hides it and starts the snooze', () async {
      final s = await storage();
      final notifier = RatePromptNotifier(s, _activeDays(5));

      await notifier.snooze();
      expect(notifier.state, isFalse);
      expect(s.ratePromptAskCount, 1);
      expect(s.ratePromptSnoozedAt, isNotNull);

      // Still suppressed on the next launch, inside the window.
      expect(RatePromptNotifier(s, _activeDays(6)).state, isFalse);
    });

    test('returns after the snooze window expires', () async {
      final past = DateTime.now()
          .subtract(AppConstants.ratePromptSnooze + const Duration(days: 1));
      final s = await storage({
        'rate_prompt_snoozed_at': past.toIso8601String(),
        'rate_prompt_ask_count': 1,
      });
      expect(RatePromptNotifier(s, _activeDays(5)).state, isTrue);
    });

    test('gives up for good after the maximum number of asks', () async {
      final past = DateTime.now()
          .subtract(AppConstants.ratePromptSnooze + const Duration(days: 1));
      final s = await storage({
        'rate_prompt_snoozed_at': past.toIso8601String(),
        'rate_prompt_ask_count': AppConstants.ratePromptMaxAsks,
      });
      // Snooze has expired, plenty of practice — but two dismissals is
      // an answer, and the app has to take it.
      expect(RatePromptNotifier(s, _activeDays(100)).state, isFalse);
    });
  });

  group('configuration', () {
    test('the tuning values are what the product intends', () {
      expect(AppConstants.ratePromptMinActiveDays, 3);
      expect(AppConstants.ratePromptSnooze, const Duration(days: 30));
      expect(AppConstants.ratePromptMaxAsks, 2);
      // iOS needs the numeric App Store id to open the listing when the
      // native sheet is unavailable; an empty one fails silently.
      expect(AppConstants.appStoreId, isNotEmpty);
    });
  });
}
