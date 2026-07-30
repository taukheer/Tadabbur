import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:tadabbur/core/services/firestore_service.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';

/// Upgrades the device's anonymous Firebase session to one keyed on the
/// signed-in Quran.com identity.
///
/// The app authenticates to Firebase anonymously so Firestore rules
/// have a real `request.auth`. That works, but anonymous accounts are
/// per-install: reinstalling or resetting the session mints a brand new
/// one. Since Firebase requires emails to be unique, the user's address
/// would strand on whichever dead account claimed it first, leaving the
/// live account blank in the console and inflating the account count
/// well past the number of actual people.
///
/// Deriving the Firebase UID from the QF `sub` removes that failure
/// mode: one human maps to one account permanently, reinstalls land
/// back on it, and the email is always attached to the account the user
/// is actually using.
///
/// The `signInWithQf` Cloud Function does the work — it verifies the
/// id_token against QF's JWKS, migrates the departing anonymous
/// account's Firestore data, and returns a custom token. Migration has
/// to happen server-side because once the UID changes the client can no
/// longer read its own former document under the security rules.
///
/// Best-effort throughout: this is identity plumbing, never something
/// the user waits on, so failures log and retry on a later launch.
class QfIdentityLinkService {
  final LocalStorageService _storage;
  final FirestoreService _firestore;

  QfIdentityLinkService(this._storage, this._firestore);

  static const _functionName = 'signInWithQf';

  /// Guards against the double-firing OAuth callback (deep-link stream
  /// plus router rebuild) running two exchanges for one sign-in.
  Future<void>? _inFlight;

  /// Upgrade the session if it hasn't been done already. Safe to call on
  /// every boot and after every sign-in.
  Future<void> linkIfNeeded() {
    return _inFlight ??= _linkIfNeeded().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _linkIfNeeded() async {
    if (_storage.authType != AuthType.quranFoundation) return;

    // Anonymous sign-in has to have landed first: the function checks
    // that the caller really owns the account whose data it is asked to
    // migrate, which means we need a Firebase session to call from.
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      debugPrint('[QfLink] skipping — no Firebase user yet');
      return;
    }

    // Compare against the UID we upgraded to, not a boolean flag: an
    // account replaced since the last run needs upgrading again.
    if (_storage.qfLinkedUid == currentUid) return;

    final idToken = await _storage.getQfIdToken();
    if (idToken == null || idToken.isEmpty) {
      debugPrint('[QfLink] skipping — no stored id_token');
      return;
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(_functionName);
      final result = await callable.call<Map<String, dynamic>>({
        'idToken': idToken,
        // The account we're leaving behind, so its journal and
        // bookmarks come with us.
        'previousUid': currentUid,
      });

      final token = result.data['token'] as String?;
      if (token == null || token.isEmpty) {
        debugPrint('[QfLink] function returned no token');
        return;
      }

      final cred =
          await FirebaseAuth.instance.signInWithCustomToken(token);
      final newUid = cred.user?.uid;
      if (newUid == null) return;

      // Point local state and Firestore at the new UID. The rules
      // require `request.auth.uid == docId`, so a stale userId here
      // would make every subsequent write fail silently.
      await _storage.setUserId(newUid);
      await _storage.setQfLinkedUid(newUid);
      _firestore.setUser(newUid);

      debugPrint('[QfLink] signed in as $newUid '
          '(migrated=${result.data['migrated']})');
    } on FirebaseFunctionsException catch (e) {
      // The token was rejected — almost always because id_tokens are
      // short-lived and this ran many launches after sign-in. Retrying
      // can't help until the user signs in again, so stop asking.
      if (e.code == 'permission-denied' || e.code == 'invalid-argument') {
        debugPrint('[QfLink] token rejected (${e.code}) — clearing id_token');
        await _storage.setQfIdToken(null);
        return;
      }
      debugPrint('[QfLink] failed (${e.code}) — will retry next launch');
    } catch (e) {
      debugPrint('[QfLink] failed: $e — will retry next launch');
    }
  }
}
