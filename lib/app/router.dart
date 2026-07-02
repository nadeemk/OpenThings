import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'built_in_lists.dart';
import 'shell.dart';

final router = GoRouter(
  initialLocation: BuiltInList.today.route,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        for (final list in BuiltInList.values)
          GoRoute(
            path: list.route,
            pageBuilder: (context, state) => NoTransitionPage(
              child: _ListPlaceholder(list: list),
            ),
          ),
      ],
    ),
  ],
);

/// Placeholder list screen; replaced by real list views in Phase 3.
class _ListPlaceholder extends StatelessWidget {
  const _ListPlaceholder({required this.list});

  final BuiltInList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(list.icon, color: list.color, size: 28),
              const SizedBox(width: 10),
              Text(list.title, style: theme.textTheme.headlineMedium),
            ],
          ),
          const Spacer(),
          Center(
            child: Text('No items yet', style: theme.textTheme.bodyMedium),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
