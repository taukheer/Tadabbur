import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/router/app_router.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/services/notification_service.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';
import 'package:tadabbur/core/theme/app_theme.dart';
import 'package:tadabbur/core/widgets/time_of_day_ribbon.dart';
import 'package:tadabbur/firebase_options.dart';

/// How long to wait between foreground-resume triggered hydrations.
/// Prevents spamming the QF API on rapid app-switching (e.g. user
/// flipping between Tadabbur and a browser while debugging).
const _kForegroundHydrateCooldown = Duration(seconds: 30);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Firebase
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e) {
    debugPrint('[Firebase] Initialization failed: $e');
  }

  // Initialize Crashlytics — catch all uncaught errors
  if (firebaseReady) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // Disable Crashlytics in debug mode to avoid noise
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    // Anonymous Firebase Auth. The app's product-side identity is
    // Quran Foundation OAuth (tokens in local storage), but Firestore
    // security rules need a real `request.auth` object — without one,
    // every write to /feedback and /users/* silently fails. Signing
    // in anonymously gives each install a stable Firebase UID that
    // satisfies the auth-not-null check. It's per-device (not shared
    // across devices); the QF identity is what carries cross-device
    // continuity via the User APIs.
    //
    // Fire-and-forget: if this fails (network, Auth disabled in
    // console), the app stays usable — Firestore writes just keep
    // their current silent-failure behavior.
    if (FirebaseAuth.instance.currentUser == null) {
      FirebaseAuth.instance.signInAnonymously().then((cred) {
        debugPrint('[FirebaseAuth] anonymous sign-in: ${cred.user?.uid}');
      }).catchError((Object e) {
        debugPrint('[FirebaseAuth] anonymous sign-in failed: $e');
      });
    }
  }

  final localStorage = LocalStorageService();
  await localStorage.init();

  // Initialize notifications (non-blocking). Failures are captured on
  // the service itself so the Settings screen can read
  // `notifService.lastScheduleError` and tell users their reminder
  // didn't actually arm.
  final notifService = NotificationService(localStorage);
  try {
    await notifService.init();
    notifService.requestPermission(); // fire-and-forget
    notifService.ensureDailyScheduled().catchError((Object e) {
      notifService.lastScheduleError = e.toString();
      debugPrint('[Notifications] ensureDailyScheduled failed: $e');
    });
  } catch (e) {
    notifService.lastScheduleError = e.toString();
    debugPrint('[Notifications] Initialization failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(localStorage),
        notificationServiceProvider.overrideWithValue(notifService),
      ],
      child: const TadabburApp(),
    ),
  );
}

class TadabburApp extends ConsumerStatefulWidget {
  const TadabburApp({super.key});

  static final _analytics = FirebaseAnalytics.instance;
  static final analyticsObserver =
      FirebaseAnalyticsObserver(analytics: _analytics);

  @override
  ConsumerState<TadabburApp> createState() => _TadabburAppState();
}

class _TadabburAppState extends ConsumerState<TadabburApp>
    with WidgetsBindingObserver {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  ProviderSubscription<AsyncValue<bool>>? _connectivitySub;

  /// Timestamp of the last foreground-resume hydrate run. Used with
  /// [_kForegroundHydrateCooldown] to throttle refresh calls so the
  /// app doesn't hit QF repeatedly during rapid app-switching.
  DateTime? _lastForegroundHydrate;

  /// Current solar band. Rebuilds the app when it changes so the
  /// dark-theme variant (warm navy vs. OLED black) can swap at
  /// maghrib/fajr without the user having to toggle anything.
  SolarBand _band = bandForHour(DateTime.now().hour);
  Timer? _bandTicker;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
      _wireConnectivity();
      _bootSyncProfile();
    });
    // Band transitions only happen at hour boundaries, so a 1-minute
    // poll is cheap and more than responsive enough. setState is a
    // no-op when the band hasn't changed.
    _bandTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = bandForHour(DateTime.now().hour);
      if (now != _band && mounted) {
        setState(() => _band = now);
      }
    });
  }

  /// Forward connectivity changes into FirestoreService so writes stop
  /// hammering the network when offline. The pending-sync queue takes
  /// over once the device reconnects.
  void _wireConnectivity() {
    _connectivitySub = ref.listenManual<AsyncValue<bool>>(
      connectivityProvider,
      (prev, next) {
        final online = next.valueOrNull ?? true;
        ref.read(firestoreServiceProvider).setOnline(online);
        debugPrint('[Connectivity] online=$online');
      },
      fireImmediately: true,
    );
  }

  /// Opportunistic profile sync on every app boot.
  ///
  /// Onboarding writes `/users/{userId}` once, but anyone who was
  /// already onboarded before we added Firestore tracking (or whose
  /// Firestore doc was deleted) would never appear in the users
  /// collection on their own. This boot-time write ensures every
  /// returning install re-stamps its profile and `last_active_at` —
  /// so the admin view actually reflects the user base over time.
  ///
  /// Gated behind `hasOnboarded` to avoid writing for users who
  /// haven't finished onboarding yet (they'll be captured by
  /// `_completeOnboarding`).
  ///
  /// Small delay to wait for anonymous Firebase Auth to land; if
  /// it hasn't completed after 3 s we give up this cycle and try
  /// again next boot.
  Future<void> _bootSyncProfile() async {
    final storage = ref.read(localStorageProvider);
    if (!storage.hasOnboarded) return;

    // Wait for anonymous Firebase Auth to settle so the Firestore
    // rule `isOwner(userId)` (request.auth.uid == userId) passes.
    for (var attempts = 0; attempts < 6; attempts++) {
      if (FirebaseAuth.instance.currentUser != null) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null) {
      debugPrint('[BootSync] skipping — anonymous auth did not land');
      return;
    }

    // For guests, migrate their local userId to the Firebase UID if
    // it's still the pre-fix hardcoded 'guest' string. Without this
    // the Firestore write would still target /users/guest (collision)
    // for installs that upgraded from before the user-tracking pass.
    if (storage.authType == AuthType.guest &&
        (storage.userId == null || storage.userId == 'guest')) {
      await storage.setUserId(authUid);
    }

    final uid = storage.userId;
    if (uid == null || uid.isEmpty) return;

    final firestore = ref.read(firestoreServiceProvider);
    firestore.setUser(uid);

    final profile = storage.getProfile();
    final authUser = ref.read(authUserProvider);
    final method = storage.authType == AuthType.guest
        ? 'guest'
        : storage.authType == AuthType.quranFoundation
            ? 'quran_foundation'
            : authUser != null
                ? 'apple'
                : 'unknown';

    unawaited(firestore
        .saveUserProfile(
          name: authUser?.name,
          email: authUser?.email,
          photoUrl: authUser?.photoUrl,
          language: storage.language,
          arabicLevel: profile?.arabicLevel.name,
          understandingLevel: profile?.understandingLevel.name,
          motivation: profile?.motivation.name,
          currentVerseKey: storage.getProgress()?.currentVerseKey,
          reciterPath: storage.reciterPath,
          arabicFont: storage.arabicFont,
          arabicFontSize: storage.arabicFontSize,
          authMethod: method,
          // Boot re-sync — preserve the original sign-in timestamp,
          // only update last_active_at.
          stampSignedIn: false,
        )
        .catchError((Object e) {
      debugPrint('[BootSync] profile write failed: $e');
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _connectivitySub?.close();
    _bandTicker?.cancel();
    super.dispose();
  }

  /// Silently refresh bookmarks + notes from QF whenever the app comes
  /// back to the foreground. This is the "real-time enough" path for
  /// two-way sync — if a user is signed in on mobile and adds a
  /// bookmark on quran.com from their laptop, the phone will pull it
  /// in the next time they switch back to the app. Throttled so rapid
  /// app-switching doesn't spam the API.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;

    // Only hydrate when the user is authenticated via QF — other
    // auth types (Google/Apple/guest) don't have QF User API access.
    final storage = ref.read(localStorageProvider);
    if (storage.authType != AuthType.quranFoundation) return;
    if (storage.authToken == null || storage.authToken!.isEmpty) return;

    final now = DateTime.now();
    final lastRun = _lastForegroundHydrate;
    if (lastRun != null &&
        now.difference(lastRun) < _kForegroundHydrateCooldown) {
      return;
    }
    _lastForegroundHydrate = now;

    debugPrint('[Foreground] refreshing bookmarks + notes from QF');
    unawaited(ref.read(bookmarkProvider.notifier).hydrateFromQF());
    unawaited(ref.read(journalProvider.notifier).hydrateFromQF());
  }

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleUri(initial);
      }
    } catch (e) {
      debugPrint('[DeepLink] initial link error: $e');
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object e) => debugPrint('[DeepLink] stream error: $e'),
    );
  }

  void _handleUri(Uri uri) {
    debugPrint('[DeepLink] Received URI: $uri');

    if (uri.scheme != 'com.tadabbur.tadabbur') {
      return;
    }
    if (uri.host != 'oauth' || uri.path != '/callback') {
      debugPrint('[DeepLink] ignoring unrelated deep link');
      return;
    }

    final error = uri.queryParameters['error'];
    if (error != null) {
      final desc = uri.queryParameters['error_description'] ?? error;
      debugPrint('[DeepLink] OAuth error: $error ($desc)');
      // Surface the OAuth failure via SyncReporter so the user sees
      // *why* sign-in didn't complete instead of landing silently
      // back on /home. A silent return looks identical to "nothing
      // happened" and wastes cycles debugging UI when the problem is
      // actually a rejected scope or a flagged client.
      SyncReporter.report(
        'sign-in · ${error == "invalid_scope" ? "scope rejected" : error}',
        desc,
      );
      return;
    }

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (code == null || state == null) {
      debugPrint('[DeepLink] Missing code or state in OAuth callback');
      return;
    }

    debugPrint('[DeepLink] Routing to /oauth/callback');
    final router = ref.read(routerProvider);
    router.go(
      '/oauth/callback'
      '?code=${Uri.encodeComponent(code)}'
      '&state=${Uri.encodeComponent(state)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Night band (roughly maghrib → fajr) uses a pure-black OLED
    // variant; other bands use the warm-navy dark theme so the app
    // doesn't feel clinical in dim daytime/evening.
    final isNight = _band == SolarBand.night || _band == SolarBand.preDawn;
    final darkVariant = isNight ? AppTheme.midnightOled : AppTheme.dark;

    return MaterialApp.router(
      title: 'Tadabbur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: darkVariant,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
