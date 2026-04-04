import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Minimal shell — just two destinations: Today's Ayah and Journal.
/// Settings accessible from Journal screen via icon.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/journal')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: child,
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
          selectedIndex: index > 1 ? 1 : index, // Settings maps to journal tab
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                context.go('/home');
              case 1:
                context.go('/journal');
            }
          },
          backgroundColor: theme.colorScheme.surface,
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          elevation: 0,
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.auto_stories_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              selectedIcon: Icon(
                Icons.auto_stories,
                color: theme.colorScheme.primary,
              ),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.book_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              selectedIcon: Icon(
                Icons.book,
                color: theme.colorScheme.primary,
              ),
              label: 'Journal',
            ),
          ],
        ),
      ),
    );
  }
}
