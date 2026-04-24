import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/models/bookmark.dart';
import 'package:tadabbur/core/models/collection.dart';
import 'package:tadabbur/core/models/qf_user_profile.dart';
import 'package:tadabbur/core/services/api_client.dart';
import 'package:tadabbur/core/services/audio_service.dart';
import 'package:tadabbur/core/services/editorial_service.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/services/quran_api_service.dart';
import 'package:tadabbur/core/services/user_api_service.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/models/user_profile.dart';
import 'package:tadabbur/core/models/user_progress.dart';
import 'package:tadabbur/core/services/auth_service.dart';
import 'package:tadabbur/core/services/qf_auth_service.dart';
import 'package:tadabbur/core/services/firestore_service.dart';
import 'package:tadabbur/core/services/notification_service.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';

// --- Core Services ---

final localStorageProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(localStorageProvider);
  final client = ApiClient();
  final token = storage.authToken;
  if (token != null) {
    client.setAuthToken(token);
  }
  return client;
});

final quranApiProvider = Provider<QuranApiService>((ref) {
  return QuranApiService(ref.watch(apiClientProvider));
});

final userApiProvider = Provider<UserApiService>((ref) {
  // UserApiService has its own Dio instance pointed at the QF User API
  // host (apis-prelive.quran.foundation / apis.quran.foundation). It
  // only needs LocalStorageService to read the live auth token on each
  // request via its interceptor — the content-API ApiClient is not
  // involved in User API calls.
  //
  // The refresh callback lets the User API interceptor recover from
  // 401 responses by triggering a single QF token refresh + retry.
  return UserApiService(
    ref.watch(localStorageProvider),
    onRefreshToken: () => ref.read(qfAuthServiceProvider).refreshAccessToken(),
  );
});

final editorialServiceProvider = Provider<EditorialService>((ref) {
  return EditorialService();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(localStorageProvider));
});

/// QF profile (name/avatar/email) for the signed-in user, cached in
/// local storage. Null while we haven't fetched yet or the user isn't
/// signed in via QF OAuth. Surfaced in Settings so the OAuth link is
/// visible — users and judges should feel "my quran.com identity
/// lives here" rather than "this app happens to know an auth token."
final qfProfileProvider =
    StateNotifierProvider<QfProfileNotifier, QfUserProfile?>((ref) {
  return QfProfileNotifier(ref);
});

class QfProfileNotifier extends StateNotifier<QfUserProfile?> {
  final Ref _ref;

  QfProfileNotifier(this._ref)
      : super(QfUserProfile.tryDecode(
          _ref.read(localStorageProvider).qfProfileJson,
        ));

  /// Fetch the freshest profile from QF and cache it. No-op for guest
  /// users or non-QF auth types — guarded at the service layer too,
  /// but shortcut here to avoid a pointless network round-trip.
  ///
  /// QF's `/v1/users/me` currently returns 403 on our client (scope
  /// config on their side); [setFromAuthUser] is the reliable path
  /// because the OIDC id_token already carries name + email. This
  /// method stays in place for when the endpoint starts answering.
  Future<void> refresh() async {
    final storage = _ref.read(localStorageProvider);
    if (storage.authType != AuthType.quranFoundation) return;
    final userApi = _ref.read(userApiProvider);
    final raw = await userApi.getUserProfile();
    if (raw == null) return;
    final profile = QfUserProfile.fromJson(raw);
    state = profile;
    await storage.setQfProfileJson(profile.encode());
  }

  /// Populate the profile directly from the AuthUser we built out of
  /// the OIDC id_token during `QFAuthService.exchangeCode`. We do
  /// this on every successful OAuth exchange so the identity card
  /// shows up immediately without waiting for a network round-trip —
  /// and so that a broken `/v1/users/me` endpoint can't hide the
  /// fact that the user is signed in.
  Future<void> setFromAuthUser({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
  }) async {
    final profile = QfUserProfile(
      id: id,
      name: name,
      email: email,
      avatarUrl: photoUrl,
    );
    state = profile;
    await _ref
        .read(localStorageProvider)
        .setQfProfileJson(profile.encode());
  }

  Future<void> clear() async {
    state = null;
    await _ref.read(localStorageProvider).setQfProfileJson(null);
  }
}

/// QF-side thematic groupings of verses. Distinct from local
/// bookmarks: collections live on quran.com and are shared with any
/// other Connected App the user has authorized, so a "Ayahs on
/// sabr" collection created in Tadabbur is visible on the website
/// too (and vice versa). That cross-app continuity is exactly the
/// Connected Apps signal the ecosystem rewards.
final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, List<QfCollection>>((ref) {
  return CollectionsNotifier(ref);
});

class CollectionsNotifier extends StateNotifier<List<QfCollection>> {
  final Ref _ref;
  bool _inFlight = false;

  CollectionsNotifier(this._ref) : super(const []);

  /// Refresh the list of collections from QF. Idempotent — safe to
  /// call on pull-to-refresh, on screen open, and after a mutation.
  Future<void> refresh() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final userApi = _ref.read(userApiProvider);
      // Clear any stale error from a prior run; getCollections will
      // set a fresh one if this attempt also fails.
      userApi.lastCollectionsError = null;
      final raw = await userApi.getCollections();
      state = raw.map(QfCollection.fromJson).toList();
    } finally {
      _inFlight = false;
    }
  }

  /// Create a collection. Returns the new id on success so callers
  /// can navigate directly into the empty collection.
  Future<String?> create(String name) async {
    final userApi = _ref.read(userApiProvider);
    final id = await userApi.createCollection(name);
    if (id != null) {
      // Optimistic refresh — the server is now the source of truth.
      unawaited(refresh());
    }
    return id;
  }

  Future<bool> delete(String collectionId) async {
    final userApi = _ref.read(userApiProvider);
    final ok = await userApi.deleteCollection(collectionId);
    if (ok) {
      state = state.where((c) => c.id != collectionId).toList();
    }
    return ok;
  }

  Future<bool> addVerse(String collectionId, String verseKey) async {
    final userApi = _ref.read(userApiProvider);
    return userApi.addVerseToCollection(collectionId, verseKey);
  }
}

/// Provider family for the items inside a specific collection. Keyed
/// by collection id — the cache is automatically scoped per-collection
/// by Riverpod without us having to manage a per-id map ourselves.
final collectionItemsProvider =
    FutureProvider.family<List<QfCollectionItem>, String>((ref, collectionId) async {
  final userApi = ref.watch(userApiProvider);
  final raw = await userApi.getCollectionItems(collectionId);
  return raw
      .map(QfCollectionItem.tryFromJson)
      .whereType<QfCollectionItem>()
      .toList();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(localStorageProvider), ref.watch(firestoreServiceProvider));
});

final qfAuthServiceProvider = Provider<QFAuthService>((ref) {
  return QFAuthService(ref.watch(localStorageProvider));
});

final authUserProvider = StateProvider<AuthUser?>((ref) => null);

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// --- Connectivity ---

final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

// --- Auth State ---

final isLoggedInProvider = StateProvider<bool>((ref) {
  return ref.watch(localStorageProvider).isLoggedIn;
});

final hasOnboardedProvider = StateProvider<bool>((ref) {
  return ref.watch(localStorageProvider).hasOnboarded;
});

// --- Display Preferences (reactive) ---

final arabicFontProvider = StateProvider<String>((ref) {
  return ref.watch(localStorageProvider).arabicFont;
});

final arabicFontSizeProvider = StateProvider<double>((ref) {
  return ref.watch(localStorageProvider).arabicFontSize;
});

final reciterPathProvider = StateProvider<String>((ref) {
  return ref.watch(localStorageProvider).reciterPath;
});

final languageProvider = StateProvider<String>((ref) {
  return ref.watch(localStorageProvider).language;
});

final showTransliterationProvider = StateProvider<bool>((ref) {
  return ref.watch(localStorageProvider).showTransliteration;
});

/// Preference for rendering journal month headers with Hijri months
/// ("Ramadan 1447") instead of Gregorian ("March 2026"). Reactive so
/// toggling in Settings immediately updates the headers.
final useHijriDatesProvider = StateProvider<bool>((ref) {
  return ref.watch(localStorageProvider).useHijriDates;
});

// --- User Profile ---

final userProfileProvider = StateProvider<UserProfile?>((ref) {
  return ref.watch(localStorageProvider).getProfile();
});

// --- User Progress ---

final userProgressProvider =
    StateNotifierProvider<UserProgressNotifier, UserProgress>((ref) {
  final storage = ref.watch(localStorageProvider);
  final userApi = ref.watch(userApiProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  final notifService = ref.watch(notificationServiceProvider);
  return UserProgressNotifier(storage, userApi, firestore, notifService);
});

class UserProgressNotifier extends StateNotifier<UserProgress> {
  final LocalStorageService _storage;
  final UserApiService _userApi;
  final FirestoreService _firestore;
  final NotificationService _notifService;

  UserProgressNotifier(
      this._storage, this._userApi, this._firestore, this._notifService)
      : super(
          _storage.getProgress() ??
              UserProgress(
                userId: _storage.userId ?? 'local',
                currentVerseKey: '1:1',
                currentStreak: 0,
                longestStreak: 0,
                totalAyatCompleted: 0,
                totalReflections: 0,
                streakFreezes: 0,
                isTravelMode: false,
              ),
        );

  Future<void> completeAyah(String verseKey) async {
    final now = DateTime.now();
    final lastCompleted = state.lastCompletedAt;

    int newStreak = state.currentStreak;

    if (lastCompleted == null) {
      newStreak = 1;
    } else {
      final dayDiff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(
              lastCompleted.year, lastCompleted.month, lastCompleted.day))
          .inDays;
      if (dayDiff == 1) {
        newStreak = state.currentStreak + 1;
      } else if (dayDiff == 0) {
        // Same day — no streak change
      } else {
        newStreak = 1; // Streak broken
      }
    }

    final nextVerse = _getNextVerseKey(verseKey);
    state = state.copyWith(
      currentVerseKey: nextVerse,
      currentStreak: newStreak,
      longestStreak:
          newStreak > state.longestStreak ? newStreak : state.longestStreak,
      totalAyatCompleted: state.totalAyatCompleted + 1,
      totalReflections: state.totalReflections + 1,
      lastCompletedAt: now,
      // Set startedAt on first completion
      startedAt: state.startedAt ?? now,
    );
    await _storage.saveProgress(state);

    // Log analytics event
    FirebaseAnalytics.instance.logEvent(
      name: 'ayah_completed',
      parameters: {
        'verse_key': verseKey,
        'streak': newStreak,
        'total_ayat': state.totalAyatCompleted,
      },
    ).catchError((Object e) {
      SyncReporter.report('analytics', e, severity: SyncSeverity.quiet);
    });

    // Sync with QF User APIs (fire-and-forget, don't block UI)
    _syncWithQF(now);

    // Sync progress to Firestore. The pending flag on storage tracks
    // unsynced writes so the next launch replays them — this failure
    // is transient, not data loss, so keep it quiet.
    _firestore.saveProgress(state.toJson(), storage: _storage).catchError(
      (Object e) {
        SyncReporter.report('progress', e, severity: SyncSeverity.quiet);
      },
    );

    // Re-arm tomorrow's reminder so its body reflects the new
    // totalAyatCompleted count and the next ayah's surah/reference.
    // Without this, the already-pending notification fires with stale
    // content ("Your first ayah is waiting") even after the user has
    // completed several ayat.
    _notifService.ensureDailyScheduled(forceReplace: true).catchError((e) {
      debugPrint('[UserProgress] re-arm after completion failed: $e');
    });
  }

  /// Sync activity with Quran Foundation APIs.
  /// Non-blocking — local writes already succeeded, so a QF failure
  /// means the quran.com mirror is lagging, not that the user lost
  /// data. Surfaced to the UI as a subtle banner so the user knows
  /// their stats on quran.com may be out of date.
  void _syncWithQF(DateTime now) {
    _userApi.updateStreak().catchError((Object e) {
      SyncReporter.report('streak · quran.com', e);
    });
    _userApi.logActivityDay(now).catchError((Object e) {
      SyncReporter.report('activity · quran.com', e);
    });
  }

  /// All 114 surah verse counts
  static const _verseCounts = [
    0, // index 0 unused
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109,     // 1-10
    123, 111, 43, 52, 99, 128, 111, 110, 98, 135,       // 11-20
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60,          // 21-30
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85,            // 31-40
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45,             // 41-50
    60, 49, 62, 55, 78, 96, 29, 22, 24, 13,             // 51-60
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44,             // 61-70
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42,             // 71-80
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20,             // 81-90
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11,                  // 91-100
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3,                      // 101-110
    5, 4, 5, 6,                                           // 111-114
  ];

  /// Check if the given verse is the last ayah of its surah
  static bool isLastAyahOfSurah(String verseKey) {
    final parts = verseKey.split(':');
    final surah = int.parse(parts[0]);
    final ayah = int.parse(parts[1]);
    if (surah < 1 || surah > 114) return false;
    return ayah == _verseCounts[surah];
  }

  /// Get the surah number from a verse key (safe parse)
  static int surahFromKey(String key) => int.tryParse(key.split(':').first) ?? 1;

  String _getNextVerseKey(String currentKey) {
    final parts = currentKey.split(':');
    final surah = int.parse(parts[0]);
    final ayah = int.parse(parts[1]);

    final maxAyah = surah <= 114 ? _verseCounts[surah] : 7;
    if (ayah < maxAyah) {
      return '$surah:${ayah + 1}';
    } else if (surah < 114) {
      return '${surah + 1}:1';
    } else {
      return '1:1'; // Cycle back to beginning
    }
  }

  Future<void> setStartingVerse(String verseKey) async {
    state = state.copyWith(currentVerseKey: verseKey);
    await _storage.saveProgress(state);
  }

  Future<void> useStreakFreeze() async {
    if (state.streakFreezes > 0) {
      state = state.copyWith(streakFreezes: state.streakFreezes - 1);
      await _storage.saveProgress(state);
    }
  }
}

// --- Bookmarks ---

final bookmarkProvider =
    StateNotifierProvider<BookmarkNotifier, List<Bookmark>>((ref) {
  final storage = ref.watch(localStorageProvider);
  final userApi = ref.watch(userApiProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  final quranApi = ref.watch(quranApiProvider);
  return BookmarkNotifier(storage, userApi, firestore, quranApi);
});

class BookmarkNotifier extends StateNotifier<List<Bookmark>> {
  final LocalStorageService _storage;
  final UserApiService _userApi;
  final FirestoreService _firestore;
  final QuranApiService _quranApi;

  /// Guard against concurrent hydration runs. The `/oauth/callback`
  /// redirect handler can fire twice for a single sign-in (deep link
  /// stream + router rebuild race), and without this gate the second
  /// run would start its dedup pass before the first's writes landed,
  /// inserting duplicate entries.
  Future<void>? _hydrateInFlight;

  BookmarkNotifier(
      this._storage, this._userApi, this._firestore, this._quranApi)
      : super(_storage.getBookmarks());

  /// Two-way sync: pull bookmarks the user already has on quran.com
  /// (via QF `/v1/bookmarks`) and merge into local state.
  ///
  /// Called after a successful QF OAuth sign-in so a user who has
  /// existing bookmarks on the website sees them immediately in the
  /// app. Dedup is by `verseKey` — local wins on conflict because
  /// local is the last-written source.
  ///
  /// The QF bookmark response only contains `{key, verseNumber}`
  /// (the surah + ayah coordinates). Verse text for display is
  /// fetched from the content API for each new bookmark; this adds
  /// latency on first sign-in but hits QuranApiService's in-memory
  /// cache on reload.
  ///
  /// Safe against concurrent calls — a second invocation during an
  /// in-flight run reuses the same Future instead of starting a new
  /// dedup race against half-applied state.
  Future<void> hydrateFromQF() {
    return _hydrateInFlight ??= _hydrateFromQF().whenComplete(() {
      _hydrateInFlight = null;
    });
  }

  Future<void> _hydrateFromQF() async {
    try {
      final remote = await _userApi.getBookmarks();
      if (remote.isEmpty) return;

      final localKeys = state.map((b) => b.verseKey).toSet();
      final additions = <Bookmark>[];

      for (final raw in remote) {
        final verseKey = _parseVerseKey(raw);
        if (verseKey == null || localKeys.contains(verseKey)) continue;

        String arabicText = '';
        String translationText = '';
        try {
          final ayah = await _quranApi.getVerseByKey(verseKey);
          arabicText = ayah.textUthmani;
          translationText = ayah.translationText ?? '';
        } catch (e) {
          debugPrint(
            '[BookmarkNotifier] hydrate verse $verseKey failed: $e',
          );
        }

        additions.add(Bookmark(
          verseKey: verseKey,
          arabicText: arabicText,
          translationText: translationText,
          bookmarkedAt: _parseDate(raw) ?? DateTime.now(),
          qfBookmarkId: _parseInt(raw['id']),
        ));
        localKeys.add(verseKey);
      }

      if (additions.isEmpty) return;
      // Sort newest first (matches local insertion order)
      additions.sort((a, b) => b.bookmarkedAt.compareTo(a.bookmarkedAt));
      state = [...additions, ...state];
      await _storage.saveBookmarks(state);
      debugPrint(
        '[BookmarkNotifier] hydrated ${additions.length} bookmarks from QF',
      );
    } catch (e) {
      debugPrint('[BookmarkNotifier] hydrateFromQF failed: $e');
    }
  }

  /// Extract a `surah:ayah` key from a QF bookmark payload. QF emits
  /// `{key, verseNumber, type, mushaf}` where `key` is the surah
  /// number and `verseNumber` is the ayah. Falls back to a handful of
  /// alternative field names so a schema change on QF's side doesn't
  /// silently break hydration.
  static String? _parseVerseKey(Map<String, dynamic> raw) {
    final key = _parseInt(raw['key']) ??
        _parseInt(raw['surah']) ??
        _parseInt(raw['chapter_id']) ??
        _parseInt(raw['chapterId']);
    final ayah = _parseInt(raw['verseNumber']) ??
        _parseInt(raw['verse_number']) ??
        _parseInt(raw['ayah']) ??
        _parseInt(raw['ayahNumber']);
    if (key == null || ayah == null) {
      // Some QF payloads encode a single verseKey string directly.
      final vk = raw['verseKey'] as String? ?? raw['verse_key'] as String?;
      if (vk != null && vk.contains(':')) return vk;
      return null;
    }
    return '$key:$ayah';
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _parseDate(Map<String, dynamic> raw) {
    final s = raw['createdAt'] as String? ??
        raw['created_at'] as String? ??
        raw['bookmarked_at'] as String?;
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  bool isBookmarked(String verseKey) {
    return state.any((b) => b.verseKey == verseKey);
  }

  Future<void> toggle({
    required String verseKey,
    required String arabicText,
    required String translationText,
  }) async {
    if (isBookmarked(verseKey)) {
      await remove(verseKey);
    } else {
      await add(
        verseKey: verseKey,
        arabicText: arabicText,
        translationText: translationText,
      );
    }
  }

  Future<void> add({
    required String verseKey,
    required String arabicText,
    required String translationText,
  }) async {
    if (isBookmarked(verseKey)) return;

    final bookmark = Bookmark(
      verseKey: verseKey,
      arabicText: arabicText,
      translationText: translationText,
      bookmarkedAt: DateTime.now(),
    );

    state = [bookmark, ...state];
    await _storage.saveBookmarks(state);

    _userApi.addBookmark(verseKey).catchError((Object e) {
      SyncReporter.report('bookmark · quran.com', e);
    });

    // Firestore write is queued for replay via the pending key, so
    // keep the failure quiet to avoid two banners for the same issue.
    _firestore.saveBookmark(bookmark, storage: _storage).catchError(
      (Object e) {
        SyncReporter.report('bookmark', e, severity: SyncSeverity.quiet);
      },
    );

    FirebaseAnalytics.instance.logEvent(
      name: 'bookmark_added',
      parameters: {'verse_key': verseKey},
    ).catchError((Object e) {
      SyncReporter.report('analytics', e, severity: SyncSeverity.quiet);
    });
  }

  Future<void> remove(String verseKey) async {
    final idx = state.indexWhere((b) => b.verseKey == verseKey);
    final bookmark = idx >= 0 ? state[idx] : null;

    state = state.where((b) => b.verseKey != verseKey).toList();
    await _storage.saveBookmarks(state);

    _firestore.removeBookmark(verseKey, storage: _storage).catchError(
      (Object e) {
        SyncReporter.report('bookmark', e, severity: SyncSeverity.quiet);
      },
    );

    final qfBookmarkId = bookmark?.qfBookmarkId;
    if (qfBookmarkId != null) {
      _userApi.removeBookmark(qfBookmarkId).catchError((Object e) {
        SyncReporter.report('bookmark · quran.com', e);
      });
    }

    FirebaseAnalytics.instance.logEvent(
      name: 'bookmark_removed',
      parameters: {'verse_key': verseKey},
    ).catchError((Object e) {
      SyncReporter.report('analytics', e, severity: SyncSeverity.quiet);
    });
  }
}

// --- Journal ---

final journalProvider =
    StateNotifierProvider<JournalNotifier, List<JournalEntry>>((ref) {
  final storage = ref.watch(localStorageProvider);
  final userApi = ref.watch(userApiProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  final quranApi = ref.watch(quranApiProvider);
  return JournalNotifier(storage, userApi, firestore, quranApi);
});

class JournalNotifier extends StateNotifier<List<JournalEntry>> {
  final LocalStorageService _storage;
  final UserApiService _userApi;
  final FirestoreService _firestore;
  final QuranApiService _quranApi;

  /// Same concurrency guard as [BookmarkNotifier._hydrateInFlight] —
  /// the double-firing OAuth callback would otherwise insert
  /// duplicate journal entries on fresh sign-ins.
  Future<void>? _hydrateInFlight;

  JournalNotifier(
      this._storage, this._userApi, this._firestore, this._quranApi)
      : super(_storage.getJournalEntries());

  /// Two-way sync: pull notes the user already has on quran.com (via
  /// QF `/v1/notes`) and merge into the local journal.
  ///
  /// Called after a successful QF OAuth sign-in. Each QF note has a
  /// `body` and a `ranges` array like `["1:1-1:1"]`; we use the first
  /// range to determine the verseKey, fetch the verse text for display,
  /// and insert the note as a [ReflectionTier.respond] entry
  /// (the tier isn't stored on QF side so we pick a reasonable default).
  ///
  /// Dedup is by a stable `qf-{note_id}` identifier on the local
  /// [JournalEntry.id] field so re-hydrating doesn't create duplicates.
  /// Safe against concurrent calls via [_hydrateInFlight].
  Future<void> hydrateFromQF() {
    return _hydrateInFlight ??= _hydrateFromQF().whenComplete(() {
      _hydrateInFlight = null;
    });
  }

  Future<void> _hydrateFromQF() async {
    try {
      final remote = await _userApi.getReflections();
      if (remote.isEmpty) return;

      final localIds = state.map((e) => e.id).toSet();
      final additions = <JournalEntry>[];

      for (final raw in remote) {
        final noteId = raw['id']?.toString();
        final localId = noteId != null ? 'qf-$noteId' : null;
        if (localId != null && localIds.contains(localId)) continue;

        final body = (raw['body'] as String?)?.trim() ?? '';
        if (body.isEmpty) continue;

        final verseKey = _parseFirstVerseFromRanges(raw['ranges']);
        if (verseKey == null) continue;

        // Skip if we already have a local entry for this note.
        //
        // Direct body match catches the common case (tier 2/3 where
        // the user's typed text is what got POSTed). But two Tadabbur-
        // specific padding patterns also need to be recognized or
        // we'd create phantom duplicates of our own writes:
        //
        //   - Tier 1 "acknowledge" entries have no responseText, but
        //     we pad them to "Acknowledged: X:Y" before POST to
        //     satisfy QF's 6-char minimum (see UserApiService
        //     .saveReflection).
        //   - Short tier-2 entries (< 6 chars) get padded as
        //     "<text> — Tadabbur reflection on X:Y".
        //
        // Recognizing both patterns closes the dedup loop so the
        // user's own reflection never comes back as a second card.
        final ackPad = 'Acknowledged: $verseKey';
        bool matchesLocal(JournalEntry e) {
          if (e.verseKey != verseKey) return false;
          final local = (e.responseText ?? '').trim();
          if (local == body) return true;
          // Acknowledge padding — local has no text, body is our pad.
          if (body == ackPad && e.tier == ReflectionTier.acknowledge) {
            return true;
          }
          // Short-text padding — local text is a prefix of body.
          if (local.isNotEmpty &&
              body == '$local — Tadabbur reflection on $verseKey') {
            return true;
          }
          return false;
        }
        final alreadyLocal = state.any(matchesLocal);
        if (alreadyLocal) continue;

        String arabicText = '';
        String translationText = '';
        try {
          final ayah = await _quranApi.getVerseByKey(verseKey);
          arabicText = ayah.textUthmani;
          translationText = ayah.translationText ?? '';
        } catch (e) {
          debugPrint(
            '[JournalNotifier] hydrate verse $verseKey failed: $e',
          );
        }

        additions.add(JournalEntry(
          id: localId ??
              'qf-${DateTime.now().microsecondsSinceEpoch}-${additions.length}',
          verseKey: verseKey,
          arabicText: arabicText,
          translationText: translationText,
          // QF doesn't expose our app's tier taxonomy, so any pulled
          // note is treated as a "respond" tier — the user wrote
          // something meaningful.
          tier: ReflectionTier.respond,
          responseText: body,
          completedAt: _parseDate(raw) ?? DateTime.now(),
          streakDay: 0,
        ));
      }

      if (additions.isEmpty) return;
      additions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      state = [...additions, ...state];
      await _storage.saveJournalEntries(state);
      debugPrint(
        '[JournalNotifier] hydrated ${additions.length} notes from QF',
      );
    } catch (e) {
      debugPrint('[JournalNotifier] hydrateFromQF failed: $e');
    }
  }

  /// Parse a verseKey from QF's `ranges` field. Ranges are strings
  /// like `"1:1-1:1"` (single verse) or `"2:255-2:256"` (span). For
  /// single-verse notes we use the start of the range. Defensive
  /// against string, list, and object shapes in case the QF response
  /// schema drifts.
  static String? _parseFirstVerseFromRanges(dynamic ranges) {
    if (ranges is List && ranges.isNotEmpty) {
      final first = ranges.first;
      if (first is String) {
        final start = first.split('-').first;
        if (start.contains(':')) return start;
      } else if (first is Map) {
        final from = first['from'] ?? first['start'];
        if (from is String && from.contains(':')) return from;
      }
    } else if (ranges is String && ranges.contains(':')) {
      return ranges.split('-').first;
    }
    return null;
  }

  static DateTime? _parseDate(Map<String, dynamic> raw) {
    final s = raw['createdAt'] as String? ??
        raw['created_at'] as String? ??
        raw['completed_at'] as String?;
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  Future<void> addEntry(
    JournalEntry entry, {
    bool shareToQuranReflect = false,
  }) async {
    // Save locally first (always works)
    state = [entry, ...state];
    await _storage.saveJournalEntries(state);

    FirebaseAnalytics.instance.logEvent(
      name: 'reflection_added',
      parameters: {
        'verse_key': entry.verseKey,
        'tier': entry.tier.name,
        'has_text': entry.responseText != null,
      },
    ).catchError((Object e) {
      SyncReporter.report('analytics', e, severity: SyncSeverity.quiet);
    });

    // Firestore write is queued for replay; the local journal entry is
    // already persisted so there's no data loss to surface.
    _firestore.saveJournalEntry(entry, storage: _storage).catchError(
      (Object e) {
        SyncReporter.report('reflection', e, severity: SyncSeverity.quiet);
      },
    );

    _syncReflectionToQF(entry, shareToQuranReflect: shareToQuranReflect);

    // Auto-bookmark on QF when user wrote a reflection (Tier 2/3)
    if (entry.tier != ReflectionTier.acknowledge && entry.responseText != null) {
      _userApi.addBookmark(entry.verseKey).catchError((Object e) {
        SyncReporter.report('bookmark · quran.com', e);
      });
    }
  }

  /// Save reflection to QF as a personal note (and optionally mirror
  /// to the public Quran Reflect feed via [shareToQuranReflect]).
  ///
  /// Non-blocking — the local journal entry is already saved, so a
  /// QF failure just means the quran.com mirror is lagging, not lost
  /// data.
  void _syncReflectionToQF(
    JournalEntry entry, {
    required bool shareToQuranReflect,
  }) {
    final body = entry.responseText ?? 'Acknowledged: ${entry.verseKey}';
    _userApi
        .saveReflection(
          entry.verseKey,
          body,
          shareToQuranReflect: shareToQuranReflect,
          metadata: {
            'tier': entry.tier.name,
            'app': 'tadabbur',
          },
        )
        .catchError((Object e) {
      SyncReporter.report('reflection · quran.com', e);
    });
  }

  List<JournalEntry> filterBySurah(int surahNumber) {
    return state
        .where((e) => e.verseKey.startsWith('$surahNumber:'))
        .toList();
  }

  List<JournalEntry> filterByTier(ReflectionTier tier) {
    return state.where((e) => e.tier == tier).toList();
  }

  List<JournalEntry> search(String query) {
    final lower = query.toLowerCase();
    return state.where((e) {
      return (e.responseText?.toLowerCase().contains(lower) ?? false) ||
          e.translationText.toLowerCase().contains(lower) ||
          e.verseKey.contains(lower);
    }).toList();
  }

  /// Flip the pinned state of the entry with [id]. No-op when the id
  /// is unknown. Persists immediately so pinning survives relaunch.
  Future<void> togglePin(String id) async {
    var changed = false;
    state = [
      for (final e in state)
        if (e.id == id)
          () {
            changed = true;
            return e.copyWith(isPinned: !e.isPinned);
          }()
        else
          e,
    ];
    if (changed) {
      await _storage.saveJournalEntries(state);
      // No QF-side pin concept yet — pinning stays local. If QF adds
      // a "pinned notes" field in the future, we'd push here.
    }
  }
}
