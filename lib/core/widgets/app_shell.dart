import 'package:flutter/material.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/layout/breakpoints.dart';
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

  void _navigateTo(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/journal');
      case 2:
        context.go('/settings');
    }
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

    final useRail = context.useSideNavigation;

    // Body content shared between phone and tablet layouts. Wraps the
    // routed child in a max-width container on tablet so screens don't
    // stretch across an iPad's full 13-inch width — text stays
    // comfortable to read, and the chrome (offline banner, sync error
    // banner) still spans the full window.
    final bodyContent = SafeArea(
      top: true,
      bottom: false,
      child: Column(
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
          Expanded(
            child: MaxWidthContainer(child: child),
          ),
        ],
      ),
    );

    return Scaffold(
      body: Row(
        children: [
          if (useRail)
            _AdaptiveNavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _navigateTo(context, i),
              t: t,
            ),
          Expanded(
            child: Stack(
              children: [
                bodyContent,
                // Ambient time-of-day tint floats above the scaffold
                // without taking layout space or blocking touches.
                // Near-invisible during the day; deepens warmly at
                // fajr/maghrib so the app feels aware of the times
                // the user prays. Phones only — on iPad the larger
                // canvas competes with the band, so we follow the
                // YouVersion / Apple Books pattern of pure status-bar →
                // content with no ambient chrome.
                if (!useRail)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: TimeOfDayRibbon(),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.brandInk.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => _navigateTo(context, i),
                backgroundColor: theme.colorScheme.surface,
                indicatorColor:
                    theme.brandInk.withValues(alpha: 0.08),
                elevation: 0,
                height: 60,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.auto_stories_outlined,
                        color:
                            theme.inkAt(0.4),
                        semanticLabel: t('today')),
                    selectedIcon: Icon(Icons.auto_stories,
                        color: theme.colorScheme.primary,
                        semanticLabel: t('today')),
                    label: t('today'),
                    tooltip: t('today'),
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.book_outlined,
                        color:
                            theme.inkAt(0.4),
                        semanticLabel: t('journal')),
                    selectedIcon: Icon(Icons.book,
                        color: theme.colorScheme.primary,
                        semanticLabel: t('journal')),
                    label: t('journal'),
                    tooltip: t('journal'),
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined,
                        color:
                            theme.inkAt(0.4),
                        semanticLabel: t('settings')),
                    selectedIcon: Icon(Icons.settings,
                        color: theme.colorScheme.primary,
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

/// Side navigation rail used at expanded window widths (iPad landscape,
/// foldable unfolded landscape, desktop). Replaces the bottom
/// [NavigationBar] so the iPad never feels like a stretched phone.
class _AdaptiveNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String Function(String) t;

  const _AdaptiveNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: true,
      bottom: true,
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.brandInk.withValues(alpha: 0.08),
        labelType: NavigationRailLabelType.all,
        useIndicator: true,
        groupAlignment: -0.85,
        destinations: [
          NavigationRailDestination(
            icon: Icon(Icons.auto_stories_outlined,
                color: theme.inkAt(0.4)),
            selectedIcon: Icon(Icons.auto_stories,
                color: theme.colorScheme.primary),
            label: Text(t('today')),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.book_outlined,
                color: theme.inkAt(0.4)),
            selectedIcon:
                Icon(Icons.book, color: theme.colorScheme.primary),
            label: Text(t('journal')),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined,
                color: theme.inkAt(0.4)),
            selectedIcon:
                Icon(Icons.settings, color: theme.colorScheme.primary),
            label: Text(t('settings')),
          ),
        ],
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
        return Material(
          color: const Color(0xFFFFF4E5),
          child: InkWell(
            onTap: () => _showSyncErrorDetails(context, err),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      padding: EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: Color(0xFFB07700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows the underlying status code and error string in a small dialog
/// so the user (or the dev triaging a report) can see *why* the sync
/// failed, instead of just "couldn't sync." Copy-to-clipboard helps
/// when forwarding the message in a bug report.
void _showSyncErrorDetails(BuildContext context, SyncError err) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text("Sync failed: ${err.what}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (err.statusCode != null)
                Text('Status code: ${err.statusCode}'),
              if (err.statusCode != null) const SizedBox(height: 8),
              SelectableText(
                err.summary,
                style: const TextStyle(fontSize: 12),
              ),
              if (err.serverBody != null) ...[
                const SizedBox(height: 8),
                const Text('Server response:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SelectableText(
                  err.serverBody!,
                  style:
                      const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Your reflection is safe — saved locally even when sync fails.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
