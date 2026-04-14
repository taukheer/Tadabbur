import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tadabbur/core/services/local_storage_service.dart' show LocalStorageService, AuthType;
import 'package:tadabbur/core/services/auth_service.dart' show AuthUser;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Quran Foundation OAuth2 PKCE authentication service.
///
/// Credentials are injected at build time via --dart-define:
///   flutter build apk \
///     --dart-define=QF_CLIENT_ID=... \
///     --dart-define=QF_CLIENT_SECRET=... \
///     --dart-define=QF_AUTH_ENDPOINT=...
class QFAuthService {
  final LocalStorageService _storage;

  // Injected at build time — never hardcoded in source
  static const _clientId = String.fromEnvironment(
    'QF_CLIENT_ID',
    defaultValue: '',
  );
  static const _clientSecret = String.fromEnvironment(
    'QF_CLIENT_SECRET',
    defaultValue: '',
  );
  static const _authEndpoint = String.fromEnvironment(
    'QF_AUTH_ENDPOINT',
    defaultValue: 'https://oauth2.quran.foundation',
  );
  static const _redirectUri = 'com.tadabbur.tadabbur://oauth/callback';

  // OAuth2 endpoints
  static const _authorizeUrl = '$_authEndpoint/oauth2/auth';
  static const _tokenUrl = '$_authEndpoint/oauth2/token';

  QFAuthService(this._storage);

  // Deduplication guard — when two deep-link handlers fire in parallel
  // for the same OAuth callback, we reuse the in-flight Future instead
  // of running two concurrent token exchanges (which race to redeem
  // the same single-use authorization code).
  Future<AuthUser?>? _inFlightExchange;

  String? get accessToken => _storage.authToken;
  bool get isAuthenticated =>
      _storage.authToken != null &&
      _storage.authType == AuthType.quranFoundation;

  /// Generate PKCE code verifier and challenge.
  static ({String verifier, String challenge}) _generatePKCE() {
    final random = Random.secure();
    final verifier = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');

    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    final challenge =
        base64UrlEncode(digest.bytes).replaceAll('=', '');

    return (verifier: verifier, challenge: challenge);
  }

  /// Start the OAuth2 PKCE flow by opening the browser.
  /// Returns the authorization URL and stores the code verifier.
  Future<String> getAuthorizationUrl() async {
    final pkce = _generatePKCE();

    // Store verifier for token exchange
    await _storage.setCodeVerifier(pkce.verifier);

    // Generate and store state parameter for CSRF protection
    final state = base64UrlEncode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    await _storage.setOAuthState(state);

    // Scopes requested. Per QF support: pre-live clients only accept
    // *parent* scope names (`note`, `bookmark`, `activity_day`, ...),
    // not the dotted child forms (`note.create`, `note.read`, ...).
    // Each parent scope grants read + write on that resource family.
    //   openid, offline_access — OIDC auth + refresh tokens
    //   note                     — POST/GET /v1/notes (reflections)
    //   bookmark                 — POST/GET/DELETE /v1/bookmarks
    //   activity_day             — POST/GET /v1/activity-days
    //   streak                   — GET /v1/streaks
    //   preference               — GET/POST /v1/preferences
    const scopes = 'openid offline_access '
        'note bookmark activity_day streak preference';

    final params = {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': scopes,
      'code_challenge': pkce.challenge,
      'code_challenge_method': 'S256',
      'state': state,
    };

    final uri = Uri.parse(_authorizeUrl).replace(queryParameters: params);
    return uri.toString();
  }

  /// Validate the OAuth state parameter against the stored value (CSRF protection).
  Future<bool> validateState(String state) async {
    final storedState = await _storage.getOAuthState();
    if (storedState == null || storedState != state) {
      debugPrint('[QFAuth] State mismatch — possible CSRF attack');
      return false;
    }
    return true;
  }

  /// Exchange the authorization code for tokens.
  /// [state] is validated against the stored value for CSRF protection.
  ///
  /// Uses HTTP Basic auth for client credentials (`client_secret_basic`),
  /// which is the OAuth2 RFC 6749 recommended method and Ory Hydra's
  /// default `token_endpoint_auth_method`.
  ///
  /// Returns the authenticated [AuthUser] parsed from the id_token on
  /// success, or `null` on failure. Safe to call multiple times with the
  /// same code — duplicate concurrent calls reuse the same in-flight
  /// Future instead of double-redeeming.
  Future<AuthUser?> exchangeCode(String code, {required String state}) {
    final existing = _inFlightExchange;
    if (existing != null) {
      debugPrint('[QFAuth] exchange already in flight — reusing future');
      return existing;
    }
    final future = _doExchange(code, state: state);
    _inFlightExchange = future;
    future.whenComplete(() => _inFlightExchange = null);
    return future;
  }

  Future<AuthUser?> _doExchange(String code, {required String state}) async {
    // Validate state parameter before proceeding
    if (!await validateState(state)) return null;

    final verifier = await _storage.getCodeVerifier();
    if (verifier == null) return null;

    try {
      final dio = Dio();
      final basicAuth =
          base64.encode(utf8.encode('$_clientId:$_clientSecret'));

      debugPrint('[QFAuth] POST $_tokenUrl (exchange)');
      final response = await dio.post<Map<String, dynamic>>(
        _tokenUrl,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Authorization': 'Basic $basicAuth',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': verifier,
        },
      );

      debugPrint('[QFAuth] exchange response: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('[QFAuth] exchange error body: ${response.data}');
        return null;
      }

      final data = response.data;
      if (data == null) {
        debugPrint('[QFAuth] exchange response empty body');
        return null;
      }

      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      final idToken = data['id_token'] as String?;

      if (accessToken != null) {
        await _storage.setAuthToken(accessToken);
        if (refreshToken != null) {
          await _storage.setRefreshToken(refreshToken);
        }
        // Mark the user as authenticated via Quran Foundation so the
        // settings screen and any other auth-aware UI show the right
        // state.
        await _storage.setAuthType(AuthType.quranFoundation);
        // Clear the code verifier and OAuth state — no longer needed
        await _storage.setCodeVerifier(null);
        await _storage.setOAuthState(null);

        // Parse the OIDC id_token to extract the real user profile
        // (name, email, sub, picture). Falls back to a placeholder
        // AuthUser if the id_token is missing or can't be parsed.
        final user = _parseIdToken(idToken) ??
            const AuthUser(
              id: 'qf-user',
              name: 'Quran.com User',
              email: '',
              photoUrl: null,
            );
        debugPrint('[QFAuth] Successfully authenticated as ${user.name}');
        return user;
      }
    } catch (e) {
      debugPrint('[QFAuth] Token exchange failed: $e');
    }
    return null;
  }

  /// Parses a base64url-encoded OIDC id_token JWT and builds an [AuthUser]
  /// from the standard claims. Returns `null` on any parse failure.
  ///
  /// Note: we intentionally do NOT validate the JWT signature here — the
  /// id_token arrived over TLS from the token endpoint we just successfully
  /// authenticated against, so we already trust its contents.
  AuthUser? _parseIdToken(String? idToken) {
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      final name = payload['name'] as String? ??
          payload['preferred_username'] as String? ??
          payload['given_name'] as String? ??
          payload['email'] as String? ??
          'Quran.com User';
      final email = payload['email'] as String? ?? '';
      final id = payload['sub'] as String? ?? 'qf-user';
      final photoUrl = payload['picture'] as String?;

      return AuthUser(
        id: id,
        name: name,
        email: email,
        photoUrl: photoUrl,
      );
    } catch (e) {
      debugPrint('[QFAuth] failed to parse id_token: $e');
      return null;
    }
  }

  /// Refresh the access token using the refresh token.
  /// Uses HTTP Basic auth to match Hydra's default `client_secret_basic`.
  Future<bool> refreshAccessToken() async {
    final refreshToken = _storage.refreshToken;
    if (refreshToken == null) return false;

    try {
      final dio = Dio();
      final basicAuth =
          base64.encode(utf8.encode('$_clientId:$_clientSecret'));

      final response = await dio.post<Map<String, dynamic>>(
        _tokenUrl,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Authorization': 'Basic $basicAuth',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[QFAuth] refresh error: ${response.statusCode} ${response.data}',
        );
        return false;
      }

      final data = response.data;
      if (data == null) return false;

      final newAccessToken = data['access_token'] as String?;
      final newRefreshToken = data['refresh_token'] as String?;

      if (newAccessToken != null) {
        await _storage.setAuthToken(newAccessToken);
        if (newRefreshToken != null) {
          await _storage.setRefreshToken(newRefreshToken);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[QFAuth] Token refresh failed: $e');
    }
    return false;
  }

  /// Open the QF login page in browser.
  Future<void> launchLogin() async {
    debugPrint('[QFAuth] launchLogin() — opening browser to QF authorize URL');
    final url = await getAuthorizationUrl();
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Sign out — clear tokens.
  Future<void> signOut() async {
    await _storage.clearAuth();
  }
}
