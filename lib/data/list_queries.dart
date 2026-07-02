import 'dart:async';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/list_rules.dart';
import 'db/database.dart';
import 'db/enums.dart';

/// A Today screen: day items, then the This Evening section.
typedef TodayView = ({List<Task> day, List<Task> evening});

/// Upcoming, grouped chronologically by day.
typedef UpcomingView = List<({DateTime day, List<Task> items})>;

/// A section of the Anytime list (one area or standalone project bucket).
typedef AnytimeSection = ({
  Area? area,
  Task? project,
  List<Task> items,
});

/// Logbook entries grouped by completion day, newest first.
typedef LogbookView = List<({DateTime day, List<Task> items})>;

/// Reactive derived views over the tasks table — the built-in lists.
///
/// Membership logic lives in [ListRules] (pure, unit-tested); this class
/// only wires those rules to drift streams and applies grouping/sort.
class ListQueries {
  ListQueries(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  DateTime get _today => today(clock: _clock());

  Stream<List<Task>> _all() => _db.select(_db.tasks).watch();

  // ---- The built-in lists -------------------------------------------------

  Stream<List<Task>> watchInbox() => _all().map((rows) =>
      rows.where(ListRules.isInInbox).sortedBy((t) => t.orderIndex));

  Stream<TodayView> watchToday() => _all().map((rows) {
        final t = _today;
        final inToday =
            rows.where((r) => ListRules.isInToday(r, t)).toList();
        return (
          day: inToday
              .where((r) => !r.isEvening)
              .sortedBy((r) => r.todayIndex),
          evening: inToday
              .where((r) => r.isEvening)
              .sortedBy((r) => r.todayIndex),
        );
      });

  Stream<UpcomingView> watchUpcoming() => _all().map((rows) {
        final t = _today;
        final byDay = groupBy(
          rows.where((r) => ListRules.isInUpcoming(r, t)),
          (r) => ListRules.upcomingDay(r, t)!,
        );
        return byDay.entries
            .map((e) =>
                (day: e.key, items: e.value.sortedBy((r) => r.orderIndex)))
            .sortedBy((g) => g.day);
      });

  /// Anytime grouped Things-style: loose items first, then per-area
  /// sections with their projects' active children folded in under the
  /// project. Parents with no active children are hidden.
  Stream<List<AnytimeSection>> watchAnytime() {
    final areasStream = (_db.select(_db.areas)
          ..orderBy([(a) => OrderingTerm.asc(a.orderIndex)]))
        .watch();
    return _combineLatest(_all(), areasStream, (rows, areas) {
      final t = _today;
      final active = rows.where((r) => ListRules.isInAnytime(r, t)).toList();
      final todos = active.where((r) => r.type == ItemType.todo).toList();
      final projectById = {
        for (final r in rows.where((r) => r.type == ItemType.project)) r.id: r
      };

      final sections = <AnytimeSection>[];

      // Standalone to-dos (no area, no project).
      final loose = todos
          .where((r) => r.projectId == null && r.areaId == null)
          .sortedBy((r) => r.orderIndex);
      if (loose.isNotEmpty) {
        sections.add((area: null, project: null, items: loose));
      }

      // Project sections without an area, then areas (loose + projects).
      List<Task> childrenOf(String projectId) => todos
          .where((r) => r.projectId == projectId)
          .sortedBy((r) => r.orderIndex);

      for (final project in projectById.values
          .where((p) => p.areaId == null && ListRules.isListable(p))
          .sortedBy((p) => p.orderIndex)) {
        final children = childrenOf(project.id);
        if (children.isNotEmpty) {
          sections.add((area: null, project: project, items: children));
        }
      }

      for (final area in areas) {
        final areaLoose = todos
            .where((r) => r.areaId == area.id && r.projectId == null)
            .sortedBy((r) => r.orderIndex);
        if (areaLoose.isNotEmpty) {
          sections.add((area: area, project: null, items: areaLoose));
        }
        for (final project in projectById.values
            .where((p) => p.areaId == area.id && ListRules.isListable(p))
            .sortedBy((p) => p.orderIndex)) {
          final children = childrenOf(project.id);
          if (children.isNotEmpty) {
            sections.add((area: area, project: project, items: children));
          }
        }
      }
      return sections;
    });
  }

  Stream<List<Task>> watchSomeday() => _all().map((rows) =>
      rows.where(ListRules.isInSomeday).sortedBy((t) => t.orderIndex));

  Stream<LogbookView> watchLogbook() => _all().map((rows) {
        final byDay = groupBy(
          rows.where(ListRules.isInLogbook),
          (r) => dateOnly(r.completionDate ?? r.modifiedAt),
        );
        return byDay.entries
            .map((e) => (
                  day: e.key,
                  items: e.value
                      .sorted((a, b) => (b.completionDate ?? b.modifiedAt)
                          .compareTo(a.completionDate ?? a.modifiedAt))
                ))
            .sorted((a, b) => b.day.compareTo(a.day));
      });

  Stream<List<Task>> watchTrash() => _all().map((rows) =>
      rows.where(ListRules.isInTrash).sortedBy((t) => t.orderIndex));

  // ---- Counts (sidebar badges) -------------------------------------------

  Stream<int> watchInboxCount() => watchInbox().map((l) => l.length);

  Stream<int> watchTodayCount() =>
      watchToday().map((v) => v.day.length + v.evening.length);

  // ---- Helpers -------------------------------------------------------------

  /// Emits `combine(a, b)` whenever either source emits, once both have
  /// emitted at least once.
  static Stream<T> _combineLatest<A, B, T>(
    Stream<A> a,
    Stream<B> b,
    T Function(A, B) combine,
  ) {
    late StreamController<T> controller;
    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;
    A? lastA;
    B? lastB;
    var hasA = false, hasB = false;

    void emit() {
      if (hasA && hasB) controller.add(combine(lastA as A, lastB as B));
    }

    controller = StreamController<T>(
      onListen: () {
        subA = a.listen((v) {
          lastA = v;
          hasA = true;
          emit();
        }, onError: controller.addError);
        subB = b.listen((v) {
          lastB = v;
          hasB = true;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );
    return controller.stream;
  }
}
