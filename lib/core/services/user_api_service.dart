import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tadabbur/core/services/api_client.dart' show ApiException;
import 'package:tadabbur/core/services/local_storage_service.dart';

/// Service for Quran Foundation User API operations.
///
/// Uses its OWN Dio client, separate from the content-API `ApiClient`:
/// - Content API lives at `api.qurancdn.com/api/qdc` (public, no auth).
/// - User API lives at `apis.quran.foundation/auth/v1` (pre-prod:
///   `apis-prelive.quran.foundation/auth/v1`) and needs two headers:
///   `x-auth-token` (the JWT access token) and `x-client-id`.
///
/// Base URL and client id are injected at build time via --dart-define.
class UserApiService {
  final LocalStorageService _storage;
  final Future<bool> Function()? _onRefreshToken;
  late final Dio _dio;

  static const _baseUrl = String.fromEnvironment(
    'QF_USER_API_BASE',
    defaultValue: 'https://apis-prelive.quran.foundation/auth',
  );
  static const _clientId = String.fromEnvironment(
    'QF_CLIENT_ID',
    defaultValue: '',
  );

  // Mushaf ID 4 = UthmaniHafs — matches the script used for
  // text_uthmani in the content API.
  static const _mushafId = 4;

  UserApiService(this._storage, {Future<bool> Function()? onRefreshToken})
      : _onRefreshToken = onRefreshToken {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-client-id': _clientId,
      },
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Only attach the QF bearer token when the user is actually
        // signed in via Quran Foundation OAuth. Google/Apple sign-ins
        // give us tokens that the QF User API will reject with 401.
        if (_storage.authType == AuthType.quranFoundation) {
          final token = _storage.authToken;
          if (token != null && token.isNotEmpty) {
            options.headers['x-auth-token'] = token;
          }
        }
        handler.next(options);
      },
      onError: (DioException err, handler) async {
        // 401 → try a single token refresh + retry. Anything else
        // (or a second 401 after refresh) flows through unchanged.
        if (err.response?.statusCode == 401 &&
            _onRefreshToken != null &&
            _storage.authType == AuthType.quranFoundation &&
            err.requestOptions.extra['__retried'] != true) {
          debugPrint('[UserApi] 401 → attempting token refresh');
          try {
            final refreshed = await _onRefreshToken();
            if (refreshed) {
              final newToken = _storage.authToken;
              if (newToken != null && newToken.isNotEmpty) {
                final retryOptions = err.requestOptions
                  ..headers['x-auth-token'] = newToken
                  ..extra['__retried'] = true;
                final response = await _dio.fetch(retryOptions);
                return handler.resolve(response);
              }
            }
          } catch (e) {
            debugPrint('[UserApi] refresh+retry failed: $e');
          }
        }
        handler.next(err);
      },
    ));
  }

  /// Whether the current user is signed in via QF OAuth (the only auth
  /// type that can use the User APIs). Methods short-circuit on false so
  /// guest / Google / Apple users don't generate 401 noise.
  bool get _canCallUserApi =>
      _storage.authType == AuthType.quranFoundation &&
      _storage.authToken != null &&
      _storage.authToken!.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Reflections (Notes)
  // ---------------------------------------------------------------------------

  /// Saves a user reflection as a Quran Foundation note tied to a verse.
  ///
  /// QF has two post-like endpoints: `/v1/posts` (social Quran Reflect
  /// posts requiring a `roomId` and other social fields) and `/v1/notes`
  /// (personal reflections attached to verse ranges). Tadabbur
  /// reflections are personal, so we use `/v1/notes`.
  ///
  /// The server enforces a minimum body length of 6 characters; short
  /// acknowledgements are padded to satisfy that.
  Future<void> saveReflection(
    String verseKey,
    String body, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!_canCallUserApi) return;
    debugPrint('[UserApi] POST /v1/notes — saveReflection($verseKey)');
    try {
      final safeBody = body.length >= 6
          ? body
          : '$body — Tadabbur reflection on $verseKey';

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/notes',
        data: {
          'body': safeBody,
          'saveToQR': false,
          'ranges': ['$verseKey-$verseKey'],
        },
      );
      debugPrint('[UserApi] POST /v1/notes → ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] POST /v1/notes failed: ${e.response?.statusCode} '
        '${e.response?.data}',
      );
      throw ApiException(
        message: 'Save reflection failed: ${e.response?.statusCode}',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  /// Fetches the user's notes (pagination via cursor).
  Future<List<Map<String, dynamic>>> getReflections({
    int? first,
    String? after,
  }) async {
    if (!_canCallUserApi) return [];
    debugPrint('[UserApi] GET /v1/notes — getReflections');
    final queryParams = <String, dynamic>{};
    if (first != null) queryParams['first'] = first;
    if (after != null) queryParams['after'] = after;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/notes',
        queryParameters: queryParams,
      );
      final data = response.data;
      if (data == null) return [];
      final list = (data['data'] ?? data['items'] ?? data['edges'])
          as List<dynamic>?;
      if (list == null) return [];
      return list.map((e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] GET /v1/notes failed: ${e.response?.statusCode} '
        '${e.response?.data}',
      );
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Streaks (read-only — server-derived from activity-days)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getStreak() async {
    if (!_canCallUserApi) return {};
    debugPrint('[UserApi] GET /v1/streaks — getStreak');
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/streaks');
      return response.data ?? {};
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] GET /v1/streaks failed: ${e.response?.statusCode}',
      );
      return {};
    }
  }

  /// No-op. Streaks are derived on the server from logged activity days.
  /// There is no POST endpoint for streaks; calling [logActivityDay] is
  /// what moves the streak forward. This method stays for call-site
  /// compatibility with existing notifiers.
  Future<void> updateStreak() async {
    debugPrint(
      '[UserApi] updateStreak() no-op (streaks derive from activity-days)',
    );
  }

  // ---------------------------------------------------------------------------
  // Activity Days
  // ---------------------------------------------------------------------------

  /// Logs an activity day for the user's Quran reading session.
  ///
  /// QF expects `type`, `seconds`, `ranges`, and `mushafId` for a
  /// QURAN activity. We default to the current verse being marked as
  /// read for 60 seconds using mushaf 4 (UthmaniHafs).
  Future<void> logActivityDay(
    DateTime date, {
    String verseKey = '1:1',
    int seconds = 60,
  }) async {
    if (!_canCallUserApi) return;
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    debugPrint(
      '[UserApi] POST /v1/activity-days — logActivityDay($dateString, $verseKey)',
    );
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/activity-days',
        data: {
          'date': dateString,
          'type': 'QURAN',
          'seconds': seconds,
          'ranges': ['$verseKey-$verseKey'],
          'mushafId': _mushafId,
        },
      );
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] POST /v1/activity-days failed: ${e.response?.statusCode} '
        '${e.response?.data}',
      );
    }
  }

  Future<List<DateTime>> getActivityDays({
    DateTime? from,
    DateTime? to,
  }) async {
    if (!_canCallUserApi) return [];
    debugPrint('[UserApi] GET /v1/activity-days — getActivityDays');
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
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/activity-days',
        queryParameters: queryParams,
      );
      final data = response.data;
      if (data == null) return [];
      final days = (data['data'] ?? data['activity_days'] ?? data['items'])
          as List<dynamic>?;
      if (days == null) return [];
      return days
          .map((e) {
            if (e is String) return DateTime.parse(e);
            if (e is Map && e['date'] is String) {
              return DateTime.parse(e['date'] as String);
            }
            return null;
          })
          .whereType<DateTime>()
          .toList();
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] GET /v1/activity-days failed: ${e.response?.statusCode}',
      );
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------

  /// Adds an ayah bookmark.
  ///
  /// [verseKey] is in `surah:ayah` format (e.g. `2:255`). Parsed into
  /// the `{key, verseNumber}` pair QF expects.
  Future<void> addBookmark(String verseKey) async {
    if (!_canCallUserApi) return;
    debugPrint('[UserApi] POST /v1/bookmarks — addBookmark($verseKey)');
    final parts = verseKey.split(':');
    if (parts.length != 2) {
      debugPrint('[UserApi] invalid verseKey: $verseKey');
      return;
    }
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) {
      debugPrint('[UserApi] could not parse verseKey: $verseKey');
      return;
    }

    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/bookmarks',
        data: {
          'key': surah,
          'type': 'ayah',
          'verseNumber': ayah,
          'mushaf': _mushafId,
        },
      );
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] POST /v1/bookmarks failed: ${e.response?.statusCode} '
        '${e.response?.data}',
      );
    }
  }

  /// Fetches all of the user's bookmarks.
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    if (!_canCallUserApi) return [];
    debugPrint('[UserApi] GET /v1/bookmarks — getBookmarks');
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/bookmarks');
      final data = response.data;
      if (data == null) return [];
      final list = (data['data'] ?? data['bookmarks'] ?? data['items'])
          as List<dynamic>?;
      if (list == null) return [];
      return list.map((e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] GET /v1/bookmarks failed: ${e.response?.statusCode}',
      );
      return [];
    }
  }

  /// Removes a bookmark by its id.
  Future<void> removeBookmark(dynamic bookmarkId) async {
    if (!_canCallUserApi) return;
    debugPrint('[UserApi] DELETE /v1/bookmarks/$bookmarkId');
    try {
      await _dio.delete<Map<String, dynamic>>('/v1/bookmarks/$bookmarkId');
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] DELETE /v1/bookmarks failed: ${e.response?.statusCode}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getPreferences() async {
    if (!_canCallUserApi) return {};
    debugPrint('[UserApi] GET /v1/preferences — getPreferences');
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/v1/preferences');
      return response.data ?? {};
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] GET /v1/preferences failed: ${e.response?.statusCode}',
      );
      return {};
    }
  }

  Future<void> updatePreferences(Map<String, dynamic> prefs) async {
    if (!_canCallUserApi) return;
    debugPrint('[UserApi] POST /v1/preferences — updatePreferences');
    try {
      await _dio.post<Map<String, dynamic>>('/v1/preferences', data: prefs);
    } on DioException catch (e) {
      debugPrint(
        '[UserApi] POST /v1/preferences failed: ${e.response?.statusCode}',
      );
    }
  }
}
