import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/database.dart';
import '../../data/db/enums.dart';
import '../lists/list_scaffold.dart';
import '../lists/todo_row.dart';

/// All open to-dos carrying a tag — Things' app-wide tag filter.
final tasksByTagProvider =
    StreamProvider.family<List<Task>, String>((ref, tagId) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.tasks).join([
    innerJoin(db.taskTags, db.taskTags.taskId.equalsExp(db.tasks.id)),
  ])
    ..where(db.taskTags.tagId.equals(tagId) &
        db.tasks.trashedAt.isNull() &
        db.tasks.isRepeatTemplate.equals(false) &
        db.tasks.status.equals(ItemStatus.open.index))
    ..orderBy([OrderingTerm.asc(db.tasks.orderIndex)]);
  return query
      .watch()
      .map((rows) => rows.map((r) => r.readTable(db.tasks)).toList());
});

final tagByIdProvider = StreamProvider.family<Tag?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.tags)..where((t) => t.id.equals(id)))
      .watchSingleOrNull();
});

class TagScreen extends ConsumerWidget {
  const TagScreen({super.key, required this.tagId});

  final String tagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = ref.watch(tagByIdProvider(tagId)).value;
    final items = ref.watch(tasksByTagProvider(tagId)).value ?? [];
    return ListScaffold(
      title: tag?.title ?? 'Tag',
      icon: Icons.sell_rounded,
      color: OtColors.somedaySand,
      isEmpty: items.isEmpty,
      emptyHint: 'No open to-dos with this tag.',
      slivers: [
        SliverTodoList(children: [
          for (final t in items) TodoRow(task: t, showWhenBadge: true),
        ]),
      ],
    );
  }
}
