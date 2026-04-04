import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    );
  }
}

final dailyAyahProvider =
    StateNotifierProvider<DailyAyahNotifier, DailyAyahState>((ref) {
  return DailyAyahNotifier(ref);
});

class DailyAyahNotifier extends StateNotifier<DailyAyahState> {
  final Ref _ref;

  DailyAyahNotifier(this._ref) : super(const DailyAyahState()) {
    loadDailyAyah();
  }

  Future<void> loadDailyAyah() async {
    state = state.copyWith(loadingState: AyahLoadingState.loading);

    try {
      final progress = _ref.read(userProgressProvider);
      final verseKey = progress.currentVerseKey;
      final quranApi = _ref.read(quranApiProvider);
      final editorialService = _ref.read(editorialServiceProvider);
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

      // Fetch ayah data, words, and editorial in parallel
      final results = await Future.wait([
        quranApi.getVerseByKey(verseKey,
            translationId: storage.translationId.toString()),
        quranApi.getWordsByVerse(verseKey),
        editorialService.getEditorialContent(verseKey),
      ]);

      final ayah = results[0] as Ayah;
      final words = results[1] as List<Word>;
      final editorial = results[2] as EditorialContent?;

      // Build audio URL from CDN with selected reciter
      final reciterPath = storage.reciterPath;
      final parts = verseKey.split(':');
      final chapterPadded = parts[0].padLeft(3, '0');
      final versePadded = parts[1].padLeft(3, '0');
      final audioUrl =
          'https://verses.quran.com/$reciterPath/mp3/$chapterPadded$versePadded.mp3';

      state = state.copyWith(
        loadingState: AyahLoadingState.loaded,
        ayah: ayah,
        words: words,
        editorial: editorial,
        audioUrl: audioUrl,
        todayCompleted: todayCompleted,
      );
    } catch (e) {
      state = state.copyWith(
        loadingState: AyahLoadingState.error,
        errorMessage: e.toString(),
      );
    }
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
