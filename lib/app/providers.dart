import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/repositories/area_repository.dart';
import '../data/repositories/checklist_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../data/repositories/task_repository.dart';

/// The single app-wide database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final taskRepositoryProvider = Provider<TaskRepository>(
    (ref) => TaskRepository(ref.watch(databaseProvider)));

final areaRepositoryProvider = Provider<AreaRepository>(
    (ref) => AreaRepository(ref.watch(databaseProvider)));

final tagRepositoryProvider =
    Provider<TagRepository>((ref) => TagRepository(ref.watch(databaseProvider)));

final checklistRepositoryProvider = Provider<ChecklistRepository>(
    (ref) => ChecklistRepository(ref.watch(databaseProvider)));
