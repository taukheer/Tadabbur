import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadabbur/core/constants/app_constants.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';

/// A journal entry stamped on [day]. Only `completedAt` matters to the
/// rate-prompt rule; the rest is filler.
JournalEntry _entryOn(DateTime day, {String? wrote}) {
  return JournalEntry(
    id: 'e-${day.toIso8601String()}-${wrote ?? ''}',
    verseKey: '1:1',
    arabicText: '',
    translationText: '',
    tier: wrote == null
        ? ReflectionTier.acknowledge
        : ReflectionTier.respond,
    responseText: wrote,
    completedAt: day,
    streakDay: 1,
  );
}

Future<LocalStorageService> _storage([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final storage = LocalStorageService();
  await storage.init();
  return storage;
}

/// `LocalStorageService.init` preloads the OAuth tokens from
/// flutter_secure_storage, which has no implementation in a unit-test
/// host. Stub the channel so `init()` completes; none of the
/// rate-prompt state lives in secure storage.
void _stubSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_stubSecureStorage);

  group('RatePromptNotifier.activeDayCount', () {
    test('counts distinct calendar days, not entries', () {
      final entries = [
        _entryOn(DateTime(2026, 7, 1, 8)),
        _entryOn(DateTime(2026, 7, 1, 21)), // same day, second reflection
        _entryOn(DateTime(2026, 7, 2, 9)),
      ];

      expect(RatePromptNotifier.activeDayCount(entries), 2);
    });

    test('is zero for an empty journal', () {
      expect(RatePromptNotifier.activeDayCount([]), 0);
    });
  });

  group('RatePromptNotifier visibility', () {
    /// Three distinct days of practice — the eligibility threshold.
    /// Just enough distinct practice days to clear the threshold,
    /// derived from the constant rather than hardcoded — the value has
    /// moved once already (3 -> 7) and silently broke these tests.
    List<JournalEntry> eligibleJournal() => [
          for (var i = 0; i < AppConstants.ratePromptMinActiveDays; i++)
            _entryOn(DateTime.now().subtract(Duration(days: i))),
        ];

    test('hidden below the active-day threshold', () async {
      final storage = await _storage();
      final entries = eligibleJournal()
          .take(AppConstants.ratePromptMinActiveDays - 1)
          .toList();

      expect(RatePromptNotifier(storage, entries).state, isFalse);
    });

    test('shown at the active-day threshold', () async {
      final storage = await _storage();

      expect(RatePromptNotifier(storage, eligibleJournal()).state, isTrue);
    });

    test('hidden forever once the user has rated', () async {
      final storage = await _storage({'rate_review_done': true});

      expect(RatePromptNotifier(storage, eligibleJournal()).state, isFalse);
    });

    test('markRated persists so the next session stays hidden', () async {
      final storage = await _storage();
      final notifier = RatePromptNotifier(storage, eligibleJournal());

      await notifier.markRated();

      expect(notifier.state, isFalse);
      expect(storage.rateReviewDone, isTrue);
      // A fresh notifier models the next app launch.
      expect(RatePromptNotifier(storage, eligibleJournal()).state, isFalse);
    });

    test('snooze hides the prompt for the snooze window', () async {
      final storage = await _storage();
      final notifier = RatePromptNotifier(storage, eligibleJournal());

      await notifier.snooze();

      expect(notifier.state, isFalse);
      expect(storage.ratePromptAskCount, 1);
      expect(RatePromptNotifier(storage, eligibleJournal()).state, isFalse);
    });

    test('prompt returns once the snooze window has elapsed', () async {
      final expired = DateTime.now()
          .subtract(AppConstants.ratePromptSnooze)
          .subtract(const Duration(days: 1));
      final storage = await _storage({
        'rate_prompt_snoozed_at': expired.toIso8601String(),
        'rate_prompt_ask_count': 1,
      });

      expect(RatePromptNotifier(storage, eligibleJournal()).state, isTrue);
    });

    test('retired after the maximum number of asks', () async {
      final expired = DateTime.now()
          .subtract(AppConstants.ratePromptSnooze)
          .subtract(const Duration(days: 1));
      final storage = await _storage({
        'rate_prompt_snoozed_at': expired.toIso8601String(),
        'rate_prompt_ask_count': AppConstants.ratePromptMaxAsks,
      });

      expect(RatePromptNotifier(storage, eligibleJournal()).state, isFalse);
    });
  });

  group('RatePromptNotifier written-reflection path', () {
    // The ask has two independent triggers. A week of practice shows
    // the habit stuck; a written reflection shows the app got words out
    // of someone, which is the stronger signal and doesn't wait a week.

    test('one written reflection qualifies on day one', () async {
      final storage = await _storage();
      final entries = [_entryOn(DateTime.now(), wrote: 'This landed today.')];

      expect(RatePromptNotifier.activeDayCount(entries), 1);
      expect(RatePromptNotifier.writtenReflectionCount(entries), 1);
      expect(RatePromptNotifier(storage, entries).state, isTrue);
    });

    test('tapping through is not reflecting, however many days', () async {
      final storage = await _storage();
      final entries = [
        for (var i = 0; i < AppConstants.ratePromptMinActiveDays - 1; i++)
          _entryOn(DateTime.now().subtract(Duration(days: i))),
      ];

      expect(RatePromptNotifier.writtenReflectionCount(entries), 0);
      expect(RatePromptNotifier(storage, entries).state, isFalse);
    });

    test('an empty or whitespace body is not writing', () async {
      final storage = await _storage();
      for (final body in ['', '   ', '\n\t ']) {
        final entries = [_entryOn(DateTime.now(), wrote: body)];
        expect(RatePromptNotifier.writtenReflectionCount(entries), 0,
            reason: 'body ${body.runes.toList()} should not count');
        expect(RatePromptNotifier(storage, entries).state, isFalse);
      }
    });

    test('a written reflection cannot reopen a retired prompt', () async {
      final storage = await _storage({'rate_review_done': true});
      final entries = [_entryOn(DateTime.now(), wrote: 'later thoughts')];

      expect(RatePromptNotifier(storage, entries).state, isFalse);
    });

    test('a written reflection is still suppressed inside the snooze',
        () async {
      final storage = await _storage({
        'rate_prompt_snoozed_at': DateTime.now().toIso8601String(),
        'rate_prompt_ask_count': 1,
      });
      final entries = [_entryOn(DateTime.now(), wrote: 'something real')];

      expect(RatePromptNotifier(storage, entries).state, isFalse);
    });
  });

  group('rate-prompt configuration', () {
    test('the tuning values are what the product intends', () {
      expect(AppConstants.ratePromptMinActiveDays, 7);
      expect(AppConstants.ratePromptMinWrittenReflections, 1);
      expect(AppConstants.ratePromptSnooze, const Duration(days: 30));
      expect(AppConstants.ratePromptMaxAsks, 2);
      // iOS needs the numeric id to open the listing when the native
      // sheet is unavailable; an empty one fails silently.
      expect(AppConstants.appStoreId, isNotEmpty);
    });
  });
}
