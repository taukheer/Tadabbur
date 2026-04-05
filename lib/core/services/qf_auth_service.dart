import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Quran Foundation OAuth2 PKCE authentication service.
class QFAuthService {
  final LocalStorageService _storage;

  // Pre-Production (Test) credentials
  static const _clientId = '196d8690-730e-42f4-bf14-07b67adb6ad5';
  static const _clientSecret = 'I3-8Jr_K6usN68LZ.6EB9S30z7';
  static const _authEndpoint = 'https://prelive-oauth2.quran.foundation';
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
    await _storage.setRefreshToken(pkce.verifier); // reusing field temporarily

    final params = {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': 'openid offline_access',
      'code_challenge': pkce.challenge,
      'code_challenge_method': 'S256',
      'state': base64UrlEncode(
        List<int>.generate(16, (_) => Random.secure().nextInt(256)),
      ),
    };

    final uri = Uri.parse(_authorizeUrl).replace(queryParameters: params);
    return uri.toString();
  }

  /// Exchange the authorization code for tokens.
  Future<bool> exchangeCode(String code) async {
    final verifier = _storage.refreshToken; // stored during getAuthorizationUrl
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
