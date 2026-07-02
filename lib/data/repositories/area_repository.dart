import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';

const _uuid = Uuid();

class AreaRepository {
  AreaRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<Area> create(String title) async {
    final now = _clock();
    final id = _uuid.v4();
    final max = await (_db.selectOnly(_db.areas)
          ..addColumns([_db.areas.orderIndex.max()]))
        .map((row) => row.read(_db.areas.orderIndex.max()))
        .getSingle();
    await _db.into(_db.areas).insert(AreasCompanion.insert(
          id: id,
          title: title,
          orderIndex: Value((max ?? 0) + 1024),
          createdAt: now,
          modifiedAt: now,
        ));
    return (await (_db.select(_db.areas)..where((a) => a.id.equals(id)))
        .getSingle());
  }

  Stream<List<Area>> watchAll() => (_db.select(_db.areas)
        ..orderBy([(a) => OrderingTerm.asc(a.orderIndex)]))
      .watch();

  Future<void> rename(String id, String title) =>
      (_db.update(_db.areas)..where((a) => a.id.equals(id))).write(
          AreasCompanion(title: Value(title), modifiedAt: Value(_clock())));

  Future<void> setOrderIndex(String id, double orderIndex) =>
      (_db.update(_db.areas)..where((a) => a.id.equals(id))).write(
          AreasCompanion(
              orderIndex: Value(orderIndex), modifiedAt: Value(_clock())));

  /// Deleting an area orphans its contents back to the top level
  /// (Things asks first; the UI is responsible for confirmation).
  Future<void> delete(String id) async {
    await _db.into(_db.pendingDeletions).insert(
          PendingDeletionsCompanion.insert(
              entityId: id, entity: 'area', deletedAt: _clock()),
          mode: InsertMode.insertOrReplace,
        );
    await (_db.update(_db.tasks)..where((t) => t.areaId.equals(id)))
        .write(const TasksCompanion(areaId: Value(null)));
    await (_db.delete(_db.areas)..where((a) => a.id.equals(id))).go();
  }
}
