import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';

const _uuid = Uuid();

class ChecklistRepository {
  ChecklistRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<ChecklistItem> add(String taskId, String title) async {
    final now = _clock();
    final id = _uuid.v4();
    final max = await (_db.selectOnly(_db.checklistItems)
          ..addColumns([_db.checklistItems.orderIndex.max()])
          ..where(_db.checklistItems.taskId.equals(taskId)))
        .map((row) => row.read(_db.checklistItems.orderIndex.max()))
        .getSingle();
    await _db.into(_db.checklistItems).insert(ChecklistItemsCompanion.insert(
          id: id,
          taskId: taskId,
          title: title,
          orderIndex: Value((max ?? 0) + 1024),
          createdAt: now,
          modifiedAt: now,
        ));
    return (_db.select(_db.checklistItems)..where((c) => c.id.equals(id)))
        .getSingle();
  }

  Stream<List<ChecklistItem>> watchForTask(String taskId) =>
      (_db.select(_db.checklistItems)
            ..where((c) => c.taskId.equals(taskId))
            ..orderBy([(c) => OrderingTerm.asc(c.orderIndex)]))
          .watch();

  Future<void> setDone(String id, bool done) => _patch(
      id, ChecklistItemsCompanion(done: Value(done)));

  Future<void> rename(String id, String title) =>
      _patch(id, ChecklistItemsCompanion(title: Value(title)));

  Future<void> setOrderIndex(String id, double orderIndex) =>
      _patch(id, ChecklistItemsCompanion(orderIndex: Value(orderIndex)));

  Future<void> delete(String id) =>
      (_db.delete(_db.checklistItems)..where((c) => c.id.equals(id))).go();

  Future<void> _patch(String id, ChecklistItemsCompanion patch) =>
      (_db.update(_db.checklistItems)..where((c) => c.id.equals(id)))
          .write(patch.copyWith(modifiedAt: Value(_clock())));
}
