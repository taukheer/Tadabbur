import 'package:tadabbur/core/services/api_client.dart';

/// Service for user-specific API operations that require authentication.
///
/// Handles reflections (posts), streaks, activity tracking, bookmarks,
/// and user preferences through the QDC user endpoints.
class UserApiService {
  final ApiClient _client;

  UserApiService(this._client);

  // ---------------------------------------------------------------------------
  // Reflections (Posts)
  // ---------------------------------------------------------------------------

  /// Saves a user reflection for a specific verse.
  ///
  /// [verseKey] identifies the verse (e.g. "2:255").
  /// [body] is the reflection text.
  /// [metadata] can include additional context like reflection tier, prompt, etc.
  Future<void> saveReflection(
    String verseKey,
    String body, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/posts',
        data: {
          'post': {
            'verse_key': verseKey,
            'body': body,
            if (metadata != null) ...metadata,
          },
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to save reflection: $e');
    }
  }

  /// Fetches the user's reflections with pagination.
  ///
  /// Returns a list of raw reflection maps from the API.
  Future<List<Map<String, dynamic>>> getReflections({
    int? page,
    int? perPage,
  }) async {
    final queryParams = <String, dynamic>{
      'page': ?page,
      'per_page': ?perPage,
    };

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/posts',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data == null || data['posts'] == null) {
        return [];
      }

      final postsList = data['posts'] as List<dynamic>;
      return postsList.map((e) => e as Map<String, dynamic>).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch reflections: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Streaks
  // ---------------------------------------------------------------------------

  /// Fetches the user's current streak information.
  ///
  /// Returns a map containing streak-related fields such as
  /// `current_streak`, `longest_streak`, etc.
  Future<Map<String, dynamic>> getStreak() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/streaks',
      );

      final data = response.data;
      if (data == null) {
        return {};
      }

      // The response may wrap streak data in a "streak" key.
      if (data.containsKey('streak')) {
        return data['streak'] as Map<String, dynamic>;
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch streak: $e');
    }
  }

  /// Updates (increments) the user's streak for the current day.
  Future<void> updateStreak() async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/streaks',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to update streak: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Activity Days
  // ---------------------------------------------------------------------------

  /// Logs an activity day for the user.
  ///
  /// [date] is the day to mark as active (time portion is ignored).
  Future<void> logActivityDay(DateTime date) async {
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      await _client.post<Map<String, dynamic>>(
        '/activity-days',
        data: {
          'date': dateString,
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to log activity day: $e');
    }
  }

  /// Fetches the user's activity days within an optional date range.
  ///
  /// Returns a list of [DateTime] objects representing active days.
  Future<List<DateTime>> getActivityDays({
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, dynamic>{};
    if (from != null) {
      queryParams['from'] =
          '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    }
    if (to != null) {
      queryParams['to'] =
          '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';
    }

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/activity-days',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data == null) {
        return [];
      }

      final days = data['activity_days'] as List<dynamic>?;
      if (days == null) {
        return [];
      }

      return days.map((e) => DateTime.parse(e as String)).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch activity days: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------

  /// Adds a bookmark for a specific verse.
  Future<void> addBookmark(String verseKey) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/user/bookmarks',
        data: {
          'bookmark': {
            'verse_key': verseKey,
          },
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to add bookmark: $e');
    }
  }

  /// Fetches all of the user's bookmarks.
  ///
  /// Returns a list of raw bookmark maps containing at minimum
  /// `id` and `verse_key`.
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/user/bookmarks',
      );

      final data = response.data;
      if (data == null || data['bookmarks'] == null) {
        return [];
      }

      final bookmarksList = data['bookmarks'] as List<dynamic>;
      return bookmarksList.map((e) => e as Map<String, dynamic>).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch bookmarks: $e');
    }
  }

  /// Removes a bookmark by its ID.
  Future<void> removeBookmark(int bookmarkId) async {
    try {
      await _client.delete<Map<String, dynamic>>(
        '/user/bookmarks/$bookmarkId',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to remove bookmark: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------

  /// Fetches the user's preferences.
  ///
  /// Returns a map of preference key-value pairs.
  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/user/preferences',
      );

      final data = response.data;
      if (data == null) {
        return {};
      }

      // Unwrap if nested under a "preferences" key.
      if (data.containsKey('preferences')) {
        return data['preferences'] as Map<String, dynamic>;
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch preferences: $e');
    }
  }

  /// Updates the user's preferences.
  ///
  /// [prefs] is a map of preference key-value pairs to set or update.
  Future<void> updatePreferences(Map<String, dynamic> prefs) async {
    try {
      await _client.put<Map<String, dynamic>>(
        '/user/preferences',
        data: {
          'preferences': prefs,
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to update preferences: $e');
    }
  }
}
