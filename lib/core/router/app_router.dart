import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/features/onboarding/screens/onboarding_screen.dart';
import 'package:tadabbur/features/daily_ayah/screens/daily_ayah_screen.dart';
import 'package:tadabbur/features/journal/screens/journal_screen.dart';
import 'package:tadabbur/features/settings/screens/settings_screen.dart';
import 'package:tadabbur/core/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final hasOnboarded = ref.watch(hasOnboardedProvider);

  return GoRouter(
    initialLocation: !hasOnboarded ? '/onboarding' : '/home',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
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
