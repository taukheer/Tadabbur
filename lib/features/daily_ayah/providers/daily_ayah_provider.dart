import 'dart:async';
import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/constants/languages.dart';
import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/models/word.dart';
import 'package:tadabbur/core/models/editorial_content.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/home_widget_service.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';

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

      final surahNum = int.tryParse(verseKey.split(':').first) ?? 1;
      final reciterId = storage.preferredReciterId;

      // The verse itself is required — if it fails, fall back to cache.
      // Everything else (words, editorial, tafsir, audio, surah metadata)
      // is an enrichment: a QF outage on translations or tafsir should
      // never block the user from reading today's ayah. Each secondary
      // call runs in parallel and is wrapped individually so a single
      // failure only drops its own slice of the UI.
      final ayahFuture = quranApi.getVerseByKey(
        verseKey,
        translationId:
            AppLanguages.getByCode(storage.language).translationId.toString(),
      );
      final wordsFuture = _guard(
        'words',
        () => quranApi.getWordsByVerse(verseKey),
        fallback: <Word>[],
      );
      final editorialFuture = _guard<EditorialContent?>(
        'editorial',
        () => editorialService.getEditorialContent(
          verseKey,
          lang: storage.language,
        ),
        fallback: null,
      );
      final surahFuture = _guard<dynamic>(
        'chapter',
        () => quranApi.getChapter(surahNum),
        fallback: null,
      );
      final tafsirFuture = _guard<String?>(
        'tafsir',
        () => _loadTafsirSummary(verseKey, storage.language),
        fallback: null,
      );
      final audioFuture = _guard<String?>(
        'audio',
        () => _resolveAudioUrl(
          quranApi,
          reciterId,
          verseKey,
          storage.reciterPath,
        ),
        fallback: null,
      );

      final ayah = await ayahFuture;
      final words = await wordsFuture;
      final editorial = await editorialFuture;
      final surah = await surahFuture;
      final tafsirSummary = await tafsirFuture;
      final audioUrl = await audioFuture;
      final revelationType = surah?.revelationType as String?;

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

      // Push today's ayah to the home screen widget so it stays in
      // sync with what the user sees in the app — without this the
      // widget would show stale content from whenever the user first
      // added it.
      unawaited(HomeWidgetService.updateWithAyah(
        ayah: ayah,
        dayNumber: progress.dayNumber,
      ));
    } catch (e) {
      // API failed — try to restore the last successful load from cache.
      final cached = _restoreFromCache(storage, verseKey, todayCompleted);
      if (cached != null) {
        state = cached;
        if (cached.ayah != null) {
          unawaited(HomeWidgetService.updateWithAyah(
            ayah: cached.ayah!,
            dayNumber: progress.dayNumber,
          ));
        }
        return;
      }
      state = state.copyWith(
        loadingState: AyahLoadingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Run a secondary fetch in isolation: if it throws, report to
  /// SyncReporter/Crashlytics as non-fatal and return [fallback] so the
  /// parent load keeps going. Used for non-critical enrichments like
  /// tafsir/audio/editorial that should degrade gracefully instead of
  /// failing the whole daily ayah screen when one endpoint is flaky.
  Future<T> _guard<T>(
    String label,
    Future<T> Function() task, {
    required T fallback,
  }) async {
    try {
      return await task();
    } catch (error, stack) {
      SyncReporter.report(
        'daily_ayah · $label',
        error,
        severity: SyncSeverity.quiet,
      );
      unawaited(FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'daily_ayah enrichment failed: $label',
        fatal: false,
      ));
      return fallback;
    }
  }

  /// Resolve the audio URL for a verse via the QF recitations endpoint.
  /// Falls back to the legacy verses.quran.com path if the API call fails,
  /// so audio still works when the recitations endpoint is unavailable.
  ///
  /// Fallback triggers are reported to Crashlytics (non-fatal) and
  /// Analytics so silent 404s from a stale [reciterPath] or a QF outage
  /// become visible instead of leaving users with broken audio and no
  /// signal. If [reciterPath] is empty, the fallback URL would 404, so
  /// we rethrow the original error rather than return a known-bad URL.
  Future<String> _resolveAudioUrl(
    dynamic quranApi,
    int reciterId,
    String verseKey,
    String reciterPath,
  ) async {
    try {
      return await quranApi.getAudioUrl(reciterId, verseKey) as String;
    } catch (error, stack) {
      if (reciterPath.isEmpty) {
        SyncReporter.report(
          'audio · no fallback path',
          error,
          severity: SyncSeverity.quiet,
        );
        rethrow;
      }

      SyncReporter.report(
        'audio · QF fallback',
        error,
        severity: SyncSeverity.quiet,
      );
      unawaited(FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'audio fallback to verses.quran.com CDN',
        information: [
          'reciterId=$reciterId',
          'verseKey=$verseKey',
          'reciterPath=$reciterPath',
        ],
        fatal: false,
      ));
      unawaited(FirebaseAnalytics.instance.logEvent(
        name: 'audio_fallback_used',
        parameters: {
          'reciter_id': reciterId,
          'reciter_path': reciterPath,
          'verse_key': verseKey,
        },
      ).catchError((Object e) {
        SyncReporter.report('analytics', e, severity: SyncSeverity.quiet);
      }));

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
