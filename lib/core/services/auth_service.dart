import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:tadabbur/core/models/user_progress.dart';
import 'package:tadabbur/core/services/firestore_service.dart';
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
  final FirestoreService _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  AuthUser? _currentUser;

  AuthService(this._storage, this._firestore);

  AuthUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// Try to restore previous sign-in silently.
  Future<AuthUser?> tryAutoSignIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final googleAuth = await account.authentication;
        _currentUser = AuthUser(
          id: account.id,
          name: account.displayName ?? 'User',
          email: account.email,
          photoUrl: account.photoUrl,
        );
        await _saveUser(googleIdToken: googleAuth.idToken);
        return _currentUser;
      }
    } catch (e) {
      debugPrint('[AuthService] tryAutoSignIn (Google silent) failed: $e');
    }

    // Check local storage for cached user
    final id = _storage.userId;
    if (id != null && !_storage.isGuest && id != 'local') {
      _currentUser = AuthUser(
        id: id,
        name: _storage.userName ?? 'User',
        email: '',
      );
      _firestore.setUser(id);
      // Replay any writes that failed to sync before this session.
      _firestore.flushPendingSyncs(_storage).catchError(
        (e) => debugPrint('[AuthService] flushPendingSyncs failed: $e'),
      );
    }
    return _currentUser;
  }

  /// Sign in with Google.
  Future<AuthUser?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // User cancelled

      final googleAuth = await account.authentication;

      _currentUser = AuthUser(
        id: account.id,
        name: account.displayName ?? 'User',
        email: account.email,
        photoUrl: account.photoUrl,
      );

      await _saveUser(googleIdToken: googleAuth.idToken);
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] signInWithGoogle failed: $e');
      return null;
    }
  }

  /// Check if Apple Sign-In is available (iOS 13+).
  Future<bool> get isAppleSignInAvailable {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return Future.value(false);
    }
    return SignInWithApple.isAvailable();
  }

  /// Sign in with Apple.
  Future<AuthUser?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Apple's userIdentifier is the only stable per-user ID across sessions.
      // authorizationCode is single-use and invalid after exchange — using it
      // as a fallback would create a fresh "account" on every reinstall and
      // orphan the user's journal/bookmarks.
      final userIdentifier = credential.userIdentifier;
      if (userIdentifier == null || userIdentifier.isEmpty) {
        debugPrint('[AuthService] Apple Sign-In returned no userIdentifier');
        return null;
      }

      final name = [
        credential.givenName,
        credential.familyName,
      ].where((n) => n != null).join(' ');

      _currentUser = AuthUser(
        id: 'apple_$userIdentifier',
        name: name.isNotEmpty ? name : 'User',
        email: credential.email ?? '',
      );

      // Apple Sign-In gives us an identityToken JWT we can use as a
      // bearer-style identifier. It is NOT a QF API token — User APIs
      // remain unavailable for Apple-signed-in users until we add a
      // backend exchange.
      await _saveUser(appleIdToken: credential.identityToken);
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] signInWithApple failed: $e');
      return null;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AuthService] Google signOut failed: $e');
    }
    _currentUser = null;
    _firestore.resetUser();
    await _storage.clearAuth();
  }

  /// Permanently delete the user's account and all associated data.
  /// Deletes cloud data (Firestore), local data (SharedPreferences + secure
  /// storage), signs out from Google, and clears the in-memory user.
  Future<void> deleteAccount() async {
    // 1. Delete cloud data (Firestore user doc + subcollections)
    try {
      await _firestore.deleteUserData();
    } catch (e) {
      debugPrint('[AuthService] Firestore delete failed: $e');
      // Continue with local deletion even if cloud fails
    }

    // 2. Sign out from Google (revokes token on Google side)
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }

    // 3. Clear all local data
    await _storage.clearAll();

    // 4. Reset in-memory state
    _currentUser = null;
  }

  Future<void> _saveUser({String? googleIdToken, String? appleIdToken}) async {
    if (_currentUser != null) {
      await _storage.setUserId(_currentUser!.id);
      await _storage.setUserName(_currentUser!.name);

      // Store the real id_token where available so it can be used for
      // identity verification. Fall back to a sentinel marker so the
      // app can still tell that the user is signed-in without leaking
      // a fake bearer to the User API client (which now skips auth-
      // requiring calls when authType != quranFoundation).
      if (googleIdToken != null && googleIdToken.isNotEmpty) {
        await _storage.setAuthToken(googleIdToken);
        await _storage.setAuthType(AuthType.google);
      } else if (appleIdToken != null && appleIdToken.isNotEmpty) {
        await _storage.setAuthToken(appleIdToken);
        await _storage.setAuthType(AuthType.google); // treated as 3rd-party
      } else {
        await _storage.setAuthToken(null);
        await _storage.setAuthType(AuthType.google);
      }

      // Connect Firestore so cloud sync works for non-QF users.
      _firestore.setUser(_currentUser!.id);
      _firestore.saveUserProfile(
        name: _currentUser!.name,
        email: _currentUser!.email,
        photoUrl: _currentUser!.photoUrl,
      ).catchError(
        (e) => debugPrint('[AuthService] saveUserProfile failed: $e'),
      );
      // Replay any writes that failed to sync before this session.
      _firestore.flushPendingSyncs(_storage).catchError(
        (e) => debugPrint('[AuthService] flushPendingSyncs failed: $e'),
      );
      // Restore cloud data if local is empty (new device / reinstall)
      await _restoreFromCloud();
    }
  }

  /// Pull progress and journal from Firestore if local data is empty.
  Future<void> _restoreFromCloud() async {
    try {
      // Restore progress if local has none
      final localProgress = _storage.getProgress();
      if (localProgress == null || localProgress.totalAyatCompleted == 0) {
        final cloudProgress = await _firestore.loadProgress();
        if (cloudProgress != null) {
          final restored = UserProgress.fromJson(cloudProgress);
          if (restored.totalAyatCompleted > 0) {
            await _storage.saveProgress(restored);
          }
        }
      }

      // Restore journal if local is empty
      final localJournal = _storage.getJournalEntries();
      if (localJournal.isEmpty) {
        final cloudJournal = await _firestore.loadJournalEntries();
        if (cloudJournal.isNotEmpty) {
          await _storage.saveJournalEntries(cloudJournal);
        }
      }
    } catch (_) {
      // Non-blocking — if restore fails, local data is still usable
    }
  }
}
