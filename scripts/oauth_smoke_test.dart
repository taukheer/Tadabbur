// Standalone OAuth URL smoke test.
//
// Mirrors the PKCE + state generation from QFAuthService.getAuthorizationUrl()
// and prints a fully-formed authorize URL. Curl that URL to confirm the
// pre-live OAuth server accepts it (expect a 200/302 with the consent page,
// not a 400 from a malformed request).
//
// Run with:
//   dart run scripts/oauth_smoke_test.dart \
//     --define=QF_CLIENT_ID=... \
//     --define=QF_AUTH_ENDPOINT=https://prelive-oauth2.quran.foundation

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';

const _clientId = String.fromEnvironment('QF_CLIENT_ID', defaultValue: '');
const _authEndpoint = String.fromEnvironment(
  'QF_AUTH_ENDPOINT',
  defaultValue: 'https://prelive-oauth2.quran.foundation',
);
const _redirectUri = 'com.tadabbur.tadabbur://oauth/callback';

void main() async {
  if (_clientId.isEmpty) {
    stderr.writeln('error: QF_CLIENT_ID not provided via --define');
    exit(1);
  }

  final random = Random.secure();
  final verifier = base64UrlEncode(
    List<int>.generate(32, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
  final challenge = base64UrlEncode(
    sha256.convert(utf8.encode(verifier)).bytes,
  ).replaceAll('=', '');
  final state = base64UrlEncode(
    List<int>.generate(32, (_) => random.nextInt(256)),
  ).replaceAll('=', '');

  // Verify challenge → verifier roundtrip by re-hashing
  final reHashed = base64UrlEncode(
    sha256.convert(utf8.encode(verifier)).bytes,
  ).replaceAll('=', '');
  if (reHashed != challenge) {
    stderr.writeln('error: PKCE challenge mismatch');
    exit(1);
  }
  print('PKCE verifier:  ${verifier.length} chars');
  print('PKCE challenge: ${challenge.length} chars');
  print('State:          ${state.length} chars (32 bytes = 256 bits)');
  print('');

  final params = {
    'client_id': _clientId,
    'response_type': 'code',
    'redirect_uri': _redirectUri,
    'scope': 'openid offline_access note bookmark activity_day streak preference',
    'code_challenge': challenge,
    'code_challenge_method': 'S256',
    'state': state,
  };
  final uri = Uri.parse('$_authEndpoint/oauth2/auth')
      .replace(queryParameters: params);
  print('Authorize URL:');
  print(uri.toString());
}
