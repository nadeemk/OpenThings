import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/db/enums.dart';
import '../data/list_queries.dart';
import '../data/repositories/area_repository.dart';
import '../data/repositories/checklist_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../data/repositories/task_repository.dart';
import '../domain/dates.dart' as d;
import '../integrations/calendar_service.dart';
import '../integrations/notification_service.dart';
import '../sync/supabase_sync_service.dart';
import '../sync/sync_config.dart';
import '../sync/sync_service.dart';

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

final listQueriesProvider =
    Provider<ListQueries>((ref) => ListQueries(ref.watch(databaseProvider)));

// ---- Reactive list views ---------------------------------------------------

final inboxProvider = StreamProvider<List<Task>>(
    (ref) => ref.watch(listQueriesProvider).watchInbox());

final todayProvider = StreamProvider<TodayView>(
    (ref) => ref.watch(listQueriesProvider).watchToday());

final upcomingProvider = StreamProvider<UpcomingView>(
    (ref) => ref.watch(listQueriesProvider).watchUpcoming());

final anytimeProvider = StreamProvider<List<AnytimeSection>>(
    (ref) => ref.watch(listQueriesProvider).watchAnytime());

final somedayProvider = StreamProvider<List<Task>>(
    (ref) => ref.watch(listQueriesProvider).watchSomeday());

final logbookProvider = StreamProvider<LogbookView>(
    (ref) => ref.watch(listQueriesProvider).watchLogbook());

final trashProvider = StreamProvider<List<Task>>(
    (ref) => ref.watch(listQueriesProvider).watchTrash());

final inboxCountProvider = StreamProvider<int>(
    (ref) => ref.watch(listQueriesProvider).watchInboxCount());

final todayCountProvider = StreamProvider<int>(
    (ref) => ref.watch(listQueriesProvider).watchTodayCount());

final areasProvider = StreamProvider<List<Area>>(
    (ref) => ref.watch(areaRepositoryProvider).watchAll());

/// All open, non-trashed projects (for the sidebar and move pickers).
final projectsProvider = StreamProvider<List<Task>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.tasks).watch().map((rows) => rows
      .where((t) =>
          t.type == ItemType.project &&
          t.trashedAt == null &&
          t.status == ItemStatus.open)
      .toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)));
});

/// A single task by id (detail editor, project screen).
final taskByIdProvider = StreamProvider.family<Task?, String>(
    (ref, id) => ref.watch(taskRepositoryProvider).watchById(id));

/// Children of a project, in manual order.
final projectChildrenProvider = StreamProvider.family<List<Task>, String>(
    (ref, id) => ref.watch(taskRepositoryProvider).watchProjectChildren(id));

/// Checklist of a to-do.
final checklistProvider = StreamProvider.family<List<ChecklistItem>, String>(
    (ref, taskId) =>
        ref.watch(checklistRepositoryProvider).watchForTask(taskId));

/// Tags of a to-do.
final taskTagsProvider = StreamProvider.family<List<Tag>, String>(
    (ref, taskId) => ref.watch(tagRepositoryProvider).watchTagsForTask(taskId));

/// All tags.
final allTagsProvider = StreamProvider<List<Tag>>(
    (ref) => ref.watch(tagRepositoryProvider).watchAll());

/// Which to-do is currently expanded inline for editing (null = none).
class ExpandedTaskId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final expandedTaskIdProvider =
    NotifierProvider<ExpandedTaskId, String?>(ExpandedTaskId.new);

// ---- Sync -------------------------------------------------------------------

/// The sync backend. NoopSyncService unless SUPABASE_URL /
/// SUPABASE_ANON_KEY are provided at build time (see SyncConfig).
final syncServiceProvider = Provider<SyncService>((ref) {
  if (!SyncConfig.enabled) return NoopSyncService();
  final service = SupabaseSyncService(
    ref.watch(databaseProvider),
    supabaseClient(),
  );
  ref.onDispose(service.dispose);
  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus>(
    (ref) => ref.watch(syncServiceProvider).status);

// ---- Integrations -----------------------------------------------------------

/// Reminder notifications. Reading this provider once (in the shell)
/// arms the scheduler for the app's lifetime.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref.watch(databaseProvider));
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

final calendarServiceProvider =
    Provider<CalendarService>((ref) => CalendarService());

/// Today's calendar events, mirrored read-only at the top of Today.
final todayEventsProvider = FutureProvider<List<MirroredEvent>>((ref) {
  final t = d.today();
  return ref
      .watch(calendarServiceProvider)
      .eventsBetween(t, t.add(const Duration(days: 1)));
});
