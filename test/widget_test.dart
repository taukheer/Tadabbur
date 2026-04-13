// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/models/user_progress.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/api_client.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/services/user_api_service.dart';
import 'package:tadabbur/core/services/firestore_service.dart';

// =============================================================================
// Fakes / Stubs
// =============================================================================

/// A minimal fake for [LocalStorageService] that stores progress and journal
/// entries in memory, avoiding any dependency on SharedPreferences or
/// FlutterSecureStorage.
class FakeLocalStorageService extends LocalStorageService {
  UserProgress? _progress;
  List<JournalEntry> _journal = [];

  @override
  UserProgress? getProgress() => _progress;

  @override
  Future<void> saveProgress(UserProgress progress) async {
    _progress = progress;
  }

  @override
  List<JournalEntry> getJournalEntries() => _journal;

  @override
  Future<void> saveJournalEntries(List<JournalEntry> entries) async {
    _journal = entries;
  }

  @override
  String? get userId => 'test-user';
}

/// A minimal fake for [UserApiService].
/// All methods are no-ops so they don't make real HTTP calls.
class FakeUserApiService extends UserApiService {
  FakeUserApiService() : super(ApiClient());

  @override
  Future<void> updateStreak() async {}

  @override
  Future<void> logActivityDay(DateTime date) async {}

  @override
  Future<void> saveReflection(
    String verseKey,
    String body, {
    Map<String, dynamic>? metadata,
  }) async {}
}

/// A minimal fake for [FirestoreService].
/// All methods are no-ops so they don't touch Firestore.
class FakeFirestoreService extends FirestoreService {
  @override
  Future<void> saveProgress(
    Map<String, dynamic> progress, {
    LocalStorageService? storage,
  }) async {}

  @override
  Future<void> saveJournalEntry(
    JournalEntry entry, {
    LocalStorageService? storage,
  }) async {}

  @override
  void setUser(String userId) {}

  @override
  bool get hasUser => false;
}

// =============================================================================
// Test helpers
// =============================================================================

/// Creates a [UserProgressNotifier] with sensible defaults for testing.
///
/// [initialProgress] lets you inject a specific starting state.
/// [storage] lets you inject a specific [FakeLocalStorageService].
UserProgressNotifier createProgressNotifier({
  UserProgress? initialProgress,
  FakeLocalStorageService? storage,
}) {
  final fakeStorage = storage ?? FakeLocalStorageService();
  if (initialProgress != null) {
    fakeStorage._progress = initialProgress;
  }
  return UserProgressNotifier(
    fakeStorage,
    FakeUserApiService(),
    FakeFirestoreService(),
  );
}

/// Creates a [JournalNotifier] seeded with [initialEntries].
JournalNotifier createJournalNotifier({
  List<JournalEntry> initialEntries = const [],
}) {
  final storage = FakeLocalStorageService();
  storage._journal = List.of(initialEntries);
  return JournalNotifier(
    storage,
    FakeUserApiService(),
    FakeFirestoreService(),
  );
}

/// Builds a simple [JournalEntry] for testing.
JournalEntry makeEntry({
  String id = '1',
  String verseKey = '1:1',
  String arabicText = 'بسم الله',
  String translationText = 'In the name of God',
  ReflectionTier tier = ReflectionTier.acknowledge,
  String? promptText,
  String? responseText,
  DateTime? completedAt,
  int streakDay = 1,
}) {
  return JournalEntry(
    id: id,
    verseKey: verseKey,
    arabicText: arabicText,
    translationText: translationText,
    tier: tier,
    promptText: promptText,
    responseText: responseText,
    completedAt: completedAt ?? DateTime(2025, 1, 1),
    streakDay: streakDay,
  );
}

// =============================================================================
// Firebase test setup
// =============================================================================

/// Sets up a mock Firebase Core so that [FirebaseAnalytics.instance] doesn't
/// crash in test. Uses the platform interface that ships with firebase_core.
void setupFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up the Firebase Core mock platform
  setupFirebaseCoreMocks();
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  setupFirebaseMocks();

  // ---------------------------------------------------------------------------
  // 1. isLastAyahOfSurah  (static — no Firebase needed)
  // ---------------------------------------------------------------------------
  group('UserProgressNotifier.isLastAyahOfSurah', () {
    test('returns true for last ayah of Al-Fatiha (1:7)', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('1:7'), isTrue);
    });

    test('returns false for middle ayah of Al-Fatiha (1:3)', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('1:3'), isFalse);
    });

    test('returns true for last ayah of Al-Baqarah (2:286)', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('2:286'), isTrue);
    });

    test('returns false for first ayah of Al-Baqarah (2:1)', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('2:1'), isFalse);
    });

    test('returns true for last ayah of An-Nas (114:6)', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('114:6'), isTrue);
    });

    test('returns false for middle ayah of An-Nas (114:3)', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('114:3'), isFalse);
    });

    test('returns true for last ayah of Al-Ikhlas (112:4)', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('112:4'), isTrue);
    });

    test('returns false for ayah 1 of any surah', () {
      // Surah 1 has 7 ayat, so 1:1 is not last
      expect(UserProgressNotifier.isLastAyahOfSurah('1:1'), isFalse);
      expect(UserProgressNotifier.isLastAyahOfSurah('50:1'), isFalse);
    });

    test('returns false for out-of-range surah number (0 or 115)', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('0:1'), isFalse);
      expect(UserProgressNotifier.isLastAyahOfSurah('115:1'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. surahFromKey  (static — no Firebase needed)
  // ---------------------------------------------------------------------------
  group('UserProgressNotifier.surahFromKey', () {
    test('parses surah 1 from "1:1"', () {
      expect(UserProgressNotifier.surahFromKey('1:1'), 1);
    });

    test('parses surah 2 from "2:255"', () {
      expect(UserProgressNotifier.surahFromKey('2:255'), 2);
    });

    test('parses surah 114 from "114:6"', () {
      expect(UserProgressNotifier.surahFromKey('114:6'), 114);
    });

    test('returns 1 for unparseable key', () {
      expect(UserProgressNotifier.surahFromKey('invalid'), 1);
    });

    test('returns 1 for empty string', () {
      expect(UserProgressNotifier.surahFromKey(''), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Verse progression via completeAyah  (requires Firebase mock)
  // ---------------------------------------------------------------------------
  group('Verse progression (via completeAyah)', () {
    setUpAll(() async {
      await Firebase.initializeApp();
    });

    test('mid-surah: completing 1:3 advances to 1:4', () async {
      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:3',
          currentStreak: 0,
          longestStreak: 0,
          totalAyatCompleted: 0,
          totalReflections: 0,
          streakFreezes: 0,
          isTravelMode: false,
        ),
      );

      await notifier.completeAyah('1:3');
      expect(notifier.state.currentVerseKey, '1:4');
    });

    test('end of surah: completing 1:7 advances to 2:1', () async {
      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:7',
          currentStreak: 0,
          longestStreak: 0,
          totalAyatCompleted: 0,
          totalReflections: 0,
          streakFreezes: 0,
          isTravelMode: false,
        ),
      );

      await notifier.completeAyah('1:7');
      expect(notifier.state.currentVerseKey, '2:1');
    });

    test('end of Quran: completing 114:6 cycles to 1:1', () async {
      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '114:6',
          currentStreak: 0,
          longestStreak: 0,
          totalAyatCompleted: 0,
          totalReflections: 0,
          streakFreezes: 0,
          isTravelMode: false,
        ),
      );

      await notifier.completeAyah('114:6');
      expect(notifier.state.currentVerseKey, '1:1');
    });

    test('start of surah: completing 2:1 advances to 2:2', () async {
      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '2:1',
          currentStreak: 0,
          longestStreak: 0,
          totalAyatCompleted: 0,
          totalReflections: 0,
          streakFreezes: 0,
          isTravelMode: false,
        ),
      );

      await notifier.completeAyah('2:1');
      expect(notifier.state.currentVerseKey, '2:2');
    });

    test('totalAyatCompleted increments by 1 on each completion', () async {
      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:1',
          currentStreak: 0,
          longestStreak: 0,
          totalAyatCompleted: 5,
          totalReflections: 5,
          streakFreezes: 0,
          isTravelMode: false,
        ),
      );

      await notifier.completeAyah('1:1');
      expect(notifier.state.totalAyatCompleted, 6);
      expect(notifier.state.totalReflections, 6);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Streak logic via completeAyah
  // ---------------------------------------------------------------------------
  group('Streak logic (via completeAyah)', () {
    setUpAll(() async {
      await Firebase.initializeApp();
    });

    test('first completion ever: streak becomes 1, startedAt is set', () async {
      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:1',
          currentStreak: 0,
          longestStreak: 0,
          totalAyatCompleted: 0,
          totalReflections: 0,
          streakFreezes: 0,
          isTravelMode: false,
          lastCompletedAt: null,
          startedAt: null,
        ),
      );

      await notifier.completeAyah('1:1');

      expect(notifier.state.currentStreak, 1);
      expect(notifier.state.startedAt, isNotNull);
      expect(notifier.state.lastCompletedAt, isNotNull);
    });

    test('same-day completion: streak stays the same', () async {
      final today = DateTime.now();

      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:2',
          currentStreak: 3,
          longestStreak: 5,
          totalAyatCompleted: 10,
          totalReflections: 10,
          streakFreezes: 0,
          isTravelMode: false,
          lastCompletedAt: today,
          startedAt: DateTime(2025, 1, 1),
        ),
      );

      await notifier.completeAyah('1:2');

      expect(notifier.state.currentStreak, 3);
    });

    test('next-day completion: streak increments by 1', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:3',
          currentStreak: 3,
          longestStreak: 5,
          totalAyatCompleted: 10,
          totalReflections: 10,
          streakFreezes: 0,
          isTravelMode: false,
          lastCompletedAt: yesterday,
          startedAt: DateTime(2025, 1, 1),
        ),
      );

      await notifier.completeAyah('1:3');

      expect(notifier.state.currentStreak, 4);
    });

    test('gap of 2+ days: streak resets to 1', () async {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:4',
          currentStreak: 10,
          longestStreak: 10,
          totalAyatCompleted: 50,
          totalReflections: 50,
          streakFreezes: 0,
          isTravelMode: false,
          lastCompletedAt: threeDaysAgo,
          startedAt: DateTime(2025, 1, 1),
        ),
      );

      await notifier.completeAyah('1:4');

      expect(notifier.state.currentStreak, 1);
    });

    test('gap of exactly 2 days: streak resets to 1', () async {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));

      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:5',
          currentStreak: 5,
          longestStreak: 5,
          totalAyatCompleted: 20,
          totalReflections: 20,
          streakFreezes: 0,
          isTravelMode: false,
          lastCompletedAt: twoDaysAgo,
          startedAt: DateTime(2025, 1, 1),
        ),
      );

      await notifier.completeAyah('1:5');

      expect(notifier.state.currentStreak, 1);
    });

    test('longestStreak updates when current exceeds it', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:6',
          currentStreak: 5,
          longestStreak: 5,
          totalAyatCompleted: 20,
          totalReflections: 20,
          streakFreezes: 0,
          isTravelMode: false,
          lastCompletedAt: yesterday,
          startedAt: DateTime(2025, 1, 1),
        ),
      );

      await notifier.completeAyah('1:6');

      // streak goes from 5 to 6, which exceeds longest (5)
      expect(notifier.state.currentStreak, 6);
      expect(notifier.state.longestStreak, 6);
    });

    test('longestStreak stays the same when current does not exceed it',
        () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '2:1',
          currentStreak: 3,
          longestStreak: 10,
          totalAyatCompleted: 20,
          totalReflections: 20,
          streakFreezes: 0,
          isTravelMode: false,
          lastCompletedAt: yesterday,
          startedAt: DateTime(2025, 1, 1),
        ),
      );

      await notifier.completeAyah('2:1');

      expect(notifier.state.currentStreak, 4);
      expect(notifier.state.longestStreak, 10);
    });

    test('longestStreak stays the same after streak reset', () async {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '2:2',
          currentStreak: 7,
          longestStreak: 15,
          totalAyatCompleted: 30,
          totalReflections: 30,
          streakFreezes: 0,
          isTravelMode: false,
          lastCompletedAt: threeDaysAgo,
          startedAt: DateTime(2025, 1, 1),
        ),
      );

      await notifier.completeAyah('2:2');

      expect(notifier.state.currentStreak, 1);
      expect(notifier.state.longestStreak, 15);
    });

    test('startedAt is preserved after first completion', () async {
      final startDate = DateTime(2025, 1, 1);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '3:1',
          currentStreak: 2,
          longestStreak: 2,
          totalAyatCompleted: 5,
          totalReflections: 5,
          streakFreezes: 0,
          isTravelMode: false,
          lastCompletedAt: yesterday,
          startedAt: startDate,
        ),
      );

      await notifier.completeAyah('3:1');

      // startedAt should remain as the original date
      expect(notifier.state.startedAt, startDate);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. UserProgressNotifier initialization
  // ---------------------------------------------------------------------------
  group('UserProgressNotifier initialization', () {
    test('initializes with default values when no saved progress', () {
      final notifier = createProgressNotifier();

      expect(notifier.state.currentVerseKey, '1:1');
      expect(notifier.state.currentStreak, 0);
      expect(notifier.state.longestStreak, 0);
      expect(notifier.state.totalAyatCompleted, 0);
    });

    test('initializes with saved progress when available', () {
      final saved = UserProgress(
        userId: 'test',
        currentVerseKey: '5:10',
        currentStreak: 7,
        longestStreak: 14,
        totalAyatCompleted: 100,
        totalReflections: 100,
        streakFreezes: 2,
        isTravelMode: false,
        startedAt: DateTime(2025, 1, 1),
      );

      final notifier = createProgressNotifier(initialProgress: saved);

      expect(notifier.state.currentVerseKey, '5:10');
      expect(notifier.state.currentStreak, 7);
      expect(notifier.state.longestStreak, 14);
      expect(notifier.state.totalAyatCompleted, 100);
      expect(notifier.state.streakFreezes, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. UserProgressNotifier.setStartingVerse
  // ---------------------------------------------------------------------------
  group('UserProgressNotifier.setStartingVerse', () {
    test('updates currentVerseKey without changing other fields', () async {
      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:1',
          currentStreak: 5,
          longestStreak: 10,
          totalAyatCompleted: 20,
          totalReflections: 20,
          streakFreezes: 1,
          isTravelMode: false,
        ),
      );

      await notifier.setStartingVerse('36:1');

      expect(notifier.state.currentVerseKey, '36:1');
      expect(notifier.state.currentStreak, 5);
      expect(notifier.state.longestStreak, 10);
      expect(notifier.state.totalAyatCompleted, 20);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. UserProgressNotifier.useStreakFreeze
  // ---------------------------------------------------------------------------
  group('UserProgressNotifier.useStreakFreeze', () {
    test('decrements streak freezes when available', () async {
      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:1',
          currentStreak: 5,
          longestStreak: 10,
          totalAyatCompleted: 20,
          totalReflections: 20,
          streakFreezes: 3,
          isTravelMode: false,
        ),
      );

      await notifier.useStreakFreeze();

      expect(notifier.state.streakFreezes, 2);
    });

    test('does nothing when no streak freezes remain', () async {
      final notifier = createProgressNotifier(
        initialProgress: UserProgress(
          userId: 'test',
          currentVerseKey: '1:1',
          currentStreak: 5,
          longestStreak: 10,
          totalAyatCompleted: 20,
          totalReflections: 20,
          streakFreezes: 0,
          isTravelMode: false,
        ),
      );

      await notifier.useStreakFreeze();

      expect(notifier.state.streakFreezes, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. JournalNotifier — addEntry
  // ---------------------------------------------------------------------------
  group('JournalNotifier.addEntry', () {
    setUpAll(() async {
      await Firebase.initializeApp();
    });

    test('prepends entry to state', () async {
      final existing = makeEntry(id: 'old', verseKey: '1:1');
      final notifier = createJournalNotifier(initialEntries: [existing]);

      final newEntry = makeEntry(id: 'new', verseKey: '1:2');
      await notifier.addEntry(newEntry);

      expect(notifier.state.length, 2);
      expect(notifier.state.first.id, 'new');
      expect(notifier.state.last.id, 'old');
    });

    test('adds first entry to empty state', () async {
      final notifier = createJournalNotifier();

      final entry = makeEntry(id: '1', verseKey: '2:255');
      await notifier.addEntry(entry);

      expect(notifier.state.length, 1);
      expect(notifier.state.first.verseKey, '2:255');
    });

    test('multiple entries are prepended in order', () async {
      final notifier = createJournalNotifier();

      await notifier.addEntry(makeEntry(id: 'a', verseKey: '1:1'));
      await notifier.addEntry(makeEntry(id: 'b', verseKey: '1:2'));
      await notifier.addEntry(makeEntry(id: 'c', verseKey: '1:3'));

      expect(notifier.state.length, 3);
      expect(notifier.state[0].id, 'c');
      expect(notifier.state[1].id, 'b');
      expect(notifier.state[2].id, 'a');
    });
  });

  // ---------------------------------------------------------------------------
  // 9. JournalNotifier — search
  // ---------------------------------------------------------------------------
  group('JournalNotifier.search', () {
    late JournalNotifier notifier;

    setUp(() {
      notifier = createJournalNotifier(initialEntries: [
        makeEntry(
          id: '1',
          verseKey: '1:1',
          translationText: 'In the name of God',
          responseText: 'A profound opening',
        ),
        makeEntry(
          id: '2',
          verseKey: '2:255',
          translationText: 'Allah - there is no deity except Him',
          responseText: 'The Throne Verse is beautiful',
        ),
        makeEntry(
          id: '3',
          verseKey: '36:1',
          translationText: 'Ya Sin',
          responseText: null,
        ),
      ]);
    });

    test('finds entries by translation text', () {
      final results = notifier.search('deity');
      expect(results.length, 1);
      expect(results.first.verseKey, '2:255');
    });

    test('finds entries by response text', () {
      final results = notifier.search('profound');
      expect(results.length, 1);
      expect(results.first.id, '1');
    });

    test('finds entries by verse key', () {
      final results = notifier.search('36:1');
      expect(results.length, 1);
      expect(results.first.verseKey, '36:1');
    });

    test('search is case-insensitive', () {
      final results = notifier.search('THRONE');
      expect(results.length, 1);
      expect(results.first.id, '2');
    });

    test('returns empty list for no matches', () {
      final results = notifier.search('xyz-no-match');
      expect(results, isEmpty);
    });

    test('returns all matching entries when multiple match', () {
      final results = notifier.search('the');
      // "In the name of God" and "Allah - there is no deity except Him" and
      // "The Throne Verse is beautiful" (response)
      expect(results.length, greaterThanOrEqualTo(2));
    });

    test('handles entries with null responseText', () {
      // Search for something only in translation of entry 3
      final results = notifier.search('Ya Sin');
      expect(results.length, 1);
      expect(results.first.id, '3');
    });
  });

  // ---------------------------------------------------------------------------
  // 10. JournalNotifier — filterBySurah
  // ---------------------------------------------------------------------------
  group('JournalNotifier.filterBySurah', () {
    late JournalNotifier notifier;

    setUp(() {
      notifier = createJournalNotifier(initialEntries: [
        makeEntry(id: '1', verseKey: '1:1'),
        makeEntry(id: '2', verseKey: '1:5'),
        makeEntry(id: '3', verseKey: '2:255'),
        makeEntry(id: '4', verseKey: '2:1'),
        makeEntry(id: '5', verseKey: '36:1'),
      ]);
    });

    test('returns entries matching surah 1', () {
      final results = notifier.filterBySurah(1);
      expect(results.length, 2);
      expect(results.every((e) => e.verseKey.startsWith('1:')), isTrue);
    });

    test('returns entries matching surah 2', () {
      final results = notifier.filterBySurah(2);
      expect(results.length, 2);
      expect(results.every((e) => e.verseKey.startsWith('2:')), isTrue);
    });

    test('returns entries matching surah 36', () {
      final results = notifier.filterBySurah(36);
      expect(results.length, 1);
      expect(results.first.verseKey, '36:1');
    });

    test('returns empty for surah with no entries', () {
      final results = notifier.filterBySurah(114);
      expect(results, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 11. JournalNotifier — filterByTier
  // ---------------------------------------------------------------------------
  group('JournalNotifier.filterByTier', () {
    late JournalNotifier notifier;

    setUp(() {
      notifier = createJournalNotifier(initialEntries: [
        makeEntry(id: '1', tier: ReflectionTier.acknowledge),
        makeEntry(id: '2', tier: ReflectionTier.respond),
        makeEntry(id: '3', tier: ReflectionTier.reflect),
        makeEntry(id: '4', tier: ReflectionTier.acknowledge),
        makeEntry(id: '5', tier: ReflectionTier.respond),
      ]);
    });

    test('filters by acknowledge tier', () {
      final results = notifier.filterByTier(ReflectionTier.acknowledge);
      expect(results.length, 2);
      expect(results.every((e) => e.tier == ReflectionTier.acknowledge), isTrue);
    });

    test('filters by respond tier', () {
      final results = notifier.filterByTier(ReflectionTier.respond);
      expect(results.length, 2);
      expect(results.every((e) => e.tier == ReflectionTier.respond), isTrue);
    });

    test('filters by reflect tier', () {
      final results = notifier.filterByTier(ReflectionTier.reflect);
      expect(results.length, 1);
      expect(results.first.tier, ReflectionTier.reflect);
    });
  });

  // ---------------------------------------------------------------------------
  // 12. JournalEntry model tests
  // ---------------------------------------------------------------------------
  group('JournalEntry model', () {
    test('fromJson round-trips correctly', () {
      final entry = makeEntry(
        id: 'abc',
        verseKey: '2:255',
        arabicText: 'آية الكرسي',
        translationText: 'The Throne Verse',
        tier: ReflectionTier.reflect,
        promptText: 'What stands out?',
        responseText: 'The majesty of God',
        completedAt: DateTime(2025, 3, 15, 10, 30),
        streakDay: 7,
      );

      final json = entry.toJson();
      final restored = JournalEntry.fromJson(json);

      expect(restored.id, entry.id);
      expect(restored.verseKey, entry.verseKey);
      expect(restored.arabicText, entry.arabicText);
      expect(restored.translationText, entry.translationText);
      expect(restored.tier, entry.tier);
      expect(restored.promptText, entry.promptText);
      expect(restored.responseText, entry.responseText);
      expect(restored.completedAt, entry.completedAt);
      expect(restored.streakDay, entry.streakDay);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'test',
        'verse_key': '1:1',
        'arabic_text': 'بسم الله',
        'translation_text': 'In the name',
        'tier': 'acknowledge',
        'completed_at': '2025-01-01T00:00:00.000',
        'streak_day': 1,
      };

      final entry = JournalEntry.fromJson(json);

      expect(entry.promptText, isNull);
      expect(entry.responseText, isNull);
      expect(entry.hijriDate, isNull);
    });

    test('copyWith creates modified copy', () {
      final original = makeEntry(id: '1', verseKey: '1:1', streakDay: 3);
      final copy = original.copyWith(verseKey: '2:1', streakDay: 5);

      expect(copy.id, '1'); // unchanged
      expect(copy.verseKey, '2:1'); // changed
      expect(copy.streakDay, 5); // changed
      expect(copy.tier, original.tier); // unchanged
    });

    test('equality works correctly', () {
      final a = makeEntry(id: '1', verseKey: '1:1');
      final b = makeEntry(id: '1', verseKey: '1:1');
      final c = makeEntry(id: '2', verseKey: '1:1');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // 13. UserProgress model tests
  // ---------------------------------------------------------------------------
  group('UserProgress model', () {
    test('fromJson round-trips correctly', () {
      final progress = UserProgress(
        userId: 'user1',
        currentVerseKey: '10:5',
        currentStreak: 7,
        longestStreak: 14,
        totalAyatCompleted: 100,
        totalReflections: 50,
        lastCompletedAt: DateTime(2025, 3, 15),
        startedAt: DateTime(2025, 1, 1),
        streakFreezes: 2,
        isTravelMode: true,
      );

      final json = progress.toJson();
      final restored = UserProgress.fromJson(json);

      expect(restored.userId, progress.userId);
      expect(restored.currentVerseKey, progress.currentVerseKey);
      expect(restored.currentStreak, progress.currentStreak);
      expect(restored.longestStreak, progress.longestStreak);
      expect(restored.totalAyatCompleted, progress.totalAyatCompleted);
      expect(restored.totalReflections, progress.totalReflections);
      expect(restored.streakFreezes, progress.streakFreezes);
      expect(restored.isTravelMode, progress.isTravelMode);
    });

    test('copyWith creates modified copy', () {
      final original = UserProgress(
        userId: 'user1',
        currentVerseKey: '1:1',
        currentStreak: 3,
        longestStreak: 5,
        totalAyatCompleted: 10,
        totalReflections: 10,
        streakFreezes: 0,
        isTravelMode: false,
      );

      final copy = original.copyWith(
        currentStreak: 4,
        longestStreak: 6,
      );

      expect(copy.userId, 'user1'); // unchanged
      expect(copy.currentStreak, 4); // changed
      expect(copy.longestStreak, 6); // changed
      expect(copy.currentVerseKey, '1:1'); // unchanged
    });
  });

  // ---------------------------------------------------------------------------
  // 14. ReflectionTier enum
  // ---------------------------------------------------------------------------
  group('ReflectionTier enum', () {
    test('has exactly 3 values', () {
      expect(ReflectionTier.values.length, 3);
    });

    test('values are acknowledge, respond, reflect', () {
      expect(ReflectionTier.values, contains(ReflectionTier.acknowledge));
      expect(ReflectionTier.values, contains(ReflectionTier.respond));
      expect(ReflectionTier.values, contains(ReflectionTier.reflect));
    });

    test('name property returns correct string', () {
      expect(ReflectionTier.acknowledge.name, 'acknowledge');
      expect(ReflectionTier.respond.name, 'respond');
      expect(ReflectionTier.reflect.name, 'reflect');
    });
  });

  // ---------------------------------------------------------------------------
  // 15. Storage integration (FakeLocalStorageService)
  // ---------------------------------------------------------------------------
  group('Progress persists to storage', () {
    setUpAll(() async {
      await Firebase.initializeApp();
    });

    test('completeAyah saves updated progress to storage', () async {
      final storage = FakeLocalStorageService();
      final notifier = UserProgressNotifier(
        storage,
        FakeUserApiService(),
        FakeFirestoreService(),
      );

      expect(storage.getProgress(), isNull);

      await notifier.completeAyah('1:1');

      final saved = storage.getProgress();
      expect(saved, isNotNull);
      expect(saved!.currentVerseKey, '1:2');
      expect(saved.currentStreak, 1);
      expect(saved.totalAyatCompleted, 1);
    });

    test('setStartingVerse saves to storage', () async {
      final storage = FakeLocalStorageService();
      final notifier = UserProgressNotifier(
        storage,
        FakeUserApiService(),
        FakeFirestoreService(),
      );

      await notifier.setStartingVerse('50:1');

      final saved = storage.getProgress();
      expect(saved, isNotNull);
      expect(saved!.currentVerseKey, '50:1');
    });
  });

  // ---------------------------------------------------------------------------
  // 16. Edge cases for isLastAyahOfSurah with various surahs
  // ---------------------------------------------------------------------------
  group('isLastAyahOfSurah edge cases', () {
    test('Al-Kawthar (108) has 3 ayat', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('108:3'), isTrue);
      expect(UserProgressNotifier.isLastAyahOfSurah('108:2'), isFalse);
    });

    test('Al-Asr (103) has 3 ayat', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('103:3'), isTrue);
      expect(UserProgressNotifier.isLastAyahOfSurah('103:1'), isFalse);
    });

    test('Yusuf (12) has 111 ayat', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('12:111'), isTrue);
      expect(UserProgressNotifier.isLastAyahOfSurah('12:110'), isFalse);
    });
  });
}
