import 'dart:async';

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

class TadabburApp extends ConsumerWidget {
  const TadabburApp({super.key});

  static final _analytics = FirebaseAnalytics.instance;
  static final analyticsObserver =
      FirebaseAnalyticsObserver(analytics: _analytics);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
