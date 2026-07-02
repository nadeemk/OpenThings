import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/built_in_lists.dart';
import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/database.dart';
import '../../data/db/enums.dart';

/// Quick Find: search across built-in lists, projects, areas, tags,
/// and to-dos; selecting a result jumps to it (Type-Travel).
Future<void> showQuickFind(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black38,
    builder: (context) => const Dialog(
      alignment: Alignment(0, -0.6),
      insetPadding: EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: _QuickFindPanel(),
    ),
  );
}

class _QuickFindPanel extends ConsumerStatefulWidget {
  const _QuickFindPanel();

  @override
  ConsumerState<_QuickFindPanel> createState() => _QuickFindPanelState();
}

class _QuickFindPanelState extends ConsumerState<_QuickFindPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();

    final results = <_Result>[];
    if (q.isNotEmpty) {
      // Built-in lists.
      for (final list in BuiltInList.values) {
        if (list.title.toLowerCase().contains(q)) {
          results.add(_Result(
            icon: list.icon,
            color: list.color,
            title: list.title,
            subtitle: 'List',
            onTap: (context) => context.go(list.route),
          ));
        }
      }
      // Areas.
      for (final area in ref.watch(areasProvider).value ?? <Area>[]) {
        if (area.title.toLowerCase().contains(q)) {
          results.add(_Result(
            icon: Icons.tag_rounded,
            color: OtColors.anytimeTeal,
            title: area.title,
            subtitle: 'Area',
            onTap: (context) => context.go(BuiltInList.anytime.route),
          ));
        }
      }
      // Projects.
      for (final project in ref.watch(projectsProvider).value ?? <Task>[]) {
        if (project.title.toLowerCase().contains(q)) {
          results.add(_Result(
            icon: Icons.donut_large_rounded,
            color: OtColors.accent,
            title: project.title,
            subtitle: 'Project',
            onTap: (context) => context.go('/project/${project.id}'),
          ));
        }
      }
      // Tags.
      for (final tag in ref.watch(allTagsProvider).value ?? <Tag>[]) {
        if (tag.title.toLowerCase().contains(q)) {
          results.add(_Result(
            icon: Icons.sell_rounded,
            color: OtColors.somedaySand,
            title: tag.title,
            subtitle: 'Tag',
            onTap: (context) => context.go(BuiltInList.anytime.route),
          ));
        }
      }
      // To-dos (open first, then logged).
      final tasks = ref.watch(_allTasksProvider).value ?? <Task>[];
      final matches = tasks
          .where((t) =>
              t.type == ItemType.todo &&
              !t.isRepeatTemplate &&
              t.trashedAt == null &&
              (t.title.toLowerCase().contains(q) ||
                  t.notes.toLowerCase().contains(q)))
          .toList()
        ..sort((a, b) => (a.status == ItemStatus.open ? 0 : 1)
            .compareTo(b.status == ItemStatus.open ? 0 : 1));
      for (final t in matches.take(12)) {
        results.add(_Result(
          icon: t.status == ItemStatus.open
              ? Icons.check_box_outline_blank_rounded
              : Icons.check_box_rounded,
          color: theme.colorScheme.primary,
          title: t.title,
          subtitle: t.status == ItemStatus.open ? 'To-Do' : 'Logged',
          onTap: (context) {
            final route = _routeForTask(t);
            context.go(route);
            ref.read(expandedTaskIdProvider.notifier).set(t.id);
          },
        ));
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(OtSpacing.md),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Quick Find',
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (_) {
                if (results.isNotEmpty) {
                  Navigator.pop(context);
                  results.first.onTap(context);
                }
              },
            ),
          ),
          const Divider(),
          Flexible(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(OtSpacing.xl),
                    child: Text(
                      q.isEmpty
                          ? 'Search for lists, projects, tags, and to-dos'
                          : 'No results',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final r = results[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(r.icon, color: r.color, size: 18),
                        title: Text(r.title),
                        trailing: Text(r.subtitle,
                            style: theme.textTheme.bodyMedium),
                        onTap: () {
                          Navigator.pop(context);
                          r.onTap(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _routeForTask(Task t) {
    if (t.projectId != null) return '/project/${t.projectId}';
    if (t.status != ItemStatus.open) return BuiltInList.logbook.route;
    return switch (t.startBucket) {
      StartBucket.inbox => BuiltInList.inbox.route,
      StartBucket.someday => BuiltInList.someday.route,
      StartBucket.anytime => BuiltInList.anytime.route,
    };
  }
}

final _allTasksProvider = StreamProvider<List<Task>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.tasks).watch();
});

class _Result {
  _Result({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final void Function(BuildContext) onTap;
}
