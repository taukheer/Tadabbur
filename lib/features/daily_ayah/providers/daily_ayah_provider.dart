import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/constants/languages.dart';
import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/models/word.dart';
import 'package:tadabbur/core/models/editorial_content.dart';
import 'package:tadabbur/core/providers/app_providers.dart';

enum AyahLoadingState { loading, loaded, error }

class DailyAyahState {
  final AyahLoadingState loadingState;
  final Ayah? ayah;
  final List<Word> words;
  final EditorialContent? editorial;
  final String? audioUrl;
  final String? errorMessage;
  final bool showWordByWord;
  final bool showContext;
  final bool showScholar;
  final bool todayCompleted;
  final String? revelationType;
  final String? tafsirSummary;
  final bool isFromCache;

  /// The 15 sajdah (prostration) verses in the Quran (Shafi'i/Hanbali count;
  /// Hanafi school omits 22:77).
  static const sajdahVerses = {
    '7:206', '13:15', '16:50', '17:109', '19:58', '22:18', '22:77',
    '25:60', '27:26', '32:15', '38:24', '41:38', '53:62', '84:21',
    '96:19',
  };

  bool get isSajdahVerse =>
      ayah != null && sajdahVerses.contains(ayah!.verseKey);

  /// True when the verse was revealed in Makkah. Normalizes the API's
  /// free-form `revelation_place` string ("makkah", "Makkah", "makki")
  /// so screens can branch on a single canonical predicate instead of
  /// brittle case-sensitive equality checks.
  bool get isMakki {
    final r = revelationType?.toLowerCase().trim();
    return r == 'makkah' || r == 'makki' || r == 'meccan';
  }

  const DailyAyahState({
    this.loadingState = AyahLoadingState.loading,
    this.ayah,
    this.words = const [],
    this.editorial,
    this.audioUrl,
    this.errorMessage,
    this.showWordByWord = false,
    this.showContext = false,
    this.showScholar = false,
    this.todayCompleted = false,
    this.revelationType,
    this.tafsirSummary,
    this.isFromCache = false,
  });

  DailyAyahState copyWith({
    AyahLoadingState? loadingState,
    Ayah? ayah,
    List<Word>? words,
    EditorialContent? editorial,
    String? audioUrl,
    String? errorMessage,
    bool? showWordByWord,
    bool? showContext,
    bool? showScholar,
    bool? todayCompleted,
    String? revelationType,
    String? tafsirSummary,
    bool? isFromCache,
  }) {
    return DailyAyahState(
      loadingState: loadingState ?? this.loadingState,
      ayah: ayah ?? this.ayah,
      words: words ?? this.words,
      editorial: editorial ?? this.editorial,
      audioUrl: audioUrl ?? this.audioUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      showWordByWord: showWordByWord ?? this.showWordByWord,
      showContext: showContext ?? this.showContext,
      showScholar: showScholar ?? this.showScholar,
      todayCompleted: todayCompleted ?? this.todayCompleted,
      revelationType: revelationType ?? this.revelationType,
      tafsirSummary: tafsirSummary ?? this.tafsirSummary,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyAyahState &&
        other.loadingState == loadingState &&
        other.ayah == ayah &&
        // Word lists compare by reference — the notifier replaces the
        // whole list on load, so identity equality is correct here.
        identical(other.words, words) &&
        other.editorial == editorial &&
        other.audioUrl == audioUrl &&
        other.errorMessage == errorMessage &&
        other.showWordByWord == showWordByWord &&
        other.showContext == showContext &&
        other.showScholar == showScholar &&
        other.todayCompleted == todayCompleted &&
        other.revelationType == revelationType &&
        other.tafsirSummary == tafsirSummary &&
        other.isFromCache == isFromCache;
  }

  @override
  int get hashCode => Object.hash(
        loadingState,
        ayah,
        words,
        editorial,
        audioUrl,
        errorMessage,
        showWordByWord,
        showContext,
        showScholar,
        todayCompleted,
        revelationType,
        tafsirSummary,
        isFromCache,
      );
}

final dailyAyahProvider =
    StateNotifierProvider<DailyAyahNotifier, DailyAyahState>((ref) {
  return DailyAyahNotifier(ref);
});

/// Memoized transliteration string for the current ayah.
///
/// The screen previously rebuilt this `.where().map().join()` chain on
/// every widget rebuild (e.g. font-size slider, theme change). Lifting
/// it into a derived Provider means it only recomputes when the
/// underlying word list actually changes.
final ayahTransliterationProvider = Provider<String>((ref) {
  final words = ref.watch(
    dailyAyahProvider.select((s) => s.words),
  );
  return words
      .where((w) => w.charTypeName == 'word' && w.transliteration != null)
      .map((w) => w.transliteration!.replaceAll(',', ''))
      .join(' ');
});

class DailyAyahNotifier extends StateNotifier<DailyAyahState> {
  final Ref _ref;

  DailyAyahNotifier(this._ref) : super(const DailyAyahState()) {
    loadDailyAyah();
  }

  Future<void> loadDailyAyah() async {
    state = const DailyAyahState(loadingState: AyahLoadingState.loading);

    final progress = _ref.read(userProgressProvider);
    final verseKey = progress.currentVerseKey;
    final storage = _ref.read(localStorageProvider);

    // Check if already completed today (skip if user chose to continue)
    bool todayCompleted = false;
    if (!_skipTodayCheck) {
      final lastCompleted = progress.lastCompletedAt;
      final now = DateTime.now();
      todayCompleted = lastCompleted != null &&
          lastCompleted.year == now.year &&
          lastCompleted.month == now.month &&
          lastCompleted.day == now.day;
    }

    try {
      final quranApi = _ref.read(quranApiProvider);
      final editorialService = _ref.read(editorialServiceProvider);

      // Fetch ayah data, words, editorial, surah info, audio in parallel
      // + local tafsir from bundled assets.
      final surahNum = int.tryParse(verseKey.split(':').first) ?? 1;
      final reciterId = storage.preferredReciterId;

      final results = await Future.wait([
        quranApi.getVerseByKey(verseKey,
            translationId: AppLanguages.getByCode(storage.language).translationId.toString()),
        quranApi.getWordsByVerse(verseKey),
        editorialService.getEditorialContent(verseKey, lang: storage.language),
        quranApi.getChapter(surahNum),
        _loadTafsirSummary(verseKey, storage.language),
        _resolveAudioUrl(quranApi, reciterId, verseKey, storage.reciterPath),
      ]);

      final ayah = results[0] as Ayah;
      final words = results[1] as List<Word>;
      final editorial = results[2] as EditorialContent?;
      final surah = results[3] as dynamic;
      final tafsirSummary = results[4] as String?;
      final audioUrl = results[5] as String;
      final revelationType = surah.revelationType as String?;

      // Persist the successful payload so we can fall back to it when offline.
      unawaited(storage.saveCachedDailyAyah({
        'verse_key': verseKey,
        'ayah': ayah.toJson(),
        'words': words.map((w) => w.toJson()).toList(),
        if (editorial != null) 'editorial': editorial.toJson(),
        'audio_url': audioUrl,
        'revelation_type': revelationType,
        'tafsir_summary': tafsirSummary,
        'cached_at': DateTime.now().toIso8601String(),
      }));

      state = state.copyWith(
        loadingState: AyahLoadingState.loaded,
        ayah: ayah,
        words: words,
        editorial: editorial,
        audioUrl: audioUrl,
        todayCompleted: todayCompleted,
        revelationType: revelationType,
        tafsirSummary: tafsirSummary,
        isFromCache: false,
      );
    } catch (e) {
      // API failed — try to restore the last successful load from cache.
      final cached = _restoreFromCache(storage, verseKey, todayCompleted);
      if (cached != null) {
        state = cached;
        return;
      }
      state = state.copyWith(
        loadingState: AyahLoadingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Resolve the audio URL for a verse via the QF recitations endpoint.
  /// Falls back to the legacy verses.quran.com path if the API call fails,
  /// so audio still works when the recitations endpoint is unavailable.
  Future<String> _resolveAudioUrl(
    dynamic quranApi,
    int reciterId,
    String verseKey,
    String reciterPath,
  ) async {
    try {
      return await quranApi.getAudioUrl(reciterId, verseKey) as String;
    } catch (_) {
      final parts = verseKey.split(':');
      final chapterPadded = parts[0].padLeft(3, '0');
      final versePadded = parts[1].padLeft(3, '0');
      return 'https://verses.quran.com/$reciterPath/mp3/$chapterPadded$versePadded.mp3';
    }
  }

  /// Restore a previously cached daily ayah payload for [verseKey], if one
  /// exists. Returns null if the cache is empty or for a different verse.
  DailyAyahState? _restoreFromCache(
    dynamic storage,
    String verseKey,
    bool todayCompleted,
  ) {
    try {
      final payload = storage.getCachedDailyAyah() as Map<String, dynamic>?;
      if (payload == null) return null;
      if (payload['verse_key'] != verseKey) return null;

      final ayah = Ayah.fromJson(payload['ayah'] as Map<String, dynamic>);
      final words = (payload['words'] as List<dynamic>? ?? [])
          .map((w) => Word.fromJson(w as Map<String, dynamic>))
          .toList();
      final editorialJson = payload['editorial'] as Map<String, dynamic>?;
      final editorial =
          editorialJson != null ? EditorialContent.fromJson(editorialJson) : null;

      return DailyAyahState(
        loadingState: AyahLoadingState.loaded,
        ayah: ayah,
        words: words,
        editorial: editorial,
        audioUrl: payload['audio_url'] as String?,
        todayCompleted: todayCompleted,
        revelationType: payload['revelation_type'] as String?,
        tafsirSummary: payload['tafsir_summary'] as String?,
        isFromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Cached tafsir summaries loaded from bundled assets.
  static Map<String, String>? _tafsirCacheEn;
  static Map<String, String>? _tafsirCacheAr;

  /// Load tafsir summary from bundled JSON (no API call).
  static Future<String?> _loadTafsirSummary(String verseKey, String lang) async {
    final isArabic = lang == 'ar';
    final cache = isArabic ? _tafsirCacheAr : _tafsirCacheEn;

    if (cache != null) {
      return cache[verseKey];
    }

    // Load and cache the full file on first access
    try {
      final path = isArabic
          ? 'assets/data/tafsir_summaries_ar.json'
          : 'assets/data/tafsir_summaries.json';
      final jsonStr = await rootBundle.loadString(path);
      final data = (json.decode(jsonStr) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, _fixTafsirSpacing(v as String)));

      if (isArabic) {
        _tafsirCacheAr = data;
      } else {
        _tafsirCacheEn = data;
      }
      return data[verseKey];
    } catch (_) {
      return null;
    }
  }

  /// Fix missing spaces in scraped tafsir text.
  /// E.g. "MakkahWhy" → "Makkah Why", "Bara'ah.\"The" → "Bara'ah.\" The"
  static String _fixTafsirSpacing(String text) {
    // Insert space where a lowercase/period/quote/paren is immediately
    // followed by an uppercase letter (but not inside Arabic text).
    return text.replaceAllMapped(
      RegExp(r'([a-z."\x27\)])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
  }

  bool _skipTodayCheck = false;

  /// Load the next ayah (user chose to continue)
  Future<void> loadNextAyah() async {
    state = state.copyWith(
      todayCompleted: false,
      showWordByWord: false,
      showContext: false,
      showScholar: false,
    );
    _skipTodayCheck = true;
    await loadDailyAyah();
    _skipTodayCheck = false;
  }

  void toggleWordByWord() {
    state = state.copyWith(showWordByWord: !state.showWordByWord);
  }

  void toggleContext() {
    state = state.copyWith(showContext: !state.showContext);
  }

  void toggleScholar() {
    state = state.copyWith(showScholar: !state.showScholar);
  }

  void markCompleted() {
    state = state.copyWith(todayCompleted: true);
  }
}
