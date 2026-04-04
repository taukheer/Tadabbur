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

// --- Auth State ---

final isLoggedInProvider = StateProvider<bool>((ref) {
  return ref.watch(localStorageProvider).isLoggedIn;
});

final hasOnboardedProvider = StateProvider<bool>((ref) {
  return ref.watch(localStorageProvider).hasOnboarded;
});

// --- User Profile ---

final userProfileProvider = StateProvider<UserProfile?>((ref) {
  return ref.watch(localStorageProvider).getProfile();
});

// --- User Progress ---

final userProgressProvider =
    StateNotifierProvider<UserProgressNotifier, UserProgress>((ref) {
  final storage = ref.watch(localStorageProvider);
  return UserProgressNotifier(storage);
});

class UserProgressNotifier extends StateNotifier<UserProgress> {
  final LocalStorageService _storage;

  UserProgressNotifier(this._storage)
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
    );
    await _storage.saveProgress(state);
  }

  String _getNextVerseKey(String currentKey) {
    final parts = currentKey.split(':');
    final surah = int.parse(parts[0]);
    final ayah = int.parse(parts[1]);

    // Total verses per surah (first 10 surahs for MVP)
    const verseCounts = {
      1: 7, 2: 286, 3: 200, 4: 176, 5: 120,
      6: 165, 7: 206, 8: 75, 9: 129, 10: 109,
      // ... continues for all 114 surahs
      78: 40, 79: 46, 80: 42, 81: 29, 82: 19,
      83: 36, 84: 25, 85: 22, 86: 17, 87: 19,
      88: 26, 89: 30, 90: 20, 91: 15, 92: 21,
      93: 11, 94: 8, 95: 8, 96: 19, 97: 5,
      98: 8, 99: 8, 100: 11, 101: 11, 102: 8,
      103: 3, 104: 9, 105: 5, 106: 4, 107: 7,
      108: 3, 109: 6, 110: 3, 111: 5, 112: 4,
      113: 5, 114: 6,
    };

    final maxAyah = verseCounts[surah] ?? 7;
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
  return JournalNotifier(storage);
});

class JournalNotifier extends StateNotifier<List<JournalEntry>> {
  final LocalStorageService _storage;

  JournalNotifier(this._storage) : super(_storage.getJournalEntries());

  Future<void> addEntry(JournalEntry entry) async {
    state = [entry, ...state];
    await _storage.saveJournalEntries(state);
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
