import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tadabbur/core/models/editorial_content.dart';

/// Service for loading editorial content from local JSON asset files.
///
/// For the MVP, all editorial content (historical context, scholar reflections,
/// surah introductions, reflection prompts) is bundled as a JSON asset at
/// `assets/data/editorial.json`. This service loads and caches that data
/// in memory.
///
/// Expected JSON structure:
/// ```json
/// {
///   "editorial": [
///     {
///       "verse_key": "1:1",
///       "historical_context": "...",
///       "scholar_reflection": "...",
///       "scholar_name": "...",
///       "tier2_prompt": "...",
///       "tier3_question": "...",
///       "surah_introduction": "..."
///     }
///   ]
/// }
/// ```
class EditorialService {
  static const String _assetPath = 'assets/data/editorial_content.json';

  /// Supported editorial languages — only show editorial for these.
  static const supportedLanguages = {'en', 'ar'};

  /// In-memory cache of editorial content, keyed by language then verse_key.
  final Map<String, Map<String, EditorialContent>> _cache = {};

  /// Loads and caches the editorial JSON for a given language.
  Future<Map<String, EditorialContent>> _loadEditorialData(String lang) async {
    if (_cache.containsKey(lang)) {
      return _cache[lang]!;
    }

    // Language-specific file, falling back to English
    final assetPath = lang == 'en'
        ? _assetPath
        : 'assets/data/editorial_content_$lang.json';

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = json.decode(jsonString);

      final List<dynamic> editorialList;
      if (jsonData is List) {
        editorialList = jsonData;
      } else if (jsonData is Map && jsonData['editorial'] is List) {
        editorialList = jsonData['editorial'] as List<dynamic>;
      } else {
        _cache[lang] = {};
        return _cache[lang]!;
      }

      _cache[lang] = {};
      for (final item in editorialList) {
        final content =
            EditorialContent.fromJson(item as Map<String, dynamic>);
        _cache[lang]![content.verseKey] = content;
      }

      return _cache[lang]!;
    } catch (_) {
      // Asset file not found or parse error — fall back to English
      if (lang != 'en') {
        return _loadEditorialData('en');
      }
      _cache[lang] = {};
      return _cache[lang]!;
    }
  }

  /// Returns the editorial content for a specific verse in the given language.
  /// Returns `null` if no editorial exists or the language is not supported.
  Future<EditorialContent?> getEditorialContent(
    String verseKey, {
    String lang = 'en',
  }) async {
    if (!supportedLanguages.contains(lang)) return null;
    final data = await _loadEditorialData(lang);
    return data[verseKey];
  }

  /// Returns the surah introduction text for a given surah number, or
  /// `null` if no introduction is available.
  ///
  /// Searches for the first editorial entry for the surah that has a
  /// non-empty `surahIntroduction` field. Typically this is stored on
  /// the first verse of the surah (e.g. "1:1", "2:1").
  Future<String?> getSurahIntroduction(int surahNumber, {String lang = 'en'}) async {
    if (!supportedLanguages.contains(lang)) return null;
    final data = await _loadEditorialData(lang);

    final firstVerseKey = '$surahNumber:1';
    final firstVerseContent = data[firstVerseKey];
    if (firstVerseContent?.surahIntroduction != null &&
        firstVerseContent!.surahIntroduction!.isNotEmpty) {
      return firstVerseContent.surahIntroduction;
    }

    for (final entry in data.values) {
      if (entry.verseKey.startsWith('$surahNumber:') &&
          entry.surahIntroduction != null &&
          entry.surahIntroduction!.isNotEmpty) {
        return entry.surahIntroduction;
      }
    }

    return null;
  }

  /// Returns all editorial content entries for a language.
  Future<List<EditorialContent>> getAllEditorial({String lang = 'en'}) async {
    final data = await _loadEditorialData(lang);
    return data.values.toList();
  }

  /// Clears the in-memory cache, forcing a reload on the next access.
  void clearCache() {
    _cache.clear();
  }
}
