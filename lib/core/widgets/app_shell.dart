import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/providers/app_providers.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/journal')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    final isOffline = ref.watch(connectivityProvider).whenOrNull(
          data: (connected) => !connected,
        ) ??
        false;

    return Scaffold(
      body: Column(
        children: [
          if (isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: theme.colorScheme.error,
              child: Text(
                t('offline_mode'),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onError,
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                context.go('/home');
              case 1:
                context.go('/journal');
              case 2:
                context.go('/settings');
            }
          },
          backgroundColor: theme.colorScheme.surface,
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          elevation: 0,
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  semanticLabel: t('today')),
              selectedIcon:
                  Icon(Icons.auto_stories, color: theme.colorScheme.primary,
                  semanticLabel: t('today')),
              label: t('today'),
              tooltip: t('today'),
            ),
            NavigationDestination(
              icon: Icon(Icons.book_outlined,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  semanticLabel: t('journal')),
              selectedIcon:
                  Icon(Icons.book, color: theme.colorScheme.primary,
                  semanticLabel: t('journal')),
              label: t('journal'),
              tooltip: t('journal'),
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  semanticLabel: t('settings')),
              selectedIcon:
                  Icon(Icons.settings, color: theme.colorScheme.primary,
                  semanticLabel: t('settings')),
              label: t('settings'),
              tooltip: t('settings'),
            ),
          ],
        ),
      ),
    );
  }
}
