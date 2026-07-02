import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/database.dart';
import 'magic_plus.dart';
import 'selection.dart';

/// Shared chrome for every list screen: big colored title, scrollable
/// body, and the floating "+" button that creates a to-do in this list.
class ListScaffold extends ConsumerWidget {
  const ListScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.slivers,
    this.onAdd,
    this.emptyHint,
    this.isEmpty = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> slivers;
  final Future<void> Function(WidgetRef ref)? onAdd;
  final String? emptyHint;
  final bool isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton:
          onAdd == null ? null : MagicPlusFab(onTap: () => onAdd!(ref)),
      bottomNavigationBar: const BatchActionBar(),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                OtSpacing.xl, OtSpacing.xl, OtSpacing.xl, OtSpacing.md),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: OtSpacing.md),
                  Expanded(
                    child:
                        Text(title, style: theme.textTheme.headlineMedium),
                  ),
                ],
              ),
            ),
          ),
          if (isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 48, color: color.withValues(alpha: 0.3)),
                    const SizedBox(height: OtSpacing.md),
                    Text(emptyHint ?? 'Nothing here',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else
            ...slivers,
          const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
        ],
      ),
    );
  }
}

/// A section header within a list ("This Evening", a date in Upcoming,
/// an area/project in Anytime).
class ListSectionHeader extends StatelessWidget {
  const ListSectionHeader({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          OtSpacing.sm, OtSpacing.xl, OtSpacing.sm, OtSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color ?? theme.colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
        ],
      ),
    );
  }
}

/// Standard horizontal padding for list content.
class SliverTodoList extends StatelessWidget {
  const SliverTodoList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: OtSpacing.lg),
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    );
  }
}

/// Creates a to-do via [create] (defaults to an Inbox capture) and
/// immediately expands it for editing.
Future<void> quickCreate(
  WidgetRef ref, {
  Future<Task> Function()? create,
}) async {
  final repo = ref.read(taskRepositoryProvider);
  final task = await (create ?? repo.createTodo)();
  ref.read(expandedTaskIdProvider.notifier).set(task.id);
}
