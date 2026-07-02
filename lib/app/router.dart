import 'package:go_router/go_router.dart';

import '../features/lists/screens.dart';
import '../features/project/project_screen.dart';
import 'built_in_lists.dart';
import 'shell.dart';

final router = GoRouter(
  initialLocation: BuiltInList.today.route,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: BuiltInList.inbox.route,
          pageBuilder: (c, s) => const NoTransitionPage(child: InboxScreen()),
        ),
        GoRoute(
          path: BuiltInList.today.route,
          pageBuilder: (c, s) => const NoTransitionPage(child: TodayScreen()),
        ),
        GoRoute(
          path: BuiltInList.upcoming.route,
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: UpcomingScreen()),
        ),
        GoRoute(
          path: BuiltInList.anytime.route,
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: AnytimeScreen()),
        ),
        GoRoute(
          path: BuiltInList.someday.route,
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: SomedayScreen()),
        ),
        GoRoute(
          path: BuiltInList.logbook.route,
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: LogbookScreen()),
        ),
        GoRoute(
          path: BuiltInList.trash.route,
          pageBuilder: (c, s) => const NoTransitionPage(child: TrashScreen()),
        ),
        GoRoute(
          path: '/project/:id',
          pageBuilder: (c, s) => NoTransitionPage(
            child: ProjectScreen(projectId: s.pathParameters['id']!),
          ),
        ),
      ],
    ),
  ],
);
