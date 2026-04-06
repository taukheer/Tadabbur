import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/router/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/services/notification_service.dart';
import 'package:tadabbur/core/theme/app_theme.dart';
import 'package:tadabbur/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Firebase (non-blocking — app works without it)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase] Initialization failed: $e');
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
