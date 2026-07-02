import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'enums.dart';

part 'database.g.dart';

/// Spheres of life (Work, Family, ...). Not completable.
class Areas extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 0, max: 512)();
  RealColumn get orderIndex => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Unified table for to-dos, projects, and headings (see [ItemType]),
/// mirroring Things' single TMTask table. This makes moving items
/// between lists, reordering, and converting to-dos into projects cheap.
class Tasks extends Table {
  TextColumn get id => text()();
  IntColumn get type => intEnum<ItemType>()();
  TextColumn get title => text().withLength(min: 0, max: 2048)();

  /// Markdown notes.
  TextColumn get notes => text().withDefault(const Constant(''))();

  IntColumn get status => intEnum<ItemStatus>()();

  // ---- The three independent date concepts -------------------------------

  /// 1. "When": coarse bucket + optional start date + evening flag.
  IntColumn get startBucket => intEnum<StartBucket>()();

  /// Day the item becomes actionable (date-only; time is always midnight
  /// local). Null when unscheduled/someday/inbox.
  DateTimeColumn get startDate => dateTime().nullable()();

  /// When true and the item is in Today, it shows in the This Evening
  /// section at the bottom.
  BoolColumn get isEvening => boolean().withDefault(const Constant(false))();

  /// 2. Deadline: independent of the start date. Date-only.
  DateTimeColumn get deadline => dateTime().nullable()();

  /// 3. Reminder: minutes since midnight on the start date at which a
  /// notification fires. Null = no reminder.
  IntColumn get reminderMinutes => integer().nullable()();

  // ---- Hierarchy ----------------------------------------------------------

  TextColumn get areaId => text().nullable().references(Areas, #id)();
  TextColumn get projectId => text().nullable()();
  TextColumn get headingId => text().nullable()();

  // ---- Ordering -----------------------------------------------------------

  /// Position within its parent list (project/area/inbox...).
  RealColumn get orderIndex => real().withDefault(const Constant(0))();

  /// Independent manual ordering within the Today list.
  RealColumn get todayIndex => real().withDefault(const Constant(0))();

  // ---- Repeaters ----------------------------------------------------------

  IntColumn get repeatMode =>
      intEnum<RepeatMode>().withDefault(Constant(RepeatMode.none.index))();
  IntColumn get repeatEveryN => integer().withDefault(const Constant(1))();
  IntColumn get repeatUnit =>
      intEnum<RepeatUnit>().withDefault(Constant(RepeatUnit.day.index))();

  /// True for the hidden template row that spawns instances.
  BoolColumn get isRepeatTemplate =>
      boolean().withDefault(const Constant(false))();

  /// For spawned instances: the template that created them.
  TextColumn get repeaterTemplateId => text().nullable()();

  /// For fixed-schedule templates: the date the next instance is (or will
  /// be) scheduled for.
  DateTimeColumn get nextInstanceDate => dateTime().nullable()();

  // ---- Lifecycle ----------------------------------------------------------

  DateTimeColumn get completionDate => dateTime().nullable()();
  DateTimeColumn get trashedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sub-steps inside a single to-do.
class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  RealColumn get orderIndex => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cross-cutting labels. Tags can be nested via [parentTagId].
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get parentTagId => text().nullable()();
  RealColumn get orderIndex => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Task <-> Tag join table.
class TaskTags extends Table {
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

@DriftDatabase(tables: [Areas, Tasks, ChecklistItems, Tags, TaskTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for tests.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'openthings',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
