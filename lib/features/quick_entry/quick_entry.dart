import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/enums.dart';
import '../../domain/natural_date_parser.dart';

/// Quick Entry: the fast-capture window (⌃Space). Type a title, hit
/// Enter, and it lands in the Inbox. A second field accepts a
/// natural-language "when" ("tomorrow", "next fri", "aug 1") to
/// schedule on the way in.
Future<void> showQuickEntry(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  final whenController = TextEditingController();
  final parser = NaturalDateParser();

  Future<void> save(BuildContext dialogContext) async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      Navigator.pop(dialogContext);
      return;
    }
    final parsed = parser.parse(whenController.text);
    await ref.read(taskRepositoryProvider).createTodo(
          title: title,
          startBucket: parsed?.bucket ?? StartBucket.inbox,
          startDate: parsed?.date,
          isEvening: parsed?.isEvening ?? false,
        );
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      alignment: const Alignment(0, -0.6),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(OtSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'New To-Do',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => save(dialogContext),
              ),
              TextField(
                controller: whenController,
                style: Theme.of(dialogContext).textTheme.bodyMedium,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.event_rounded, size: 16),
                  hintText: 'When? (optional — tomorrow, aug 1, someday…)',
                  hintStyle: Theme.of(dialogContext).textTheme.bodyMedium,
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => save(dialogContext),
              ),
              const SizedBox(height: OtSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: OtSpacing.sm),
                  FilledButton(
                    onPressed: () => save(dialogContext),
                    child: const Text('Save to Inbox'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
