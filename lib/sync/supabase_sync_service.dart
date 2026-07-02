import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db/database.dart';
import '../data/db/enums.dart';
import 'sync_service.dart';

/// The initialized Supabase client (Supabase.initialize must have run —
/// see main()).
SupabaseClient supabaseClient() => Supabase.instance.client;

/// Offline-first bidirectional sync against Supabase Postgres.
///
/// Strategy:
/// - The local drift database is the write queue: every repository write
///   stamps `modifiedAt`, so "unsynced" = `modifiedAt > lastPushedAt`.
/// - Push: upsert local rows changed since the push watermark.
/// - Pull: fetch remote rows changed since the pull watermark and apply
///   with last-writer-wins on `modified_at` (newer side wins per row).
/// - Hard deletions propagate through a `deletions` tombstone table,
///   queued locally in `pending_deletions` while offline.
/// - A Postgres realtime channel nudges an immediate pull when another
///   device pushes (the "fastlane" for reminders and edits).
class SupabaseSyncService implements SyncService {
  SupabaseSyncService(this._db, this._client) {
    _statusController.add(
        _client.auth.currentSession == null ? SyncStatus.offline : SyncStatus.connecting);
    _authSub = _client.auth.onAuthStateChange.listen((event) {
      if (event.session != null) {
        _startContinuousSync();
      } else {
        _stopContinuousSync();
        _statusController.add(SyncStatus.offline);
      }
    });
    if (isSignedIn) _startContinuousSync();
  }

  final AppDatabase _db;
  final SupabaseClient _client;
  final _statusController = StreamController<SyncStatus>.broadcast();
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Set<TableUpdate>>? _localSub;
  Timer? _pollTimer;
  Timer? _debounce;
  RealtimeChannel? _channel;
  bool _syncing = false;
  bool _resyncQueued = false;

  static const _pushKey = 'lastPushedAt';
  static const _pullKey = 'lastPulledAt';

  @override
  Stream<SyncStatus> get status => _statusController.stream;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  @override
  Future<void> signUp({required String email, required String password}) =>
      _client.auth.signUp(email: email, password: password);

  @override
  Future<void> signInWithOAuth(String provider) =>
      _client.auth.signInWithOAuth(switch (provider) {
        'apple' => OAuthProvider.apple,
        'google' => OAuthProvider.google,
        _ => throw ArgumentError.value(provider, 'provider'),
      });

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    await _client.rpc('delete_account');
    await _client.auth.signOut();
  }

  void _startContinuousSync() {
    _statusController.add(SyncStatus.connecting);
    // Sync now, then poll as a fallback and subscribe for pushes.
    unawaited(syncNow());
    // Fallback poll — snappy enough to feel live even if Realtime is
    // unavailable, cheap enough for a single user.
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => syncNow());

    // Push local edits as they happen: watch the content tables (not the
    // sync-bookkeeping tables, to avoid a feedback loop) and sync ~1s
    // after the last change.
    _localSub?.cancel();
    _localSub = _db
        .tableUpdates(TableUpdateQuery.onAllTables([
          _db.tasks,
          _db.areas,
          _db.checklistItems,
          _db.tags,
          _db.taskTags,
          _db.pendingDeletions,
        ]))
        .listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 900), syncNow);
    });

    // Pull instantly when another device changes anything (requires the
    // tables to be in the supabase_realtime publication — see
    // supabase/migrations/0003_realtime.sql).
    _channel?.unsubscribe();
    var channel = _client.channel('sync-nudge');
    for (final table in const ['tasks', 'areas', 'checklist_items', 'tags']) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => syncNow(),
      );
    }
    _channel = channel..subscribe();
  }

  void _stopContinuousSync() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _debounce?.cancel();
    _debounce = null;
    _localSub?.cancel();
    _localSub = null;
    _channel?.unsubscribe();
    _channel = null;
  }

  @override
  Future<void> syncNow() async {
    if (!isSignedIn) return;
    // If a sync is already running, remember to run once more after it so
    // edits made mid-sync aren't missed.
    if (_syncing) {
      _resyncQueued = true;
      return;
    }
    _syncing = true;
    _statusController.add(SyncStatus.syncing);
    try {
      await _pushDeletions();
      await _push();
      await _pull();
      _statusController.add(SyncStatus.upToDate);
    } catch (e, st) {
      debugPrint('[sync] failed: $e\n$st');
      _statusController.add(SyncStatus.error);
    } finally {
      _syncing = false;
    }
    if (_resyncQueued) {
      _resyncQueued = false;
      unawaited(syncNow());
    }
  }

  // ---- Push ---------------------------------------------------------------

  Future<void> _push() async {
    final since = await _watermark(_pushKey);
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now().toUtc();

    final tasks = await (_db.select(_db.tasks)
          ..where((t) => t.modifiedAt.isBiggerThanValue(since)))
        .get();
    if (tasks.isNotEmpty) {
      await _client.from('tasks').upsert([
        for (final t in tasks) _taskToRow(t, userId),
      ]);
    }

    final areas = await (_db.select(_db.areas)
          ..where((a) => a.modifiedAt.isBiggerThanValue(since)))
        .get();
    if (areas.isNotEmpty) {
      await _client.from('areas').upsert([
        for (final a in areas)
          {
            'id': a.id,
            'user_id': userId,
            'title': a.title,
            'order_index': a.orderIndex,
            'created_at': a.createdAt.toUtc().toIso8601String(),
            'modified_at': a.modifiedAt.toUtc().toIso8601String(),
          },
      ]);
    }

    final checklist = await (_db.select(_db.checklistItems)
          ..where((c) => c.modifiedAt.isBiggerThanValue(since)))
        .get();
    if (checklist.isNotEmpty) {
      await _client.from('checklist_items').upsert([
        for (final c in checklist)
          {
            'id': c.id,
            'user_id': userId,
            'task_id': c.taskId,
            'title': c.title,
            'done': c.done,
            'order_index': c.orderIndex,
            'created_at': c.createdAt.toUtc().toIso8601String(),
            'modified_at': c.modifiedAt.toUtc().toIso8601String(),
          },
      ]);
    }

    final tags = await (_db.select(_db.tags)
          ..where((t) => t.modifiedAt.isBiggerThanValue(since)))
        .get();
    if (tags.isNotEmpty) {
      await _client.from('tags').upsert([
        for (final t in tags)
          {
            'id': t.id,
            'user_id': userId,
            'title': t.title,
            'parent_tag_id': t.parentTagId,
            'order_index': t.orderIndex,
            'created_at': t.createdAt.toUtc().toIso8601String(),
            'modified_at': t.modifiedAt.toUtc().toIso8601String(),
          },
      ]);
    }

    await _setWatermark(_pushKey, now);
  }

  Future<void> _pushDeletions() async {
    final pending = await _db.select(_db.pendingDeletions).get();
    if (pending.isEmpty) return;
    final userId = _client.auth.currentUser!.id;
    await _client.from('deletions').insert([
      for (final p in pending)
        {
          'user_id': userId,
          'entity': p.entity,
          'entity_id': p.entityId,
          'deleted_at': p.deletedAt.toUtc().toIso8601String(),
        },
    ]);
    // Delete the actual remote rows too.
    for (final p in pending) {
      final table = switch (p.entity) {
        'task' => 'tasks',
        'area' => 'areas',
        'checklist_item' => 'checklist_items',
        'tag' => 'tags',
        _ => null,
      };
      if (table != null) {
        await _client.from(table).delete().eq('id', p.entityId);
      }
    }
    await _db.delete(_db.pendingDeletions).go();
  }

  // ---- Pull ---------------------------------------------------------------

  Future<void> _pull() async {
    final since = await _watermark(_pullKey);
    final now = DateTime.now().toUtc();

    final remoteTasks = await _client
        .from('tasks')
        .select()
        .gt('modified_at', since.toIso8601String());
    for (final row in remoteTasks) {
      await _applyRemoteTask(row);
    }

    final remoteAreas = await _client
        .from('areas')
        .select()
        .gt('modified_at', since.toIso8601String());
    for (final row in remoteAreas) {
      await _applyLww(
        table: _db.areas,
        id: row['id'] as String,
        remoteModified: DateTime.parse(row['modified_at'] as String),
        localModified: (Area a) => a.modifiedAt,
        insert: AreasCompanion.insert(
          id: row['id'] as String,
          title: row['title'] as String,
          orderIndex: Value((row['order_index'] as num).toDouble()),
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          modifiedAt: DateTime.parse(row['modified_at'] as String).toLocal(),
        ),
      );
    }

    final remoteChecklist = await _client
        .from('checklist_items')
        .select()
        .gt('modified_at', since.toIso8601String());
    for (final row in remoteChecklist) {
      await _applyLww(
        table: _db.checklistItems,
        id: row['id'] as String,
        remoteModified: DateTime.parse(row['modified_at'] as String),
        localModified: (ChecklistItem c) => c.modifiedAt,
        insert: ChecklistItemsCompanion.insert(
          id: row['id'] as String,
          taskId: row['task_id'] as String,
          title: row['title'] as String,
          done: Value(row['done'] as bool),
          orderIndex: Value((row['order_index'] as num).toDouble()),
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          modifiedAt: DateTime.parse(row['modified_at'] as String).toLocal(),
        ),
      );
    }

    final remoteTags = await _client
        .from('tags')
        .select()
        .gt('modified_at', since.toIso8601String());
    for (final row in remoteTags) {
      await _applyLww(
        table: _db.tags,
        id: row['id'] as String,
        remoteModified: DateTime.parse(row['modified_at'] as String),
        localModified: (Tag t) => t.modifiedAt,
        insert: TagsCompanion.insert(
          id: row['id'] as String,
          title: row['title'] as String,
          parentTagId: Value(row['parent_tag_id'] as String?),
          orderIndex: Value((row['order_index'] as num).toDouble()),
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          modifiedAt: DateTime.parse(row['modified_at'] as String).toLocal(),
        ),
      );
    }

    // Apply remote tombstones.
    final tombstones = await _client
        .from('deletions')
        .select()
        .gt('deleted_at', since.toIso8601String());
    for (final row in tombstones) {
      final id = row['entity_id'] as String;
      switch (row['entity'] as String) {
        case 'task':
          await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
        case 'area':
          await (_db.delete(_db.areas)..where((a) => a.id.equals(id))).go();
        case 'checklist_item':
          await (_db.delete(_db.checklistItems)
                ..where((c) => c.id.equals(id)))
              .go();
        case 'tag':
          await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
      }
    }

    await _setWatermark(_pullKey, now);
  }

  Future<void> _applyRemoteTask(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final remoteModified = DateTime.parse(row['modified_at'] as String);
    final local = await (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    // Last-writer-wins on the row's modification time.
    if (local != null && !remoteModified.isAfter(local.modifiedAt.toUtc())) {
      return;
    }
    DateTime? date(String key) => row[key] == null
        ? null
        : DateTime.parse(row[key] as String).toLocal();
    await _db.into(_db.tasks).insertOnConflictUpdate(TasksCompanion.insert(
          id: id,
          type: _intToEnum(row['type'] as int, ItemTypeExt.values),
          title: row['title'] as String,
          notes: Value(row['notes'] as String),
          status: _intToEnum(row['status'] as int, ItemStatusExt.values),
          startBucket:
              _intToEnum(row['start_bucket'] as int, StartBucketExt.values),
          startDate: Value(date('start_date')),
          isEvening: Value(row['is_evening'] as bool),
          deadline: Value(date('deadline')),
          reminderMinutes: Value(row['reminder_minutes'] as int?),
          areaId: Value(row['area_id'] as String?),
          projectId: Value(row['project_id'] as String?),
          headingId: Value(row['heading_id'] as String?),
          orderIndex: Value((row['order_index'] as num).toDouble()),
          todayIndex: Value((row['today_index'] as num).toDouble()),
          repeatMode: Value(
              _intToEnum(row['repeat_mode'] as int, RepeatModeExt.values)),
          repeatEveryN: Value(row['repeat_every_n'] as int),
          repeatUnit: Value(
              _intToEnum(row['repeat_unit'] as int, RepeatUnitExt.values)),
          isRepeatTemplate: Value(row['is_repeat_template'] as bool),
          repeaterTemplateId: Value(row['repeater_template_id'] as String?),
          nextInstanceDate: Value(date('next_instance_date')),
          completionDate: Value(date('completion_date')),
          trashedAt: Value(date('trashed_at')),
          createdAt: date('created_at')!,
          modifiedAt: date('modified_at')!,
        ));
  }

  Future<void> _applyLww<TableT extends Table, Row>({
    required TableInfo<TableT, Row> table,
    required String id,
    required DateTime remoteModified,
    required DateTime Function(Row) localModified,
    required Insertable<Row> insert,
  }) async {
    final local = await (_db.select(table)
          ..where((t) => (t as dynamic).id.equals(id) as Expression<bool>))
        .getSingleOrNull();
    if (local != null &&
        !remoteModified.isAfter(localModified(local).toUtc())) {
      return;
    }
    await _db.into(table).insertOnConflictUpdate(insert);
  }

  // ---- Helpers --------------------------------------------------------------

  Map<String, dynamic> _taskToRow(Task t, String userId) => {
        'id': t.id,
        'user_id': userId,
        'type': t.type.index,
        'title': t.title,
        'notes': t.notes,
        'status': t.status.index,
        'start_bucket': t.startBucket.index,
        'start_date': _dateOnlyIso(t.startDate),
        'is_evening': t.isEvening,
        'deadline': _dateOnlyIso(t.deadline),
        'reminder_minutes': t.reminderMinutes,
        'area_id': t.areaId,
        'project_id': t.projectId,
        'heading_id': t.headingId,
        'order_index': t.orderIndex,
        'today_index': t.todayIndex,
        'repeat_mode': t.repeatMode.index,
        'repeat_every_n': t.repeatEveryN,
        'repeat_unit': t.repeatUnit.index,
        'is_repeat_template': t.isRepeatTemplate,
        'repeater_template_id': t.repeaterTemplateId,
        'next_instance_date': _dateOnlyIso(t.nextInstanceDate),
        'completion_date': t.completionDate?.toUtc().toIso8601String(),
        'trashed_at': t.trashedAt?.toUtc().toIso8601String(),
        'created_at': t.createdAt.toUtc().toIso8601String(),
        'modified_at': t.modifiedAt.toUtc().toIso8601String(),
      };

  String? _dateOnlyIso(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  T _intToEnum<T>(int index, List<T> values) => values[index];

  Future<DateTime> _watermark(String key) async {
    final row = await (_db.select(_db.syncState)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.parse(row.value);
  }

  Future<void> _setWatermark(String key, DateTime value) =>
      _db.into(_db.syncState).insertOnConflictUpdate(SyncStateCompanion.insert(
          key: key, value: value.toIso8601String()));

  @override
  Future<void> dispose() async {
    _stopContinuousSync();
    await _authSub?.cancel();
    await _statusController.close();
  }
}

// Enum lookup tables (drift stores enum indexes).
abstract final class ItemTypeExt {
  static const values = ItemType.values;
}

abstract final class ItemStatusExt {
  static const values = ItemStatus.values;
}

abstract final class StartBucketExt {
  static const values = StartBucket.values;
}

abstract final class RepeatModeExt {
  static const values = RepeatMode.values;
}

abstract final class RepeatUnitExt {
  static const values = RepeatUnit.values;
}
