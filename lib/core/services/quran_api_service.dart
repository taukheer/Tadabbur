import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/models/reciter.dart';
import 'package:tadabbur/core/models/surah.dart';
import 'package:tadabbur/core/models/word.dart';
import 'package:tadabbur/core/services/api_client.dart';

/// Service for fetching Quran content from the Quran Foundation API.
///
/// Wraps the QDC endpoints for verses, chapters, audio, tafsir, and
/// translations, parsing the JSON envelope structures specific to each
/// endpoint.
class QuranApiService {
  final ApiClient _client;

  /// Audio CDN base URL. The API returns relative audio paths that must
  /// be prefixed with this.
  static const String _audioCdnBase = 'https://audio.qurancdn.com/';

  QuranApiService(this._client);

  // ---------------------------------------------------------------------------
  // Verses
  // ---------------------------------------------------------------------------

  /// Fetches all verses for a given [chapterNum] (1-114).
  ///
  /// Optional [translationId] adds a specific translation resource.
  /// Optional [language] sets the response language (default: 'en').
  ///
  /// QDC response shape: `{"verses": [...]}`
  Future<List<Ayah>> getVersesByChapter(
    int chapterNum, {
    String? translationId,
    String? language,
  }) async {
    final queryParams = <String, dynamic>{
      if (language != null) 'language': language,
      if (translationId != null) 'translations': translationId,
      'fields': 'text_uthmani,text_simple',
    };

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/verses/by_chapter/$chapterNum',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data == null || data['verses'] == null) {
        return [];
      }

      final versesList = data['verses'] as List<dynamic>;
      return versesList
          .map((json) => _parseVerseJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch verses: $e');
    }
  }

  /// Fetches a single verse by its key (e.g. "2:255").
  ///
  /// QDC response shape: `{"verse": {...}}`
  Future<Ayah> getVerseByKey(
    String verseKey, {
    String? translationId,
  }) async {
    final queryParams = <String, dynamic>{
      'translations': translationId ?? '20',
      'fields': 'text_uthmani,text_simple,chapter_id,verse_number,juz_number,hizb_number,page_number',
      'language': 'en',
    };

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/verses/by_key/$verseKey',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data == null || data['verse'] == null) {
        throw ApiException(
          message: 'Verse not found: $verseKey',
          statusCode: 404,
        );
      }

      return _parseVerseJson(data['verse'] as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch verse $verseKey: $e');
    }
  }

  /// Fetches word-by-word breakdown for a verse.
  ///
  /// Words are nested inside the verse response under the `words` array
  /// when the `word_fields` parameter is provided.
  Future<List<Word>> getWordsByVerse(String verseKey) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/verses/by_key/$verseKey',
        queryParameters: <String, dynamic>{
          'words': 'true',
          'word_fields': 'text_uthmani,char_type_name',
          'word_translation_language': 'en',
        },
      );

      final data = response.data;
      if (data == null || data['verse'] == null) {
        return [];
      }

      final verse = data['verse'] as Map<String, dynamic>;
      final words = verse['words'] as List<dynamic>?;
      if (words == null) {
        return [];
      }

      return words
          .map((json) => _parseWordJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'Failed to fetch words for $verseKey: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Audio
  // ---------------------------------------------------------------------------

  /// Returns the full audio URL for a specific verse and reciter.
  ///
  /// QDC endpoint: `/recitations/{reciter_id}/by_chapter/{chapter}`
  /// Response shape: `{"audio_files": [{"verse_key": "1:1", "url": "..."}]}`
  /// The `url` field is a relative path that needs the audio CDN prefix.
  Future<String> getAudioUrl(int reciterId, String verseKey) async {
    try {
      final parts = verseKey.split(':');
      final chapter = parts[0];
      final ayahNum = parts[1];

      final response = await _client.get<Map<String, dynamic>>(
        '/recitations/$reciterId/by_chapter/$chapter',
      );

      final data = response.data;
      if (data == null || data['audio_files'] == null) {
        throw ApiException(
          message: 'Audio not found for reciter $reciterId, chapter $chapter',
          statusCode: 404,
        );
      }

      final audioFiles = data['audio_files'] as List<dynamic>;
      // Find the audio file matching the specific verse
      final match = audioFiles.firstWhere(
        (f) => f['verse_key'] == verseKey ||
            f['verse_key'] == '$chapter:$ayahNum',
        orElse: () => audioFiles.isNotEmpty ? audioFiles.first : null,
      );

      if (match == null) {
        throw ApiException(
          message: 'No audio files available for $verseKey',
          statusCode: 404,
        );
      }

      final fileMap = match as Map<String, dynamic>;
      final relativePath = fileMap['url'] as String;

      // The API returns a relative path; prepend the CDN base URL.
      if (relativePath.startsWith('http')) {
        return relativePath;
      }
      return '$_audioCdnBase$relativePath';
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch audio URL: $e');
    }
  }

  /// Fetches the list of available reciters.
  ///
  /// QDC response shape: `{"reciters": [...]}`
  Future<List<Reciter>> getReciters() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/resources/recitations',
      );

      final data = response.data;
      if (data == null || data['recitations'] == null) {
        return [];
      }

      final recitersList = data['recitations'] as List<dynamic>;
      return recitersList
          .map(
            (json) => Reciter.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch reciters: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Chapters
  // ---------------------------------------------------------------------------

  /// Fetches the list of all 114 chapters (surahs).
  ///
  /// QDC response shape: `{"chapters": [...]}`
  Future<List<Surah>> getAllChapters({String? language}) async {
    final queryParams = <String, dynamic>{
      if (language != null) 'language': language,
    };

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/chapters',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data == null || data['chapters'] == null) {
        return [];
      }

      final chaptersList = data['chapters'] as List<dynamic>;
      return chaptersList
          .map(
            (json) => _parseChapterJson(json as Map<String, dynamic>),
          )
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch chapters: $e');
    }
  }

  /// Fetches a single chapter by number (1-114).
  ///
  /// QDC response shape: `{"chapter": {...}}`
  Future<Surah> getChapter(int chapterNum) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/chapters/$chapterNum',
      );

      final data = response.data;
      if (data == null || data['chapter'] == null) {
        throw ApiException(
          message: 'Chapter not found: $chapterNum',
          statusCode: 404,
        );
      }

      return _parseChapterJson(data['chapter'] as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch chapter $chapterNum: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Tafsir
  // ---------------------------------------------------------------------------

  /// Fetches tafsir text for a verse from a specific tafsir source.
  ///
  /// [tafsirSlug] identifies the tafsir (e.g. "en-tafisr-ibn-kathir").
  /// QDC response shape: `{"tafsir": {"text": "..."}}`
  Future<String> getTafsir(String tafsirSlug, String verseKey) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/tafsirs/$tafsirSlug/by_ayah/$verseKey',
      );

      final data = response.data;
      if (data == null || data['tafsir'] == null) {
        throw ApiException(
          message:
              'Tafsir not found for $tafsirSlug, verse $verseKey',
          statusCode: 404,
        );
      }

      final tafsir = data['tafsir'] as Map<String, dynamic>;
      return tafsir['text'] as String? ?? '';
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch tafsir: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Translations
  // ---------------------------------------------------------------------------

  /// Fetches the list of available translation resources.
  ///
  /// QDC response shape: `{"translations": [...]}`
  Future<List<Map<String, dynamic>>> getTranslations() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/resources/translations',
      );

      final data = response.data;
      if (data == null || data['translations'] == null) {
        return [];
      }

      final translationsList = data['translations'] as List<dynamic>;
      return translationsList
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch translations: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // JSON parsing helpers
  // ---------------------------------------------------------------------------

  /// Parses a verse JSON object into an [Ayah].
  ///
  /// Handles the QDC verse structure including nested `translations` array
  /// and `translated_name` object.
  Ayah _parseVerseJson(Map<String, dynamic> json) {
    // Extract translation text if translations array is present.
    String? translationText;
    String? translationAuthor;
    final translations = json['translations'] as List<dynamic>?;
    if (translations != null && translations.isNotEmpty) {
      final firstTranslation = translations[0] as Map<String, dynamic>;
      translationText = firstTranslation['text'] as String?;
      // Strip HTML tags and footnote references from translation
      if (translationText != null) {
        translationText = translationText
            .replaceAll(RegExp(r'<[^>]*>'), '')    // HTML tags
            .replaceAll(RegExp(r',\d+'), '')        // ",1" footnote refs anywhere
            .replaceAll(RegExp(r'\[\d+\]'), '')     // [1] style footnotes
            .replaceAll(RegExp(r'\s+'), ' ')        // collapse whitespace
            .trim();
      }
      translationAuthor = firstTranslation['resource_name'] as String?;
    }

    return Ayah(
      id: json['id'] as int,
      verseKey: json['verse_key'] as String,
      surahNumber: json['chapter_id'] as int? ??
          _surahNumberFromKey(json['verse_key'] as String),
      ayahNumber: json['verse_number'] as int? ??
          _ayahNumberFromKey(json['verse_key'] as String),
      textUthmani: json['text_uthmani'] as String? ?? '',
      textSimple: json['text_simple'] as String?,
      translationText: translationText ?? json['translation_text'] as String?,
      translationAuthor:
          translationAuthor ?? json['translation_author'] as String?,
      juzNumber: json['juz_number'] as int?,
      hizbNumber: json['hizb_number'] as int?,
      rukuNumber: json['ruku_number'] as int?,
      pageNumber: json['page_number'] as int?,
    );
  }

  /// Parses a word JSON object into a [Word].
  ///
  /// Handles the nested `translation` and `transliteration` objects
  /// in the QDC response.
  Word _parseWordJson(Map<String, dynamic> json) {
    // translation can be a nested object: {"text": "...", "language_name": "..."}
    String? translationText;
    final translation = json['translation'];
    if (translation is Map<String, dynamic>) {
      translationText = translation['text'] as String?;
    } else if (translation is String) {
      translationText = translation;
    }

    // transliteration can also be a nested object.
    String? transliterationText;
    final transliteration = json['transliteration'];
    if (transliteration is Map<String, dynamic>) {
      transliterationText = transliteration['text'] as String?;
    } else if (transliteration is String) {
      transliterationText = transliteration;
    }

    return Word(
      id: json['id'] as int,
      position: json['position'] as int,
      textUthmani: json['text_uthmani'] as String? ?? '',
      transliteration: transliterationText,
      translation: translationText,
      charTypeName: json['char_type_name'] as String?,
    );
  }

  /// Parses a chapter JSON object into a [Surah].
  ///
  /// Handles the QDC chapter structure including the nested
  /// `translated_name` object.
  Surah _parseChapterJson(Map<String, dynamic> json) {
    // translated_name can be a nested object: {"name": "...", "language_name": "..."}
    String? translatedName;
    final tn = json['translated_name'];
    if (tn is Map<String, dynamic>) {
      translatedName = tn['name'] as String?;
    } else if (tn is String) {
      translatedName = tn;
    }

    return Surah(
      id: json['id'] as int,
      nameArabic: json['name_arabic'] as String,
      nameSimple: json['name_simple'] as String,
      nameComplex: json['name_complex'] as String,
      translatedName: translatedName,
      revelationType: json['revelation_place'] as String? ??
          json['revelation_type'] as String? ??
          '',
      versesCount: json['verses_count'] as int,
      pages: (json['pages'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  /// Extracts the surah number from a verse key like "2:255".
  int _surahNumberFromKey(String verseKey) {
    return int.parse(verseKey.split(':').first);
  }

  /// Extracts the ayah number from a verse key like "2:255".
  int _ayahNumberFromKey(String verseKey) {
    return int.parse(verseKey.split(':').last);
  }
}
