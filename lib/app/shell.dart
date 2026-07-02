import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/tokens.dart';
import 'built_in_lists.dart';

/// Breakpoint above which we show the persistent sidebar instead of
/// bottom navigation.
const _kSidebarBreakpoint = 700.0;

/// Adaptive navigation shell: persistent sidebar on desktop/web/tablet,
/// bottom navigation + drawer on phones.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _kSidebarBreakpoint;
    return wide ? _WideShell(child: child) : _NarrowShell(child: child);
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: ColoredBox(
              color: isDark ? OtColors.darkSidebar : OtColors.lightSidebar,
              child: const _Sidebar(),
            ),
          ),
          const VerticalDivider(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NarrowShell extends StatelessWidget {
  const _NarrowShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    // Primary tabs on phones; the rest are reachable from the browse tab.
    const tabs = [
      BuiltInList.inbox,
      BuiltInList.today,
      BuiltInList.upcoming,
      BuiltInList.anytime,
    ];
    final index = tabs.indexWhere((l) => location.startsWith(l.route));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 1 : index,
        onDestinationSelected: (i) => context.go(tabs[i].route),
        destinations: [
          for (final list in tabs)
            NavigationDestination(
              icon: Icon(list.icon, color: list.color),
              label: list.title,
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: OtSpacing.lg),
      children: [
        for (final list in BuiltInList.values) ...[
          _SidebarTile(
            list: list,
            selected: location.startsWith(list.route),
          ),
          // Things visually groups: Inbox | dates | library.
          if (list == BuiltInList.inbox || list == BuiltInList.someday)
            const SizedBox(height: OtSpacing.lg),
        ],
        // Areas and projects will be listed here (Phase 3).
      ],
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.list, required this.selected});

  final BuiltInList list;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: OtSpacing.sm, vertical: OtSpacing.xxs),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OtRadii.sm)),
        selected: selected,
        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        leading: Icon(list.icon, color: list.color, size: 20),
        title: Text(list.title, style: theme.textTheme.bodyLarge),
        onTap: () => context.go(list.route),
      ),
    );
  }
}
