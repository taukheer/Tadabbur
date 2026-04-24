import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';
import 'package:tadabbur/core/widgets/time_of_day_ribbon.dart';

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
      body: Stack(
        children: [
          Column(
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
              const _SyncErrorBanner(),
              Expanded(child: child),
            ],
          ),
          // Ambient time-of-day tint floats above the scaffold without
          // taking layout space or blocking touches. Near-invisible
          // during the day; deepens warmly at fajr/maghrib so the app
          // feels aware of the times the user prays.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TimeOfDayRibbon(),
          ),
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

/// Dismissible banner that surfaces the most-recent user-visible sync
/// failure reported via [SyncReporter]. Auto-hides after 30 seconds so
/// a transient network blip doesn't linger forever.
class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<SyncError?>(
      valueListenable: SyncReporter.lastError,
      builder: (context, err, _) {
        if (err == null) return const SizedBox.shrink();
        // Auto-expire stale errors so the banner doesn't get stuck if
        // the user is offline for a while then comes back.
        if (DateTime.now().difference(err.at) > const Duration(seconds: 30)) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFFFFF4E5),
          child: Row(
            children: [
              const Icon(Icons.sync_problem_rounded,
                  size: 14, color: Color(0xFFB07700)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Couldn't sync ${err.what} · saved locally",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF7A5600),
                  ),
                ),
              ),
              InkWell(
                onTap: SyncReporter.dismiss,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.close_rounded,
                      size: 14, color: Color(0xFFB07700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
