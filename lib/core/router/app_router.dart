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

  return GoRouter(
    initialLocation: !hasOnboarded ? '/onboarding' : '/home',
    observers: [TadabburApp.analyticsObserver],
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // OAuth callback deep link handler
      GoRoute(
        path: '/oauth/callback',
        redirect: (context, state) {
          final code = state.uri.queryParameters['code'];
          final callbackState = state.uri.queryParameters['state'];
          if (code != null && callbackState != null) {
            debugPrint('[OAuth] Received callback with auth code');
            final qfAuth = ref.read(qfAuthServiceProvider);
            qfAuth.exchangeCode(code, state: callbackState);
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
