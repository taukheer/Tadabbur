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

  /// In-memory cache of editorial content, keyed by verse_key.
  Map<String, EditorialContent>? _cache;

  /// Whether the editorial data has been loaded at least once.
  bool get isLoaded => _cache != null;

  /// Loads and caches the editorial JSON from the app bundle.
  ///
  /// Returns the parsed map of verse_key to [EditorialContent].
  /// Subsequent calls return the cached data without re-reading the asset.
  Future<Map<String, EditorialContent>> _loadEditorialData() async {
    if (_cache != null) {
      return _cache!;
    }

    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final jsonData = json.decode(jsonString);

      // Support both plain array and {"editorial": [...]} wrapper
      final List<dynamic> editorialList;
      if (jsonData is List) {
        editorialList = jsonData;
      } else if (jsonData is Map && jsonData['editorial'] is List) {
        editorialList = jsonData['editorial'] as List<dynamic>;
      } else {
        _cache = {};
        return _cache!;
      }

      _cache = {};
      for (final item in editorialList) {
        final content =
            EditorialContent.fromJson(item as Map<String, dynamic>);
        _cache![content.verseKey] = content;
      }

      return _cache!;
    } on Exception {
      // Asset file not found. Return empty cache so callers get null
      // gracefully rather than crashing.
      _cache = {};
      return _cache!;
    } catch (e) {
      // Malformed JSON or other parse error.
      _cache = {};
      return _cache!;
    }
  }

  /// Returns the editorial content for a specific verse, or `null` if
  /// no editorial content exists for that verse key.
  ///
  /// [verseKey] should be in the format "surah:ayah" (e.g. "2:255").
  Future<EditorialContent?> getEditorialContent(String verseKey) async {
    final data = await _loadEditorialData();
    return data[verseKey];
  }

  /// Returns the surah introduction text for a given surah number, or
  /// `null` if no introduction is available.
  ///
  /// Searches for the first editorial entry for the surah that has a
  /// non-empty `surahIntroduction` field. Typically this is stored on
  /// the first verse of the surah (e.g. "1:1", "2:1").
  Future<String?> getSurahIntroduction(int surahNumber) async {
    final data = await _loadEditorialData();

    // Look for the first verse of the surah first (most likely location).
    final firstVerseKey = '$surahNumber:1';
    final firstVerseContent = data[firstVerseKey];
    if (firstVerseContent?.surahIntroduction != null &&
        firstVerseContent!.surahIntroduction!.isNotEmpty) {
      return firstVerseContent.surahIntroduction;
    }

    // Fall back to scanning all entries for this surah.
    for (final entry in data.values) {
      if (entry.verseKey.startsWith('$surahNumber:') &&
          entry.surahIntroduction != null &&
          entry.surahIntroduction!.isNotEmpty) {
        return entry.surahIntroduction;
      }
    }

    return null;
  }

  /// Returns all editorial content entries.
  ///
  /// Useful for pre-populating caches or building index screens.
  Future<List<EditorialContent>> getAllEditorial() async {
    final data = await _loadEditorialData();
    return data.values.toList();
  }

  /// Clears the in-memory cache, forcing a reload on the next access.
  ///
  /// Useful for testing or when the asset may have been updated
  /// (e.g. after a hot reload during development).
  void clearCache() {
    _cache = null;
  }
}
