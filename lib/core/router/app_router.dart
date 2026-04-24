import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/main.dart';
import 'package:tadabbur/features/onboarding/screens/onboarding_screen.dart';
import 'package:tadabbur/features/daily_ayah/screens/daily_ayah_screen.dart';
import 'package:tadabbur/features/journal/screens/journal_screen.dart';
import 'package:tadabbur/features/settings/screens/settings_screen.dart';
import 'package:tadabbur/core/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final hasOnboarded = ref.watch(hasOnboardedProvider);
  final safeFallback = hasOnboarded ? '/home' : '/onboarding';

  return GoRouter(
    initialLocation: safeFallback,
    observers: [TadabburApp.analyticsObserver],
    // Top-level redirect: catches the cold-start deep link case where
    // Flutter forwards the raw custom-scheme URI
    // (com.tadabbur.tadabbur://oauth/callback?code=...&state=...) as the
    // initial location. We rewrite it to the internal /oauth/callback
    // route with the extracted query params so go_router can match it.
    redirect: (context, state) {
      final uri = state.uri;
      final location = state.matchedLocation;

      // Detect custom-scheme deep links — anything that's not an
      // http/https/in-app path.
      final isCustomScheme = uri.scheme.isNotEmpty &&
          uri.scheme != 'http' &&
          uri.scheme != 'https';

      if (isCustomScheme) {
        if (uri.host == 'oauth' && uri.path == '/callback') {
          final code = uri.queryParameters['code'];
          final oauthState = uri.queryParameters['state'];
          if (code != null && oauthState != null) {
            debugPrint('[Router] rewriting cold-start OAuth deep link');
            return '/oauth/callback'
                '?code=${Uri.encodeComponent(code)}'
                '&state=${Uri.encodeComponent(oauthState)}';
          }
        }
        debugPrint('[Router] unknown custom-scheme URI -> $safeFallback');
        return safeFallback;
      }

      if (location.isEmpty || !location.startsWith('/')) {
        debugPrint(
          '[Router] unmatched initial location: $location -> $safeFallback',
        );
        return safeFallback;
      }
      return null;
    },
    // Defensive errorBuilder: show a loading spinner (not a dead
    // "Page not found" screen). Do NOT auto-redirect here — the
    // deep-link handler in main.dart or the top-level redirect above
    // is responsible for navigation. Auto-redirecting would race with
    // the OAuth callback handler and steal navigation.
    errorBuilder: (context, state) {
      debugPrint('[Router] errorBuilder fired for: ${state.uri}');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // OAuth callback deep link handler.
      //
      // Fires after successful QF sign-in. Validates state, kicks off
      // the token exchange (fire-and-forget), and marks the user as
      // onboarded + logged in so the final destination is /home.
      GoRoute(
        path: '/oauth/callback',
        redirect: (context, state) async {
          final code = state.uri.queryParameters['code'];
          final callbackState = state.uri.queryParameters['state'];
          if (code != null && callbackState != null) {
            final qfAuth = ref.read(qfAuthServiceProvider);
            final isValid = await qfAuth.validateState(callbackState);
            if (isValid) {
              debugPrint('[OAuth] State validated, exchanging code');
              // Await the exchange so the UI state is only flipped to
              // signed-in when we actually have a token. The dedup
              // guard in QFAuthService makes this safe to await even
              // when the /oauth/callback redirect fires multiple times
              // in parallel — the second caller just reuses the
              // first's Future. Returns the real AuthUser parsed from
              // the OIDC id_token, or null on failure.
              final user =
                  await qfAuth.exchangeCode(code, state: callbackState);

              if (user != null) {
                // The user has authenticated successfully. Treat that
                // as the completion of onboarding so we land on /home
                // instead of being bounced back to /onboarding, and
                // populate authUserProvider with the real profile so
                // the Settings screen shows the user's actual name.
                final storage = ref.read(localStorageProvider);
                await storage.setOnboarded(true);
                ref.read(hasOnboardedProvider.notifier).state = true;
                ref.read(isLoggedInProvider.notifier).state = true;
                ref.read(authUserProvider.notifier).state = user;

                // Populate the QF profile from the id_token we just
                // decoded. The app's identity card relies on this
                // notifier — before, it depended on a network fetch
                // from /v1/users/me that currently 403s, so the card
                // never rendered and the app "looked" logged out even
                // when it wasn't. Driving it directly from the token
                // means the identity lands immediately.
                unawaited(ref.read(qfProfileProvider.notifier).setFromAuthUser(
                      id: user.id,
                      name: user.name,
                      email: user.email,
                      photoUrl: user.photoUrl,
                    ));

                // If the local userId is still the hardcoded 'guest'
                // string (happens when _completeOnboarding ran before
                // Firebase anonymous auth landed), upgrade it to the
                // current Firebase UID so the Firestore write below
                // targets a doc the security rule will accept
                // (request.auth.uid == docId).
                final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
                if (firebaseUid != null &&
                    (storage.userId == null ||
                        storage.userId == 'guest' ||
                        storage.userId!.isEmpty)) {
                  await storage.setUserId(firebaseUid);
                  ref.read(firestoreServiceProvider).setUser(firebaseUid);
                  debugPrint(
                    '[OAuth] upgraded local userId guest→$firebaseUid',
                  );
                }

                // CRITICAL: refresh the ApiClient's in-memory auth
                // token so subsequent User API calls include the
                // Bearer header. The ApiClient was instantiated once
                // at app startup when no token existed; without this
                // explicit sync every User API call silently fails
                // with 401.
                final apiClient = ref.read(apiClientProvider);
                apiClient.setAuthToken(storage.authToken);
                debugPrint(
                  '[OAuth] refreshed ApiClient token '
                  '(len=${storage.authToken?.length ?? 0})',
                );

                // Two-way sync: pull existing bookmarks and notes the
                // user already has on quran.com into local state so
                // they see their prior reading history in the app.
                // Fire-and-forget — the UI can land on /home while
                // this runs in the background; the bookmark/journal
                // lists will update reactively as entries stream in.
                unawaited(
                  ref.read(bookmarkProvider.notifier).hydrateFromQF(),
                );
                unawaited(
                  ref.read(journalProvider.notifier).hydrateFromQF(),
                );
                // Fetch the user's quran.com profile so Settings can
                // surface "Signed in as [name] · quran.com" instead
                // of treating OAuth as an invisible token handshake.
                unawaited(ref.read(qfProfileProvider.notifier).refresh());
                // Pull existing collections so cross-app continuity
                // is immediately visible — any collection the user
                // created on quran.com shows up in Tadabbur at once.
                unawaited(ref.read(collectionsProvider.notifier).refresh());

                // Update the Firestore /users doc with the now-real
                // Quran.com identity. The doc is keyed by the device's
                // Firebase anonymous UID (Firestore rules require
                // request.auth.uid == doc id, and we can't mint a
                // Firebase custom token from a QF OAuth flow without
                // a server). So the key stays anonymous; we write the
                // QF identity into fields on the same doc — which
                // lets the admin see "Firebase anon UID X was signed
                // in as Quran.com user Y, email Z, on date D."
                //
                // Re-stamps signed_in_at because the user has just
                // completed a real sign-in — this is a meaningful
                // moment, not a passive boot refresh.
                final firestore = ref.read(firestoreServiceProvider);
                unawaited(firestore
                    .saveUserProfile(
                      name: user.name,
                      email: user.email,
                      photoUrl: user.photoUrl,
                      authMethod: 'quran_foundation',
                      qfUserId: user.id,
                    )
                    .catchError((Object e) {
                  debugPrint('[OAuth] profile sync failed: $e');
                }));

                debugPrint('[OAuth] signed in as ${user.name} -> /home');
                return '/home';
              } else {
                debugPrint('[OAuth] exchange returned null');
              }
            } else {
              debugPrint('[OAuth] State mismatch — rejecting callback');
            }
          } else {
            debugPrint('[OAuth] Invalid callback — missing code or state');
          }
          return hasOnboarded ? '/home' : '/onboarding';
        },
      ),

      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const DailyAyahScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/journal',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const JournalScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
        ],
      ),
    ],
  );
});
