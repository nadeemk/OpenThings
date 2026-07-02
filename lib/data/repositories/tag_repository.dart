import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';

const _uuid = Uuid();

class TagRepository {
  TagRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<Tag> create(String title, {String? parentTagId}) async {
    final now = _clock();
    final id = _uuid.v4();
    await _db.into(_db.tags).insert(TagsCompanion.insert(
          id: id,
          title: title,
          parentTagId: Value(parentTagId),
          createdAt: now,
          modifiedAt: now,
        ));
    return (_db.select(_db.tags)..where((t) => t.id.equals(id))).getSingle();
  }

  Stream<List<Tag>> watchAll() => (_db.select(_db.tags)
        ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
      .watch();

  Future<void> rename(String id, String title) =>
      (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
          TagsCompanion(title: Value(title), modifiedAt: Value(_clock())));

  Future<void> delete(String id) async {
    await _db.into(_db.pendingDeletions).insert(
          PendingDeletionsCompanion.insert(
              entityId: id, entity: 'tag', deletedAt: _clock()),
          mode: InsertMode.insertOrReplace,
        );
    await (_db.delete(_db.taskTags)..where((tt) => tt.tagId.equals(id))).go();
    // Re-parent children of a deleted nested tag.
    await (_db.update(_db.tags)..where((t) => t.parentTagId.equals(id)))
        .write(const TagsCompanion(parentTagId: Value(null)));
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }

  // ---- Assignment ---------------------------------------------------------

  Future<void> tagTask(String taskId, String tagId) =>
      _db.into(_db.taskTags).insert(
            TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
            mode: InsertMode.insertOrIgnore,
          );

  Future<void> untagTask(String taskId, String tagId) => (_db
          .delete(_db.taskTags)
        ..where((tt) => tt.taskId.equals(taskId) & tt.tagId.equals(tagId)))
      .go();

  Stream<List<Tag>> watchTagsForTask(String taskId) {
    final query = _db.select(_db.tags).join([
      innerJoin(_db.taskTags, _db.taskTags.tagId.equalsExp(_db.tags.id)),
    ])
      ..where(_db.taskTags.taskId.equals(taskId));
    return query.watch().map(
        (rows) => rows.map((row) => row.readTable(_db.tags)).toList());
  }
}
