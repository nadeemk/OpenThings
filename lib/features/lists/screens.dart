import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/built_in_lists.dart';
import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/enums.dart';
import '../../domain/dates.dart' as d;
import 'list_scaffold.dart';
import 'magic_plus.dart';
import 'todo_row.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inboxProvider).value ?? [];
    const list = BuiltInList.inbox;
    return ListScaffold(
      title: list.title,
      icon: list.icon,
      color: list.color,
      isEmpty: items.isEmpty,
      emptyHint: 'Collect your thoughts — new to-dos land here.',
      onAdd: (ref) => quickCreate(ref),
      slivers: [
        SliverTodoList(children: [
          for (final t in items)
            MagicPlusDropTarget(
              before: t,
              onInsert: (orderIndex) => quickCreate(ref,
                  create: () => ref
                      .read(taskRepositoryProvider)
                      .createTodo(orderIndex: orderIndex)),
              child: TodoRow(task: t),
            ),
        ]),
      ],
    );
  }
}

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(todayProvider).value;
    const list = BuiltInList.today;
    final day = view?.day ?? [];
    final evening = view?.evening ?? [];
    return ListScaffold(
      title: list.title,
      icon: list.icon,
      color: list.color,
      isEmpty: day.isEmpty && evening.isEmpty,
      emptyHint: 'Take a moment to plan your day.',
      onAdd: (ref) => quickCreate(ref,
          create: () => ref.read(taskRepositoryProvider).createTodo(
              startBucket: StartBucket.anytime, startDate: d.today())),
      slivers: [
        SliverTodoList(children: [for (final t in day) TodoRow(task: t)]),
        if (evening.isNotEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: OtSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: ListSectionHeader(
                label: 'This Evening',
                icon: Icons.nightlight_round,
                color: OtColors.accentDark,
              ),
            ),
          ),
        if (evening.isNotEmpty)
          SliverTodoList(children: [for (final t in evening) TodoRow(task: t)]),
      ],
    );
  }
}

class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(upcomingProvider).value ?? [];
    const list = BuiltInList.upcoming;
    final today = d.today();
    return ListScaffold(
      title: list.title,
      icon: list.icon,
      color: list.color,
      isEmpty: groups.isEmpty,
      emptyHint: 'No scheduled to-dos. Enjoy the calm.',
      onAdd: (ref) => quickCreate(ref,
          create: () => ref.read(taskRepositoryProvider).createTodo(
              startBucket: StartBucket.anytime,
              startDate: today.add(const Duration(days: 1)))),
      slivers: [
        for (final group in groups) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: OtSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: ListSectionHeader(label: _dayLabel(group.day, today)),
            ),
          ),
          SliverTodoList(children: [for (final t in group.items) TodoRow(task: t)]),
        ],
      ],
    );
  }

  String _dayLabel(DateTime day, DateTime today) {
    final diff = day.difference(today).inDays;
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return DateFormat.EEEE().format(day);
    return DateFormat.yMMMd().format(day);
  }
}

class AnytimeScreen extends ConsumerWidget {
  const AnytimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(anytimeProvider).value ?? [];
    const list = BuiltInList.anytime;
    final today = d.today();
    return ListScaffold(
      title: list.title,
      icon: list.icon,
      color: list.color,
      isEmpty: sections.isEmpty,
      emptyHint: 'To-dos you could do at any time will show here.',
      onAdd: (ref) => quickCreate(ref,
          create: () => ref
              .read(taskRepositoryProvider)
              .createTodo(startBucket: StartBucket.anytime)),
      slivers: [
        for (final section in sections) ...[
          if (section.area != null || section.project != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: OtSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: ListSectionHeader(
                  label: [
                    if (section.area != null) section.area!.title,
                    if (section.project != null) section.project!.title,
                  ].join(' › '),
                  icon: section.project != null
                      ? Icons.donut_large_rounded
                      : Icons.tag_rounded,
                  color: OtColors.anytimeTeal,
                ),
              ),
            ),
          SliverTodoList(children: [
            for (final t in section.items)
              TodoRow(
                task: t,
                showTodayStar:
                    t.startDate != null && !t.startDate!.isAfterDay(today),
                showWhenBadge: false,
              ),
          ]),
        ],
      ],
    );
  }
}

class SomedayScreen extends ConsumerWidget {
  const SomedayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(somedayProvider).value ?? [];
    const list = BuiltInList.someday;
    return ListScaffold(
      title: list.title,
      icon: list.icon,
      color: list.color,
      isEmpty: items.isEmpty,
      emptyHint: 'Ideas on hold. Review every so often.',
      onAdd: (ref) => quickCreate(ref,
          create: () => ref
              .read(taskRepositoryProvider)
              .createTodo(startBucket: StartBucket.someday)),
      slivers: [
        SliverTodoList(children: [for (final t in items) TodoRow(task: t)]),
      ],
    );
  }
}

class LogbookScreen extends ConsumerWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(logbookProvider).value ?? [];
    const list = BuiltInList.logbook;
    return ListScaffold(
      title: list.title,
      icon: list.icon,
      color: list.color,
      isEmpty: groups.isEmpty,
      emptyHint: 'Completed to-dos are archived here.',
      slivers: [
        for (final group in groups) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: OtSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: ListSectionHeader(
                  label: DateFormat.yMMMd().format(group.day)),
            ),
          ),
          SliverTodoList(children: [for (final t in group.items) TodoRow(task: t)]),
        ],
      ],
    );
  }
}

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(trashProvider).value ?? [];
    const list = BuiltInList.trash;
    return ListScaffold(
      title: list.title,
      icon: list.icon,
      color: list.color,
      isEmpty: items.isEmpty,
      emptyHint: 'Trash is empty.',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: OtSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(taskRepositoryProvider).emptyTrash(),
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: const Text('Empty Trash'),
              ),
            ),
          ),
        ),
        SliverTodoList(children: [
          for (final t in items)
            ListTile(
              dense: true,
              title: Text(t.title,
                  style: const TextStyle(
                      decoration: TextDecoration.lineThrough)),
              trailing: TextButton(
                child: const Text('Restore'),
                onPressed: () =>
                    ref.read(taskRepositoryProvider).restore(t.id),
              ),
            ),
        ]),
      ],
    );
  }
}
