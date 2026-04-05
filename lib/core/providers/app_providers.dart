import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:tadabbur/core/services/firestore_service.dart';
import 'package:tadabbur/core/services/notification_service.dart';

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
  return UserApiService(ref.watch(apiClientProvider));
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

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(localStorageProvider));
});

final authUserProvider = StateProvider<AuthUser?>((ref) => null);

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
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

// --- User Profile ---

final userProfileProvider = StateProvider<UserProfile?>((ref) {
  return ref.watch(localStorageProvider).getProfile();
});

// --- User Progress ---

final userProgressProvider =
    StateNotifierProvider<UserProgressNotifier, UserProgress>((ref) {
  final storage = ref.watch(localStorageProvider);
  final userApi = ref.watch(userApiProvider);
  return UserProgressNotifier(storage, userApi);
});

class UserProgressNotifier extends StateNotifier<UserProgress> {
  final LocalStorageService _storage;
  final UserApiService _userApi;

  UserProgressNotifier(this._storage, this._userApi)
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

    // Sync with QF User APIs (fire-and-forget, don't block UI)
    _syncWithQF(now);
  }

  /// Sync activity with Quran Foundation APIs.
  /// Non-blocking — failures are silently ignored so the app works offline.
  void _syncWithQF(DateTime now) {
    // Update streak on QF
    _userApi.updateStreak().catchError((_) {});
    // Log activity day on QF
    _userApi.logActivityDay(now).catchError((_) {});
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

  /// Get the surah number from a verse key
  static int surahFromKey(String key) => int.parse(key.split(':').first);

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

// --- Journal ---

final journalProvider =
    StateNotifierProvider<JournalNotifier, List<JournalEntry>>((ref) {
  final storage = ref.watch(localStorageProvider);
  final userApi = ref.watch(userApiProvider);
  return JournalNotifier(storage, userApi);
});

class JournalNotifier extends StateNotifier<List<JournalEntry>> {
  final LocalStorageService _storage;
  final UserApiService _userApi;

  JournalNotifier(this._storage, this._userApi)
      : super(_storage.getJournalEntries());

  Future<void> addEntry(JournalEntry entry) async {
    // Save locally first (always works)
    state = [entry, ...state];
    await _storage.saveJournalEntries(state);

    // Sync to QF Post API (fire-and-forget)
    _syncReflectionToQF(entry);
  }

  /// Save reflection to QF Post API.
  /// Non-blocking — failures silently ignored for offline support.
  void _syncReflectionToQF(JournalEntry entry) {
    final body = entry.responseText ?? 'Acknowledged: ${entry.verseKey}';
    _userApi
        .saveReflection(
          entry.verseKey,
          body,
          metadata: {
            'tier': entry.tier.name,
            'app': 'tadabbur',
          },
        )
        .catchError((_) {});
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
}
