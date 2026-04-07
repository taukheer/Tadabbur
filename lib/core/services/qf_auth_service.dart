import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
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
    defaultValue: 'https://prelive-oauth2.quran.foundation',
  );
  static const _redirectUri = 'com.tadabbur.tadabbur://oauth/callback';

  // OAuth2 endpoints
  static const _authorizeUrl = '$_authEndpoint/oauth2/auth';
  static const _tokenUrl = '$_authEndpoint/oauth2/token';

  QFAuthService(this._storage);

  String? get accessToken => _storage.authToken;
  bool get isAuthenticated =>
      _storage.authToken != null &&
      _storage.authToken != 'guest' &&
      !_storage.authToken!.startsWith('google_');

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

    final params = {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': 'openid offline_access',
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
  Future<bool> exchangeCode(String code, {required String state}) async {
    // Validate state parameter before proceeding
    if (!await validateState(state)) return false;

    final verifier = await _storage.getCodeVerifier();
    if (verifier == null) return false;

    try {
      final dio = Dio();
      final response = await dio.post(
        _tokenUrl,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
        data: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': verifier,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;

        if (accessToken != null) {
          await _storage.setAuthToken(accessToken);
          if (refreshToken != null) {
            await _storage.setRefreshToken(refreshToken);
          }
          // Clear the code verifier and OAuth state — no longer needed
          await _storage.setCodeVerifier(null);
          await _storage.setOAuthState(null);
          debugPrint('[QFAuth] Successfully authenticated with QF OAuth2');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[QFAuth] Token exchange failed: $e');
    }
    return false;
  }

  /// Refresh the access token using the refresh token.
  Future<bool> refreshAccessToken() async {
    final refreshToken = _storage.refreshToken;
    if (refreshToken == null) return false;

    try {
      final dio = Dio();
      final response = await dio.post(
        _tokenUrl,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
        data: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken != null) {
          await _storage.setAuthToken(newAccessToken);
          if (newRefreshToken != null) {
            await _storage.setRefreshToken(newRefreshToken);
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('[QFAuth] Token refresh failed: $e');
    }
    return false;
  }

  /// Open the QF login page in browser.
  Future<void> launchLogin() async {
    final url = await getAuthorizationUrl();
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Sign out — clear tokens.
  Future<void> signOut() async {
    await _storage.clearAuth();
  }
}
