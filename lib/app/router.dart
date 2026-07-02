import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/db/enums.dart';
import '../domain/natural_date_parser.dart';
import '../features/auth/auth.dart';
import '../features/lists/screens.dart';
import '../features/project/project_screen.dart';
import '../features/tags/tag_screen.dart';
import 'built_in_lists.dart';
import 'providers.dart';
import 'shell.dart';

/// Router as a provider so deep-link routes can reach repositories.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return GoRouter(
    initialLocation: BuiltInList.today.route,
    // Re-evaluate the auth gate whenever sign-in state changes.
    refreshListenable: auth,
    redirect: (context, state) {
      // Gate only on the web (with sync configured); native stays
      // offline-first and usable without an account.
      if (!authGateEnabled) return null;
      final onSignIn = state.matchedLocation == '/signin';
      if (!auth.isSignedIn) return onSignIn ? null : '/signin';
      if (onSignIn) return BuiltInList.today.route;
      return null;
    },
    routes: [
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
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
          GoRoute(
            path: '/tag/:id',
            pageBuilder: (c, s) => NoTransitionPage(
              child: TagScreen(tagId: s.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
});
