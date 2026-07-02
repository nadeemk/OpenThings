import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/built_in_lists.dart';
import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/database.dart';
import '../../data/db/enums.dart';
import '../../data/list_queries.dart';
import '../../domain/dates.dart' as d;
import '../../domain/reorder.dart';
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
        // Drag rows to reorder; drop the Magic Plus between rows to
        // insert.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: OtSpacing.lg),
          sliver: SliverReorderableList(
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) {
              final idx = reorderedIndex(
                  [for (final t in items) t.orderIndex], oldIndex, newIndex);
              ref
                  .read(taskRepositoryProvider)
                  .setOrderIndex(items[oldIndex].id, idx);
            },
            itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
              key: ValueKey('inbox-${items[i].id}'),
              index: i,
              child: MagicPlusDropTarget(
                before: items[i],
                onInsert: (orderIndex) => quickCreate(ref,
                    create: () => ref
                        .read(taskRepositoryProvider)
                        .createTodo(orderIndex: orderIndex)),
                child: TodoRow(task: items[i]),
              ),
            ),
          ),
        ),
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
    final events = ref.watch(todayEventsProvider).value ?? const [];
    return ListScaffold(
      title: list.title,
      icon: list.icon,
      color: list.color,
      isEmpty: day.isEmpty && evening.isEmpty && events.isEmpty,
      emptyHint: 'Take a moment to plan your day.',
      onAdd: (ref) => quickCreate(ref,
          create: () => ref.read(taskRepositoryProvider).createTodo(
              startBucket: StartBucket.anytime, startDate: d.today())),
      slivers: [
        // Read-only calendar events, pinned at the top like Things.
        if (events.isNotEmpty)
          SliverTodoList(children: [
            for (final e in events)
              ListTile(
                dense: true,
                leading: const Icon(Icons.calendar_today_rounded,
                    size: 14, color: OtColors.upcomingRed),
                title: Text(e.title),
                trailing: e.start == null
                    ? null
                    : Text(DateFormat.jm().format(e.start!),
                        style: Theme.of(context).textTheme.bodyMedium),
              ),
            const Divider(),
          ]),
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
        // Things-style grouping: each of the next 7 days individually,
        // then one section per month.
        for (final section in _sectioned(groups, today)) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: OtSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: ListSectionHeader(label: section.label),
            ),
          ),
          SliverTodoList(children: [
            for (final t in section.items)
              TodoRow(task: t, showWhenBadge: section.showDates),
          ]),
        ],
      ],
    );
  }

  List<({String label, List<Task> items, bool showDates})> _sectioned(
      UpcomingView groups, DateTime today) {
    final sections = <({String label, List<Task> items, bool showDates})>[];
    final monthBuckets = <String, List<Task>>{};
    for (final group in groups) {
      final diff = group.day.difference(today).inDays;
      if (diff < 7) {
        sections.add((
          label: _dayLabel(group.day, today),
          items: group.items,
          showDates: false,
        ));
      } else {
        final key = DateFormat.yMMMM().format(group.day);
        monthBuckets.putIfAbsent(key, () => []).addAll(group.items);
      }
    }
    for (final entry in monthBuckets.entries) {
      sections.add((label: entry.key, items: entry.value, showDates: true));
    }
    return sections;
  }

  String _dayLabel(DateTime day, DateTime today) {
    final diff = day.difference(today).inDays;
    if (diff == 1) return 'Tomorrow';
    return DateFormat.EEEE().format(day);
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
