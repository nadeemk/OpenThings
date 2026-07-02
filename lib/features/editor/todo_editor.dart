import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/enums.dart';
import '../../domain/dates.dart' as d;
import '../lists/todo_checkbox.dart';
import 'when_picker.dart';

/// The inline-expanded editing card: a to-do opens in place into a
/// distraction-free card with title, notes, checklist, tags, and the
/// three date controls, like Things.
class TodoEditor extends ConsumerStatefulWidget {
  const TodoEditor({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends ConsumerState<TodoEditor> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _checklistController = TextEditingController();
  bool _seeded = false;
  bool _previewNotes = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _checklistController.dispose();
    super.dispose();
  }

  void _close() => ref.read(expandedTaskIdProvider.notifier).set(null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskAsync = ref.watch(taskByIdProvider(widget.taskId));
    final task = taskAsync.value;
    if (task == null) return const SizedBox.shrink();

    if (!_seeded) {
      _titleController.text = task.title;
      _notesController.text = task.notes;
      _seeded = true;
    }

    final repo = ref.read(taskRepositoryProvider);
    final checklist = ref.watch(checklistProvider(task.id)).value ?? [];
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      color: isDark ? OtColors.darkCard : OtColors.lightCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(OtRadii.md)),
      margin: const EdgeInsets.symmetric(vertical: OtSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(OtSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TodoCheckbox(
                  checked: task.completionDate != null,
                  onChanged: (v) async {
                    if (v) {
                      _close();
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
                  child: TextField(
                    controller: _titleController,
                    autofocus: task.title.isEmpty,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'New To-Do',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (v) => repo.updateTitle(task.id, v),
                    onSubmitted: (_) => _close(),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Notes (Markdown, with preview toggle) ----
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _previewNotes
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: MarkdownBody(
                                    data: _notesController.text.isEmpty
                                        ? '_No notes_'
                                        : _notesController.text),
                              )
                            : TextField(
                                controller: _notesController,
                                maxLines: null,
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Notes (Markdown supported)',
                                  hintStyle: theme.textTheme.bodyMedium,
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (v) =>
                                    repo.updateNotes(task.id, v),
                              ),
                      ),
                      IconButton(
                        tooltip:
                            _previewNotes ? 'Edit notes' : 'Preview Markdown',
                        iconSize: 14,
                        icon: Icon(_previewNotes
                            ? Icons.edit_rounded
                            : Icons.visibility_rounded),
                        onPressed: () =>
                            setState(() => _previewNotes = !_previewNotes),
                      ),
                    ],
                  ),
                  // ---- Checklist ----
                  for (final item in checklist)
                    Row(
                      children: [
                        SizedBox(
                          height: 28,
                          child: Checkbox(
                            value: item.done,
                            onChanged: (v) => ref
                                .read(checklistRepositoryProvider)
                                .setDone(item.id, v ?? false),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        Expanded(
                          child: Text(item.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 13,
                                decoration: item.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              )),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 14),
                          onPressed: () => ref
                              .read(checklistRepositoryProvider)
                              .delete(item.id),
                        ),
                      ],
                    ),
                  TextField(
                    controller: _checklistController,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '+ Add checklist item',
                      hintStyle:
                          theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (v) async {
                      if (v.trim().isEmpty) return;
                      await ref
                          .read(checklistRepositoryProvider)
                          .add(task.id, v.trim());
                      _checklistController.clear();
                    },
                  ),
                  const SizedBox(height: OtSpacing.md),
                  // ---- Date chips ----
                  Wrap(
                    spacing: OtSpacing.sm,
                    runSpacing: OtSpacing.xs,
                    children: [
                      _DateChip(
                        icon: task.isEvening
                            ? Icons.nightlight_round
                            : Icons.star_rounded,
                        color: OtColors.todayYellow,
                        label: _whenLabel(task.startBucket, task.startDate,
                            task.isEvening),
                        onTap: () async {
                          final choice = await showWhenPicker(context);
                          if (choice != null) {
                            await repo.setWhen(task.id,
                                bucket: choice.bucket,
                                startDate: choice.date,
                                isEvening: choice.isEvening);
                          }
                        },
                      ),
                      _DateChip(
                        icon: Icons.flag_rounded,
                        color: OtColors.deadlineRed,
                        label: task.deadline == null
                            ? 'Deadline'
                            : DateFormat.MMMd().format(task.deadline!),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: task.deadline ?? d.today(),
                            firstDate: d.today(),
                            lastDate:
                                d.today().add(const Duration(days: 365 * 5)),
                          );
                          await repo.setDeadline(task.id, picked);
                        },
                      ),
                      _DateChip(
                        icon: Icons.access_time_rounded,
                        color: OtColors.accent,
                        label: task.reminderMinutes == null
                            ? 'Reminder'
                            : _reminderLabel(task.reminderMinutes!),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (picked != null) {
                            await repo.setReminder(
                                task.id, picked.hour * 60 + picked.minute);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: OtSpacing.sm),
            Row(
              children: [
                IconButton(
                  tooltip: 'Move to Trash',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: () async {
                    _close();
                    await repo.trash(task.id);
                  },
                ),
                const Spacer(),
                TextButton(onPressed: _close, child: const Text('Done')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _whenLabel(StartBucket bucket, DateTime? date, bool evening) {
    if (bucket == StartBucket.someday) return 'Someday';
    if (date == null) return 'When';
    final today = d.today();
    if (date.isSameDay(today)) return evening ? 'This Evening' : 'Today';
    if (date.isSameDay(today.add(const Duration(days: 1)))) return 'Tomorrow';
    return DateFormat.MMMd().format(date);
  }

  String _reminderLabel(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    final t = TimeOfDay(hour: h, minute: m);
    return t.format(context);
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: theme.textTheme.bodyMedium),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
