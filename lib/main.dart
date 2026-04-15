import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/router/app_router.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/services/notification_service.dart';
import 'package:tadabbur/core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
      _wireConnectivity();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _connectivitySub?.close();
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
      debugPrint(
        '[DeepLink] OAuth error: $error '
        '(${uri.queryParameters['error_description'] ?? 'no description'})',
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

    return MaterialApp.router(
      title: 'Tadabbur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
