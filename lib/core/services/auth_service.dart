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
    final id = _storage.userId;
    if (id != null && !_storage.isGuest && id != 'local') {
      _currentUser = AuthUser(
        id: id,
        name: _storage.userName ?? 'User',
        email: '',
      );
      _firestore.setUser(id);
      // Replay any writes that failed to sync before this session.
      _firestore.flushPendingSyncs(_storage).catchError((_) {});
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

  /// Check if Apple Sign-In is available (iOS 13+).
  Future<bool> get isAppleSignInAvailable async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    return await SignInWithApple.isAvailable();
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

      final name = [
        credential.givenName,
        credential.familyName,
      ].where((n) => n != null).join(' ');

      _currentUser = AuthUser(
        id: 'apple_${credential.userIdentifier ?? credential.authorizationCode}',
        name: name.isNotEmpty ? name : 'User',
        email: credential.email ?? '',
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

  Future<void> _saveUser() async {
    if (_currentUser != null) {
      await _storage.setUserId(_currentUser!.id);
      await _storage.setUserName(_currentUser!.name);
      await _storage.setAuthToken('google_${_currentUser!.id}');
      // Connect Firestore so cloud sync works
      _firestore.setUser(_currentUser!.id);
      _firestore.saveUserProfile(
        name: _currentUser!.name,
        email: _currentUser!.email,
        photoUrl: _currentUser!.photoUrl,
      ).catchError((_) {});
      // Replay any writes that failed to sync before this session.
      _firestore.flushPendingSyncs(_storage).catchError((_) {});
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
