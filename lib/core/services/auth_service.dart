import 'package:google_sign_in/google_sign_in.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });
}

class AuthService {
  final LocalStorageService _storage;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  AuthUser? _currentUser;

  AuthService(this._storage);

  AuthUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// Try to restore previous sign-in silently.
  Future<AuthUser?> tryAutoSignIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = AuthUser(
          id: account.id,
          name: account.displayName ?? 'User',
          email: account.email,
          photoUrl: account.photoUrl,
        );
        await _saveUser();
        return _currentUser;
      }
    } catch (_) {}

    // Check local storage for cached user
    final name = _storage.userId;
    if (name != null && name != 'guest' && name != 'local') {
      _currentUser = AuthUser(
        id: name,
        name: _storage.notificationTime ?? 'User', // reusing field temporarily
        email: '',
      );
    }
    return _currentUser;
  }

  /// Sign in with Google.
  Future<AuthUser?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // User cancelled

      _currentUser = AuthUser(
        id: account.id,
        name: account.displayName ?? 'User',
        email: account.email,
        photoUrl: account.photoUrl,
      );

      await _saveUser();
      return _currentUser;
    } catch (e) {
      return null;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    await _storage.clearAuth();
  }

  Future<void> _saveUser() async {
    if (_currentUser != null) {
      await _storage.setUserId(_currentUser!.id);
      await _storage.setAuthToken('google_${_currentUser!.id}');
    }
  }
}
