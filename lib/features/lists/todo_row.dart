import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/database.dart';
import '../../domain/dates.dart' as d;
import '../editor/todo_editor.dart';
import 'todo_checkbox.dart';

/// One to-do in a list. Tapping the row expands it inline into the
/// editor card (Things' signature interaction); tapping the checkbox
/// completes it after a short grace delay.
class TodoRow extends ConsumerWidget {
  const TodoRow({
    super.key,
    required this.task,
    this.showTodayStar = false,
    this.showWhenBadge = false,
  });

  final Task task;

  /// Yellow star marker shown in Anytime for items that are in Today.
  final bool showTodayStar;

  /// Show the when-date badge (used in Anytime/lists without a date
  /// context of their own).
  final bool showWhenBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedId = ref.watch(expandedTaskIdProvider);
    if (expandedId == task.id) {
      return TodoEditor(taskId: task.id);
    }

    final theme = Theme.of(context);
    final checked = task.completionDate != null;
    final checklistAsync = ref.watch(checklistProvider(task.id));
    final tagsAsync = ref.watch(taskTagsProvider(task.id));

    return InkWell(
      onTap: () => ref.read(expandedTaskIdProvider.notifier).set(task.id),
      borderRadius: BorderRadius.circular(OtRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: OtSpacing.sm, vertical: OtSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTodayStar)
              const Padding(
                padding: EdgeInsets.only(top: 8, right: 2),
                child: Icon(Icons.star_rounded,
                    size: 14, color: OtColors.todayYellow),
              ),
            TodoCheckbox(
              checked: checked,
              onChanged: (v) async {
                final repo = ref.read(taskRepositoryProvider);
                if (v) {
                  // Grace delay so the check animation is visible before
                  // the row leaves the list, like Things.
                  await Future<void>.delayed(
                      const Duration(milliseconds: 450));
                  await repo.complete(task.id);
                } else {
                  await repo.reopen(task.id);
                }
              },
            ),
            const SizedBox(width: OtSpacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title.isEmpty ? 'New To-Do' : task.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: task.title.isEmpty
                            ? theme.textTheme.bodyMedium?.color
                            : null,
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _MetaRow(
                      task: task,
                      showWhenBadge: showWhenBadge,
                      checklistCount: checklistAsync.value?.length ?? 0,
                      checklistDone: checklistAsync.value
                              ?.where((c) => c.done)
                              .length ??
                          0,
                      tags: tagsAsync.value ?? const [],
                    ),
                  ],
                ),
              ),
            ),
            if (task.deadline != null)
              Padding(
                padding: const EdgeInsets.only(top: 7, left: OtSpacing.sm),
                child: _DeadlineFlag(deadline: task.deadline!),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.task,
    required this.showWhenBadge,
    required this.checklistCount,
    required this.checklistDone,
    required this.tags,
  });

  final Task task;
  final bool showWhenBadge;
  final int checklistCount;
  final int checklistDone;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[
      if (task.notes.trim().isNotEmpty)
        Icon(Icons.notes_rounded,
            size: 12, color: theme.textTheme.bodyMedium?.color),
      if (checklistCount > 0)
        Text('$checklistDone/$checklistCount',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
      if (task.reminderMinutes != null)
        Icon(Icons.access_time_rounded,
            size: 12, color: theme.textTheme.bodyMedium?.color),
      if (showWhenBadge && task.startDate != null)
        Text(DateFormat.MMMd().format(task.startDate!),
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
      for (final tag in tags)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          ),
          child: Text(tag.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 10, color: theme.colorScheme.primary)),
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(spacing: 6, runSpacing: 2, children: children),
    );
  }
}

class _DeadlineFlag extends StatelessWidget {
  const _DeadlineFlag({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final now = d.today();
    final days = deadline.difference(now).inDays;
    final overdue = days < 0;
    final label = days == 0
        ? 'today'
        : overdue
            ? '${-days}d ago'
            : '${days}d left';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.flag_rounded, size: 12, color: OtColors.deadlineRed),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: OtColors.deadlineRed)),
      ],
    );
  }
}
