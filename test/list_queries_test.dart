import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openthings/data/db/database.dart';
import 'package:openthings/data/db/enums.dart';
import 'package:openthings/data/list_queries.dart';
import 'package:openthings/data/repositories/area_repository.dart';
import 'package:openthings/data/repositories/task_repository.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repo;
  late AreaRepository areas;
  late ListQueries lists;

  final now = DateTime(2026, 7, 1, 9, 0);
  DateTime clock() => now;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TaskRepository(db, clock: clock);
    areas = AreaRepository(db, clock: clock);
    lists = ListQueries(db, clock: clock);
  });

  tearDown(() => db.close());

  test('Today splits day and This Evening sections', () async {
    await repo.createTodo(
        title: 'morning run',
        startBucket: StartBucket.anytime,
        startDate: DateTime(2026, 7, 1));
    await repo.createTodo(
        title: 'wine with sam',
        startBucket: StartBucket.anytime,
        startDate: DateTime(2026, 7, 1),
        isEvening: true);

    final view = await lists.watchToday().first;
    expect(view.day.map((t) => t.title), ['morning run']);
    expect(view.evening.map((t) => t.title), ['wine with sam']);
  });

  test('Upcoming groups by day chronologically', () async {
    await repo.createTodo(
        title: 'later',
        startBucket: StartBucket.anytime,
        startDate: DateTime(2026, 7, 10));
    await repo.createTodo(
        title: 'sooner',
        startBucket: StartBucket.anytime,
        startDate: DateTime(2026, 7, 3));

    final view = await lists.watchUpcoming().first;
    expect(view.map((g) => g.day),
        [DateTime(2026, 7, 3), DateTime(2026, 7, 10)]);
    expect(view.first.items.single.title, 'sooner');
  });

  test(
      'Anytime groups loose items, then projects, then areas; '
      'hides parents with no active children', () async {
    final area = await areas.create('Work');
    final visible = await repo.createProject(title: 'Visible', areaId: area.id);
    // Project whose only child is future-scheduled -> hidden.
    final hidden = await repo.createProject(title: 'Hidden', areaId: area.id);

    await repo.createTodo(title: 'loose');
    // Loose to-dos are created in Inbox by default; promote to Anytime.
    final all = await db.select(db.tasks).get();
    final loose = all.singleWhere((t) => t.title == 'loose');
    await repo.setWhen(loose.id, bucket: StartBucket.anytime);

    await repo.createTodo(title: 'active child', projectId: visible.id);
    await repo.createTodo(
        title: 'future child',
        projectId: hidden.id,
        startDate: DateTime(2026, 8, 1));

    final sections = await lists.watchAnytime().first;
    final labels = sections
        .map((s) =>
            '${s.area?.title ?? '-'}/${s.project?.title ?? '-'}:'
            '${s.items.map((i) => i.title).join(',')}')
        .toList();
    expect(labels, [
      '-/-:loose',
      'Work/Visible:active child',
    ]);
  });

  test('Logbook groups by completion day, newest first', () async {
    final a = await repo.createTodo(title: 'a');
    final b = await repo.createTodo(title: 'b');
    await repo.complete(a.id);
    await repo.complete(b.id);

    final view = await lists.watchLogbook().first;
    expect(view, hasLength(1));
    expect(view.single.day, DateTime(2026, 7, 1));
    expect(view.single.items, hasLength(2));
  });

  test('sidebar counts', () async {
    await repo.createTodo(title: 'captured');
    await repo.createTodo(
        title: 'due',
        startBucket: StartBucket.anytime,
        startDate: DateTime(2026, 7, 1));

    expect(await lists.watchInboxCount().first, 1);
    expect(await lists.watchTodayCount().first, 1);
  });

  test('completing a Today item removes it from Today, adds to Logbook',
      () async {
    final t = await repo.createTodo(
        title: 'done deal',
        startBucket: StartBucket.anytime,
        startDate: DateTime(2026, 7, 1));
    expect((await lists.watchToday().first).day, hasLength(1));

    await repo.complete(t.id);
    expect((await lists.watchToday().first).day, isEmpty);
    expect((await lists.watchLogbook().first).single.items.single.title,
        'done deal');
  });
}
