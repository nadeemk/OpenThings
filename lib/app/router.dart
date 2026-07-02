import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/db/enums.dart';
import '../domain/natural_date_parser.dart';
import '../features/lists/screens.dart';
import '../features/project/project_screen.dart';
import 'built_in_lists.dart';
import 'providers.dart';
import 'shell.dart';

/// Router as a provider so deep-link routes can reach repositories.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: BuiltInList.today.route,
    routes: [
      // things:// style deep link: /add?title=…&notes=…&when=tomorrow
      // Creates the to-do, then lands on the appropriate list.
      GoRoute(
        path: '/add',
        redirect: (context, state) async {
          final title = state.uri.queryParameters['title'] ?? '';
          final notes = state.uri.queryParameters['notes'] ?? '';
          final whenRaw = state.uri.queryParameters['when'];
          final parsed =
              whenRaw == null ? null : NaturalDateParser().parse(whenRaw);
          await ref.read(taskRepositoryProvider).createTodo(
                title: title,
                notes: notes,
                startBucket: parsed?.bucket ?? StartBucket.inbox,
                startDate: parsed?.date,
                isEvening: parsed?.isEvening ?? false,
              );
          if (parsed == null) return BuiltInList.inbox.route;
          if (parsed.bucket == StartBucket.someday) {
            return BuiltInList.someday.route;
          }
          return BuiltInList.today.route;
        },
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: BuiltInList.inbox.route,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: InboxScreen()),
          ),
          GoRoute(
            path: BuiltInList.today.route,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: TodayScreen()),
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
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: TrashScreen()),
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
});
