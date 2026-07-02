import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';

/// Tag assignment sheet for a to-do (⌘⇧T): toggle existing tags or
/// create a new one inline.
Future<void> showTagPicker(
    BuildContext context, WidgetRef ref, String taskId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _TagPickerSheet(taskId: taskId),
  );
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({required this.taskId});

  final String taskId;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  final _newTag = TextEditingController();

  @override
  void dispose() {
    _newTag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(allTagsProvider).value ?? [];
    final assigned = (ref.watch(taskTagsProvider(widget.taskId)).value ?? [])
        .map((t) => t.id)
        .toSet();
    final repo = ref.read(tagRepositoryProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: OtSpacing.xl,
        right: OtSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + OtSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tags', style: theme.textTheme.titleLarge),
          const SizedBox(height: OtSpacing.md),
          if (all.isEmpty)
            Text('No tags yet — create one below.',
                style: theme.textTheme.bodyMedium),
          Wrap(
            spacing: OtSpacing.sm,
            runSpacing: OtSpacing.xs,
            children: [
              for (final tag in all)
                FilterChip(
                  label: Text(tag.title),
                  selected: assigned.contains(tag.id),
                  onSelected: (on) => on
                      ? repo.tagTask(widget.taskId, tag.id)
                      : repo.untagTask(widget.taskId, tag.id),
                ),
            ],
          ),
          const SizedBox(height: OtSpacing.md),
          TextField(
            controller: _newTag,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.sell_rounded, size: 16),
              hintText: 'New tag…',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) async {
              final title = v.trim();
              if (title.isEmpty) return;
              final tag = await repo.create(title);
              await repo.tagTask(widget.taskId, tag.id);
              _newTag.clear();
            },
          ),
        ],
      ),
    );
  }
}
