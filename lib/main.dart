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

  // Initialize notifications (non-blocking)
  try {
    final notifService = NotificationService(localStorage);
    await notifService.init();
    notifService.requestPermission(); // fire-and-forget
  } catch (e) {
    debugPrint('[Notifications] Initialization failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(localStorage),
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

class _TadabburAppState extends ConsumerState<TadabburApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDeepLinks());
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
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
