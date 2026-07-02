import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/built_in_lists.dart';
import '../../app/providers.dart';
import '../../data/db/enums.dart';
import '../../domain/dates.dart' as d;
import '../quick_entry/quick_entry.dart';
import '../quick_find/quick_find.dart';

/// The app-wide keyboard map, Things-style:
///
///   ⌘N        new to-do (in the current list's context)
///   ⇧⌘N       new project
///   ⌘K / ⌘F   Quick Find
///   ⌃Space    Quick Entry capture
///   ⌘1…⌘5     Inbox / Today / Upcoming / Anytime / Someday
///   ⌘T        expanded to-do → Today
///   ⌘E        expanded to-do → This Evening
///   ⌘O        expanded to-do → Someday
///   ⌘.        complete expanded to-do
///   ⌘→ / ⌘←   shift expanded to-do's start date ±1 day
///
/// On non-Apple platforms ⌘ is Ctrl.
class AppShortcuts extends ConsumerWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.iOS;

    SingleActivator cmd(LogicalKeyboardKey key, {bool shift = false}) =>
        SingleActivator(key,
            meta: meta, control: !meta, shift: shift);

    Future<void> newTodoHere() async {
      final location =
          GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
      final repo = ref.read(taskRepositoryProvider);
      final task = await switch (location) {
        '/today' => repo.createTodo(
            startBucket: StartBucket.anytime, startDate: d.today()),
        '/someday' => repo.createTodo(startBucket: StartBucket.someday),
        '/anytime' => repo.createTodo(startBucket: StartBucket.anytime),
        _ when location.startsWith('/project/') =>
          repo.createTodo(projectId: location.split('/').last),
        _ => repo.createTodo(),
      };
      ref.read(expandedTaskIdProvider.notifier).set(task.id);
    }

    Future<void> withExpanded(
        Future<void> Function(String id) action) async {
      final id = ref.read(expandedTaskIdProvider);
      if (id != null) await action(id);
    }

    Future<void> shiftDate(int days) => withExpanded((id) async {
          final repo = ref.read(taskRepositoryProvider);
          final task = await repo.getById(id);
          if (task == null) return;
          final base = task.startDate ?? d.today();
          await repo.setWhen(id,
              bucket: StartBucket.anytime,
              startDate: base.add(Duration(days: days)),
              isEvening: task.isEvening);
        });

    return CallbackShortcuts(
      bindings: {
        cmd(LogicalKeyboardKey.keyN): newTodoHere,
        cmd(LogicalKeyboardKey.keyN, shift: true): () async {
          final project =
              await ref.read(taskRepositoryProvider).createProject();
          if (context.mounted) context.go('/project/${project.id}');
        },
        cmd(LogicalKeyboardKey.keyK): () => showQuickFind(context),
        cmd(LogicalKeyboardKey.keyF): () => showQuickFind(context),
        const SingleActivator(LogicalKeyboardKey.space, control: true): () =>
            showQuickEntry(context, ref),
        cmd(LogicalKeyboardKey.digit1): () =>
            context.go(BuiltInList.inbox.route),
        cmd(LogicalKeyboardKey.digit2): () =>
            context.go(BuiltInList.today.route),
        cmd(LogicalKeyboardKey.digit3): () =>
            context.go(BuiltInList.upcoming.route),
        cmd(LogicalKeyboardKey.digit4): () =>
            context.go(BuiltInList.anytime.route),
        cmd(LogicalKeyboardKey.digit5): () =>
            context.go(BuiltInList.someday.route),
        cmd(LogicalKeyboardKey.keyT): () => withExpanded((id) =>
            ref.read(taskRepositoryProvider).setWhen(id,
                bucket: StartBucket.anytime, startDate: d.today())),
        cmd(LogicalKeyboardKey.keyE): () => withExpanded((id) =>
            ref.read(taskRepositoryProvider).setWhen(id,
                bucket: StartBucket.anytime,
                startDate: d.today(),
                isEvening: true)),
        cmd(LogicalKeyboardKey.keyO): () => withExpanded((id) => ref
            .read(taskRepositoryProvider)
            .setWhen(id, bucket: StartBucket.someday)),
        cmd(LogicalKeyboardKey.period): () => withExpanded((id) async {
              ref.read(expandedTaskIdProvider.notifier).set(null);
              await ref.read(taskRepositoryProvider).complete(id);
            }),
        cmd(LogicalKeyboardKey.arrowRight): () => shiftDate(1),
        cmd(LogicalKeyboardKey.arrowLeft): () => shiftDate(-1),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
