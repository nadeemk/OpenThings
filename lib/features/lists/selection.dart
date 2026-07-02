import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/enums.dart';
import '../../domain/dates.dart' as d;

/// Multi-select state: the set of selected to-do ids. Non-empty set
/// means selection mode is active.
class SelectedTaskIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) {
    state = state.contains(id)
        ? ({...state}..remove(id))
        : {...state, id};
  }

  void clear() => state = const {};
}

final selectedTaskIdsProvider =
    NotifierProvider<SelectedTaskIds, Set<String>>(SelectedTaskIds.new);

/// Bottom bar with batch actions for the current selection:
/// schedule Today / Someday, complete, or trash all selected.
class BatchActionBar extends ConsumerWidget {
  const BatchActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTaskIdsProvider);
    if (selected.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final repo = ref.read(taskRepositoryProvider);

    Future<void> forAll(Future<void> Function(String id) action) async {
      for (final id in selected) {
        await action(id);
      }
      ref.read(selectedTaskIdsProvider.notifier).clear();
    }

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: OtSpacing.md, vertical: OtSpacing.xs),
          child: Row(
            children: [
              Text('${selected.length} selected',
                  style: theme.textTheme.bodyMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Today',
                icon: const Icon(Icons.star_rounded,
                    color: OtColors.todayYellow),
                onPressed: () => forAll((id) => repo.setWhen(id,
                    bucket: StartBucket.anytime, startDate: d.today())),
              ),
              IconButton(
                tooltip: 'Someday',
                icon: const Icon(Icons.archive_rounded,
                    color: OtColors.somedaySand),
                onPressed: () => forAll(
                    (id) => repo.setWhen(id, bucket: StartBucket.someday)),
              ),
              IconButton(
                tooltip: 'Complete',
                icon: Icon(Icons.check_circle_rounded,
                    color: theme.colorScheme.primary),
                onPressed: () => forAll(repo.complete),
              ),
              IconButton(
                tooltip: 'Move to Trash',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => forAll(repo.trash),
              ),
              IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.close_rounded),
                onPressed: () =>
                    ref.read(selectedTaskIdsProvider.notifier).clear(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
