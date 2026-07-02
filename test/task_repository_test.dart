import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openthings/data/db/database.dart';
import 'package:openthings/data/db/enums.dart';
import 'package:openthings/data/repositories/checklist_repository.dart';
import 'package:openthings/data/repositories/task_repository.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repo;
  late ChecklistRepository checklists;

  // Fixed, controllable clock.
  var now = DateTime(2026, 7, 1, 9, 0);
  DateTime clock() => now;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TaskRepository(db, clock: clock);
    checklists = ChecklistRepository(db, clock: clock);
    now = DateTime(2026, 7, 1, 9, 0);
  });

  tearDown(() => db.close());

  group('creation defaults', () {
    test('bare to-do lands in Inbox', () async {
      final t = await repo.createTodo(title: 'Capture me');
      expect(t.startBucket, StartBucket.inbox);
      expect(t.startDate, isNull);
      expect(t.status, ItemStatus.open);
    });

    test('to-do created inside a project defaults to Anytime', () async {
      final p = await repo.createProject(title: 'Trip');
      final t = await repo.createTodo(title: 'Book flights', projectId: p.id);
      expect(t.startBucket, StartBucket.anytime);
    });

    test('order indexes increase within a parent', () async {
      final p = await repo.createProject(title: 'P');
      final a = await repo.createTodo(title: 'a', projectId: p.id);
      final b = await repo.createTodo(title: 'b', projectId: p.id);
      expect(b.orderIndex, greaterThan(a.orderIndex));
    });
  });

  group('the three dates are independent', () {
    test('deadline does not touch the start bucket', () async {
      final t = await repo.createTodo(title: 't');
      await repo.setDeadline(t.id, DateTime(2026, 7, 20));
      final after = (await repo.getById(t.id))!;
      expect(after.startBucket, StartBucket.inbox);
      expect(after.deadline, DateTime(2026, 7, 20));
    });

    test('setWhen today + evening flag', () async {
      final t = await repo.createTodo(title: 't');
      await repo.setWhen(t.id,
          bucket: StartBucket.anytime,
          startDate: DateTime(2026, 7, 1),
          isEvening: true);
      final after = (await repo.getById(t.id))!;
      expect(after.startDate, DateTime(2026, 7, 1));
      expect(after.isEvening, isTrue);
      expect(after.deadline, isNull);
    });

    test('reminder stores minutes since midnight', () async {
      final t = await repo.createTodo(title: 't');
      await repo.setReminder(t.id, 18 * 60);
      expect((await repo.getById(t.id))!.reminderMinutes, 1080);
    });
  });

  group('lifecycle', () {
    test('complete stamps completionDate; reopen clears it', () async {
      final t = await repo.createTodo(title: 't');
      await repo.complete(t.id);
      var after = (await repo.getById(t.id))!;
      expect(after.status, ItemStatus.completed);
      expect(after.completionDate, isNotNull);

      await repo.reopen(t.id);
      after = (await repo.getById(t.id))!;
      expect(after.status, ItemStatus.open);
      expect(after.completionDate, isNull);
    });

    test('moving an inbox item into a project promotes it to Anytime',
        () async {
      final p = await repo.createProject(title: 'P');
      final t = await repo.createTodo(title: 't');
      await repo.move(t.id, projectId: p.id);
      final after = (await repo.getById(t.id))!;
      expect(after.projectId, p.id);
      expect(after.startBucket, StartBucket.anytime);
    });

    test('trash and restore', () async {
      final t = await repo.createTodo(title: 't');
      await repo.trash(t.id);
      expect((await repo.getById(t.id))!.trashedAt, isNotNull);
      await repo.restore(t.id);
      expect((await repo.getById(t.id))!.trashedAt, isNull);
    });
  });

  group('repeaters: fixed schedule', () {
    test('template pre-generates first instance scheduled on its date',
        () async {
      final template = await repo.createTodo(
        title: 'Water plants',
        repeatMode: RepeatMode.fixedSchedule,
        repeatEveryN: 3,
        repeatUnit: RepeatUnit.day,
        startDate: DateTime(2026, 7, 1),
        startBucket: StartBucket.anytime,
      );
      expect(template.isRepeatTemplate, isTrue);

      final all = await db.select(db.tasks).get();
      final instances =
          all.where((t) => t.repeaterTemplateId == template.id).toList();
      expect(instances, hasLength(1));
      expect(instances.single.startDate, DateTime(2026, 7, 1));
      expect(instances.single.isRepeatTemplate, isFalse);

      // Template already knows when the following instance is due.
      final refreshed = (await repo.getById(template.id))!;
      expect(refreshed.nextInstanceDate, DateTime(2026, 7, 4));
    });

    test('catchUpRepeaters spawns the overdue next instance on schedule',
        () async {
      // Template created a week ago.
      now = DateTime(2026, 6, 24, 9, 0);
      final template = await repo.createTodo(
        title: 'Weekly review',
        repeatMode: RepeatMode.fixedSchedule,
        repeatEveryN: 1,
        repeatUnit: RepeatUnit.week,
        startDate: DateTime(2026, 6, 24),
        startBucket: StartBucket.anytime,
      );
      // A week passes.
      now = DateTime(2026, 7, 1, 9, 0);
      await repo.catchUpRepeaters();

      final all = await db.select(db.tasks).get();
      final instances =
          all.where((t) => t.repeaterTemplateId == template.id).toList()
            ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
      expect(instances.map((i) => i.startDate).toList(),
          [DateTime(2026, 6, 24), DateTime(2026, 7, 1)]);
    });
  });

  group('repeaters: after completion', () {
    test('completing an instance spawns the next N units later', () async {
      final template = await repo.createTodo(
        title: 'Tidy desk',
        repeatMode: RepeatMode.afterCompletion,
        repeatEveryN: 4,
        repeatUnit: RepeatUnit.day,
        startBucket: StartBucket.anytime,
        startDate: DateTime(2026, 7, 1),
      );
      // After-completion templates do NOT pre-generate; spawn first manually.
      var all = await db.select(db.tasks).get();
      expect(all.where((t) => t.repeaterTemplateId == template.id), isEmpty);

      // Simulate the first instance existing (spawned at setup time by
      // catchUp for after-completion? No — Things creates the first
      // instance when the repeater is created; our engine does it on
      // first completion cycle. Create one linked instance directly.)
      final first = await repo.createTodo(
        title: 'Tidy desk',
        startBucket: StartBucket.anytime,
        startDate: DateTime(2026, 7, 1),
      );
      await (db.update(db.tasks)
            ..where((t) => t.id.equals(first.id)))
          .write(TasksCompanion(
              repeaterTemplateId: Value(template.id)));

      now = DateTime(2026, 7, 2, 18, 0); // completed a day late
      await repo.complete(first.id);

      all = await db.select(db.tasks).get();
      final instances = all
          .where((t) =>
              t.repeaterTemplateId == template.id && t.status == ItemStatus.open)
          .toList();
      expect(instances, hasLength(1));
      // 4 days after the completion DAY, not the original schedule.
      expect(instances.single.startDate, DateTime(2026, 7, 6));
    });
  });

  group('checklist copy on spawn', () {
    test('fixed-schedule instances inherit the template checklist', () async {
      final template = await repo.createTodo(
        title: 'Pack gym bag',
        repeatMode: RepeatMode.fixedSchedule,
        repeatEveryN: 1,
        repeatUnit: RepeatUnit.day,
        startDate: DateTime(2026, 7, 1),
        startBucket: StartBucket.anytime,
      );
      await checklists.add(template.id, 'Shoes');
      await checklists.add(template.id, 'Towel');

      // Trigger another spawn via catch-up after two days.
      now = DateTime(2026, 7, 3, 8, 0);
      await repo.catchUpRepeaters();

      final all = await db.select(db.tasks).get();
      final latest = all
          .where((t) => t.repeaterTemplateId == template.id)
          .reduce((a, b) => a.startDate!.isAfter(b.startDate!) ? a : b);
      final items = await (db.select(db.checklistItems)
            ..where((c) => c.taskId.equals(latest.id)))
          .get();
      expect(items.map((i) => i.title).toSet(), {'Shoes', 'Towel'});
      expect(items.every((i) => !i.done), isTrue);
    });
  });
}
