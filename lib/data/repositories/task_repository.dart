import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/dates.dart';
import '../../domain/repeat_engine.dart';
import '../db/database.dart';
import '../db/enums.dart';

const _uuid = Uuid();

/// CRUD + lifecycle operations for tasks, projects, and headings.
///
/// All writes stamp `modifiedAt`; list-membership queries live in the
/// list engine (domain/list_rules.dart + data/list_queries.dart).
class TaskRepository {
  TaskRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  // ---- Creation -----------------------------------------------------------

  /// Creates a to-do. With no arguments it lands in the Inbox, like
  /// Things' quick entry.
  Future<Task> createTodo({
    String title = '',
    String notes = '',
    StartBucket? startBucket,
    DateTime? startDate,
    bool isEvening = false,
    DateTime? deadline,
    int? reminderMinutes,
    String? projectId,
    String? headingId,
    String? areaId,
    double? orderIndex,
    RepeatMode repeatMode = RepeatMode.none,
    int repeatEveryN = 1,
    RepeatUnit repeatUnit = RepeatUnit.day,
  }) async {
    // Inside a project/area items are never "inbox"; default them to
    // anytime, otherwise default to inbox — mirroring Things.
    final bucket = startBucket ??
        ((projectId != null || areaId != null)
            ? StartBucket.anytime
            : StartBucket.inbox);
    final isTemplate = repeatMode != RepeatMode.none;
    final now = _clock();
    final task = TasksCompanion.insert(
      id: _uuid.v4(),
      type: ItemType.todo,
      title: title,
      notes: Value(notes),
      status: ItemStatus.open,
      startBucket: bucket,
      startDate: Value(startDate == null ? null : dateOnly(startDate)),
      isEvening: Value(isEvening),
      deadline: Value(deadline == null ? null : dateOnly(deadline)),
      reminderMinutes: Value(reminderMinutes),
      projectId: Value(projectId),
      headingId: Value(headingId),
      areaId: Value(areaId),
      orderIndex: Value(orderIndex ?? await _nextOrderIndex(projectId, areaId)),
      repeatMode: Value(repeatMode),
      repeatEveryN: Value(repeatEveryN),
      repeatUnit: Value(repeatUnit),
      isRepeatTemplate: Value(isTemplate),
      createdAt: now,
      modifiedAt: now,
    );
    await _db.into(_db.tasks).insert(task);
    final created = await getById(task.id.value);
    // Fixed-schedule templates immediately pre-generate their first
    // instance.
    if (isTemplate && repeatMode == RepeatMode.fixedSchedule) {
      await _spawnFixedInstance(created!);
    }
    return created!;
  }

  Future<Task> createProject({
    String title = '',
    String notes = '',
    String? areaId,
    StartBucket startBucket = StartBucket.anytime,
    DateTime? startDate,
    DateTime? deadline,
  }) async {
    final now = _clock();
    final id = _uuid.v4();
    await _db.into(_db.tasks).insert(TasksCompanion.insert(
          id: id,
          type: ItemType.project,
          title: title,
          notes: Value(notes),
          status: ItemStatus.open,
          startBucket: startBucket,
          startDate: Value(startDate == null ? null : dateOnly(startDate)),
          deadline: Value(deadline == null ? null : dateOnly(deadline)),
          areaId: Value(areaId),
          orderIndex: Value(await _nextOrderIndex(null, areaId)),
          createdAt: now,
          modifiedAt: now,
        ));
    return (await getById(id))!;
  }

  Future<Task> createHeading({
    required String projectId,
    String title = '',
    double? orderIndex,
  }) async {
    final now = _clock();
    final id = _uuid.v4();
    await _db.into(_db.tasks).insert(TasksCompanion.insert(
          id: id,
          type: ItemType.heading,
          title: title,
          status: ItemStatus.open,
          startBucket: StartBucket.anytime,
          projectId: Value(projectId),
          orderIndex: Value(orderIndex ?? await _nextOrderIndex(projectId, null)),
          createdAt: now,
          modifiedAt: now,
        ));
    return (await getById(id))!;
  }

  // ---- Reads --------------------------------------------------------------

  Future<Task?> getById(String id) =>
      (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Task?> watchById(String id) =>
      (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  /// Children of a project (to-dos + headings), in manual order.
  Stream<List<Task>> watchProjectChildren(String projectId) =>
      (_db.select(_db.tasks)
            ..where((t) =>
                t.projectId.equals(projectId) &
                t.trashedAt.isNull() &
                t.isRepeatTemplate.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  // ---- Editing ------------------------------------------------------------

  Future<void> updateTitle(String id, String title) =>
      _patch(id, TasksCompanion(title: Value(title)));

  Future<void> updateNotes(String id, String notes) =>
      _patch(id, TasksCompanion(notes: Value(notes)));

  /// Sets the "When". Passing [StartBucket.anytime] with a date schedules
  /// it (today or future); with null date it goes to plain Anytime.
  Future<void> setWhen(
    String id, {
    required StartBucket bucket,
    DateTime? startDate,
    bool isEvening = false,
  }) =>
      _patch(
        id,
        TasksCompanion(
          startBucket: Value(bucket),
          startDate: Value(startDate == null ? null : dateOnly(startDate)),
          isEvening: Value(isEvening),
        ),
      );

  Future<void> setDeadline(String id, DateTime? deadline) => _patch(
      id,
      TasksCompanion(
          deadline: Value(deadline == null ? null : dateOnly(deadline))));

  Future<void> setReminder(String id, int? minutesSinceMidnight) => _patch(
      id, TasksCompanion(reminderMinutes: Value(minutesSinceMidnight)));

  /// Moves an item to a project/heading/area. Clears inbox status, since
  /// organized items are at least Anytime (Things' behavior).
  Future<void> move(
    String id, {
    String? projectId,
    String? headingId,
    String? areaId,
  }) async {
    final task = await getById(id);
    if (task == null) return;
    final leavingInbox = task.startBucket == StartBucket.inbox &&
        (projectId != null || areaId != null || headingId != null);
    await _patch(
      id,
      TasksCompanion(
        projectId: Value(projectId),
        headingId: Value(headingId),
        areaId: Value(areaId),
        startBucket:
            leavingInbox ? const Value(StartBucket.anytime) : const Value.absent(),
        orderIndex: Value(await _nextOrderIndex(projectId, areaId)),
      ),
    );
  }

  Future<void> setOrderIndex(String id, double orderIndex) =>
      _patch(id, TasksCompanion(orderIndex: Value(orderIndex)));

  Future<void> setTodayIndex(String id, double todayIndex) =>
      _patch(id, TasksCompanion(todayIndex: Value(todayIndex)));

  // ---- Lifecycle ----------------------------------------------------------

  /// Completes a to-do/project. If the item was spawned by an
  /// after-completion repeater, schedules the next instance; fixed-schedule
  /// instances are already pre-generated when spawned.
  Future<void> complete(String id) async {
    final task = await getById(id);
    if (task == null) return;
    final now = _clock();
    await _patch(
      id,
      TasksCompanion(
        status: const Value(ItemStatus.completed),
        completionDate: Value(now),
      ),
    );
    await _maybeSpawnNextAfterCompletion(task, now);
  }

  Future<void> cancel(String id) async {
    final task = await getById(id);
    if (task == null) return;
    final now = _clock();
    await _patch(
      id,
      TasksCompanion(
        status: const Value(ItemStatus.cancelled),
        completionDate: Value(now),
      ),
    );
    await _maybeSpawnNextAfterCompletion(task, now);
  }

  Future<void> reopen(String id) => _patch(
        id,
        const TasksCompanion(
          status: Value(ItemStatus.open),
          completionDate: Value(null),
        ),
      );

  Future<void> trash(String id) =>
      _patch(id, TasksCompanion(trashedAt: Value(_clock())));

  Future<void> restore(String id) =>
      _patch(id, const TasksCompanion(trashedAt: Value(null)));

  Future<void> emptyTrash() =>
      (_db.delete(_db.tasks)..where((t) => t.trashedAt.isNotNull())).go();

  // ---- Repeaters ----------------------------------------------------------

  /// Ensures fixed-schedule templates have pre-generated instances up to
  /// date. Call on app start / day rollover.
  Future<void> catchUpRepeaters() async {
    final templates = await (_db.select(_db.tasks)
          ..where((t) =>
              t.isRepeatTemplate.equals(true) &
              t.repeatMode.equals(RepeatMode.fixedSchedule.index) &
              t.trashedAt.isNull()))
        .get();
    final todayDate = today(clock: _clock());
    for (final template in templates) {
      final next = template.nextInstanceDate;
      // Spawn when the next occurrence is due today or overdue.
      if (next == null || !next.isAfter(todayDate)) {
        await _spawnFixedInstance(template);
      }
    }
  }

  Future<void> _maybeSpawnNextAfterCompletion(Task task, DateTime now) async {
    if (task.repeaterTemplateId == null) return;
    final template = await getById(task.repeaterTemplateId!);
    if (template == null ||
        template.trashedAt != null ||
        template.repeatMode != RepeatMode.afterCompletion) {
      return;
    }
    final nextDate = RepeatEngine.nextAfterCompletion(
      completionDay: dateOnly(now),
      everyN: template.repeatEveryN,
      unit: template.repeatUnit,
    );
    await _spawnInstance(template, nextDate);
  }

  Future<void> _spawnFixedInstance(Task template) async {
    final todayDate = today(clock: _clock());
    var next = template.nextInstanceDate ?? template.startDate ?? todayDate;
    next = RepeatEngine.catchUpFixed(
      nextDate: next,
      everyN: template.repeatEveryN,
      unit: template.repeatUnit,
      todayDate: todayDate,
    );
    await _spawnInstance(template, next);
    // Pre-compute when the following instance will be due.
    final following = RepeatEngine.nextFixed(
      current: next,
      everyN: template.repeatEveryN,
      unit: template.repeatUnit,
    );
    await _patch(
        template.id, TasksCompanion(nextInstanceDate: Value(following)));
  }

  Future<Task> _spawnInstance(Task template, DateTime startDate) async {
    final now = _clock();
    final id = _uuid.v4();
    await _db.into(_db.tasks).insert(TasksCompanion.insert(
          id: id,
          type: ItemType.todo,
          title: template.title,
          notes: Value(template.notes),
          status: ItemStatus.open,
          startBucket: StartBucket.anytime,
          startDate: Value(dateOnly(startDate)),
          isEvening: Value(template.isEvening),
          deadline: const Value(null),
          reminderMinutes: Value(template.reminderMinutes),
          projectId: Value(template.projectId),
          headingId: Value(template.headingId),
          areaId: Value(template.areaId),
          orderIndex: Value(template.orderIndex),
          repeaterTemplateId: Value(template.id),
          createdAt: now,
          modifiedAt: now,
        ));
    // Copy the template's checklist onto the new instance.
    final checklist = await (_db.select(_db.checklistItems)
          ..where((c) => c.taskId.equals(template.id))
          ..orderBy([(c) => OrderingTerm.asc(c.orderIndex)]))
        .get();
    for (final item in checklist) {
      await _db.into(_db.checklistItems).insert(ChecklistItemsCompanion.insert(
            id: _uuid.v4(),
            taskId: id,
            title: item.title,
            orderIndex: Value(item.orderIndex),
            createdAt: now,
            modifiedAt: now,
          ));
    }
    return (await getById(id))!;
  }

  // ---- Internals ----------------------------------------------------------

  Future<void> _patch(String id, TasksCompanion patch) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id)))
          .write(patch.copyWith(modifiedAt: Value(_clock())));

  Future<double> _nextOrderIndex(String? projectId, String? areaId) async {
    final query = _db.selectOnly(_db.tasks)
      ..addColumns([_db.tasks.orderIndex.max()]);
    if (projectId != null) {
      query.where(_db.tasks.projectId.equals(projectId));
    } else if (areaId != null) {
      query.where(_db.tasks.areaId.equals(areaId));
    } else {
      query.where(_db.tasks.projectId.isNull() & _db.tasks.areaId.isNull());
    }
    final max = await query
        .map((row) => row.read(_db.tasks.orderIndex.max()))
        .getSingle();
    return (max ?? 0) + 1024;
  }
}
