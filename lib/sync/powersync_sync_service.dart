import 'dart:async';

import 'package:drift/drift.dart' hide Column, Table;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart' hide SyncStatus;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db/database.dart';
import '../data/db/enums.dart';
import 'sync_config.dart';
import 'sync_service.dart';
import 'supabase_sync_service.dart' show supabaseClient;

/// PowerSync tables (id is implicit). Mirrors the drift schema; dates are
/// ISO-8601 text, booleans are 0/1 integers.
const powersyncSchema = Schema([
  Table('tasks', [
    Column.integer('type'),
    Column.text('title'),
    Column.text('notes'),
    Column.integer('status'),
    Column.integer('start_bucket'),
    Column.text('start_date'),
    Column.integer('is_evening'),
    Column.text('deadline'),
    Column.integer('reminder_minutes'),
    Column.text('area_id'),
    Column.text('project_id'),
    Column.text('heading_id'),
    Column.real('order_index'),
    Column.real('today_index'),
    Column.integer('repeat_mode'),
    Column.integer('repeat_every_n'),
    Column.integer('repeat_unit'),
    Column.integer('is_repeat_template'),
    Column.text('repeater_template_id'),
    Column.text('next_instance_date'),
    Column.text('completion_date'),
    Column.text('trashed_at'),
    Column.text('created_at'),
    Column.text('modified_at'),
  ]),
  Table('areas', [
    Column.text('title'),
    Column.real('order_index'),
    Column.text('created_at'),
    Column.text('modified_at'),
  ]),
  Table('checklist_items', [
    Column.text('task_id'),
    Column.text('title'),
    Column.integer('done'),
    Column.real('order_index'),
    Column.text('created_at'),
    Column.text('modified_at'),
  ]),
  Table('tags', [
    Column.text('title'),
    Column.text('parent_tag_id'),
    Column.real('order_index'),
    Column.text('created_at'),
    Column.text('modified_at'),
  ]),
]);

/// Uploads PowerSync CRUD batches to Supabase Postgres and authenticates
/// PowerSync with the Supabase session JWT — the standard
/// PowerSync + Supabase pairing.
class _SupabaseConnector extends PowerSyncBackendConnector {
  _SupabaseConnector(this._client);

  final SupabaseClient _client;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    return PowerSyncCredentials(
      endpoint: SyncConfig.powersyncUrl,
      token: session.accessToken,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;
    final userId = _client.auth.currentUser?.id;
    for (final op in transaction.crud) {
      final table = _client.from(op.table);
      switch (op.op) {
        case UpdateType.put:
          await table.upsert({
            ...?op.opData,
            'id': op.id,
            'user_id': ?userId,
          });
        case UpdateType.patch:
          await table.update({...?op.opData}).eq('id', op.id);
        case UpdateType.delete:
          await table.delete().eq('id', op.id);
      }
    }
    await transaction.complete();
  }
}

/// Sync backend using PowerSync as the offline-first transport:
/// drift stays the app's source of truth; changed rows are mirrored into
/// the PowerSync database (whose CRUD queue uploads to Supabase), and
/// rows streamed down by the PowerSync service are applied back into
/// drift with last-writer-wins on modified_at.
class PowerSyncSyncService implements SyncService {
  PowerSyncSyncService(this._db, this._client);

  final AppDatabase _db;
  final SupabaseClient _client;
  final _statusController = StreamController<SyncStatus>.broadcast();
  PowerSyncDatabase? _ps;
  StreamSubscription<AuthState>? _authSub;
  final List<StreamSubscription<Object?>> _watches = [];
  Timer? _pushTimer;
  bool _syncing = false;

  static const _pushKey = 'ps.lastPushedAt';
  static const _pullKey = 'ps.lastPulledAt';

  @override
  Stream<SyncStatus> get status => _statusController.stream;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  Future<void> init() async {
    _statusController
        .add(isSignedIn ? SyncStatus.connecting : SyncStatus.offline);
    final dir = await getApplicationSupportDirectory();
    final ps = PowerSyncDatabase(
      schema: powersyncSchema,
      path: p.join(dir.path, 'openthings-powersync.db'),
    );
    await ps.initialize();
    _ps = ps;
    _authSub = _client.auth.onAuthStateChange.listen((event) {
      if (event.session != null) {
        _start();
      } else {
        _stop();
        _statusController.add(SyncStatus.offline);
      }
    });
    if (isSignedIn) await _start();
  }

  Future<void> _start() async {
    final ps = _ps;
    if (ps == null) return;
    _statusController.add(SyncStatus.connecting);
    await ps.connect(connector: _SupabaseConnector(_client));
    // Mirror loop: drift -> powersync on a short cadence (the local db
    // is the offline queue; modifiedAt watermark finds unpushed rows).
    _pushTimer?.cancel();
    _pushTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => syncNow());
    // Mirror loop: powersync -> drift whenever synced data changes.
    for (final table in ['tasks', 'areas', 'checklist_items', 'tags']) {
      _watches.add(ps
          .watch('SELECT * FROM $table')
          .listen((_) => _applyDownstream()));
    }
    await syncNow();
  }

  void _stop() {
    _pushTimer?.cancel();
    _pushTimer = null;
    for (final w in _watches) {
      w.cancel();
    }
    _watches.clear();
    _ps?.disconnect();
  }

  @override
  Future<void> syncNow() async {
    final ps = _ps;
    if (ps == null || _syncing || !isSignedIn) return;
    _syncing = true;
    _statusController.add(SyncStatus.syncing);
    try {
      await _pushUpstream(ps);
      await _applyDownstream();
      _statusController.add(SyncStatus.upToDate);
    } catch (_) {
      _statusController.add(SyncStatus.error);
    } finally {
      _syncing = false;
    }
  }

  // ---- drift -> powersync ---------------------------------------------------

  Future<void> _pushUpstream(PowerSyncDatabase ps) async {
    final since = await _watermark(_pushKey);
    final now = DateTime.now().toUtc();

    final tasks = await (_db.select(_db.tasks)
          ..where((t) => t.modifiedAt.isBiggerThanValue(since)))
        .get();
    for (final t in tasks) {
      await ps.execute(
        'INSERT OR REPLACE INTO tasks (id, type, title, notes, status, '
        'start_bucket, start_date, is_evening, deadline, reminder_minutes, '
        'area_id, project_id, heading_id, order_index, today_index, '
        'repeat_mode, repeat_every_n, repeat_unit, is_repeat_template, '
        'repeater_template_id, next_instance_date, completion_date, '
        'trashed_at, created_at, modified_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?, ?)',
        [
          t.id,
          t.type.index,
          t.title,
          t.notes,
          t.status.index,
          t.startBucket.index,
          t.startDate?.toIso8601String(),
          t.isEvening ? 1 : 0,
          t.deadline?.toIso8601String(),
          t.reminderMinutes,
          t.areaId,
          t.projectId,
          t.headingId,
          t.orderIndex,
          t.todayIndex,
          t.repeatMode.index,
          t.repeatEveryN,
          t.repeatUnit.index,
          t.isRepeatTemplate ? 1 : 0,
          t.repeaterTemplateId,
          t.nextInstanceDate?.toIso8601String(),
          t.completionDate?.toUtc().toIso8601String(),
          t.trashedAt?.toUtc().toIso8601String(),
          t.createdAt.toUtc().toIso8601String(),
          t.modifiedAt.toUtc().toIso8601String(),
        ],
      );
    }

    final areas = await (_db.select(_db.areas)
          ..where((a) => a.modifiedAt.isBiggerThanValue(since)))
        .get();
    for (final a in areas) {
      await ps.execute(
        'INSERT OR REPLACE INTO areas (id, title, order_index, created_at, '
        'modified_at) VALUES (?, ?, ?, ?, ?)',
        [
          a.id,
          a.title,
          a.orderIndex,
          a.createdAt.toUtc().toIso8601String(),
          a.modifiedAt.toUtc().toIso8601String(),
        ],
      );
    }

    // Hard deletions queued while offline.
    final pending = await _db.select(_db.pendingDeletions).get();
    for (final d in pending) {
      final table = switch (d.entity) {
        'task' => 'tasks',
        'area' => 'areas',
        'checklist_item' => 'checklist_items',
        'tag' => 'tags',
        _ => null,
      };
      if (table != null) {
        await ps.execute('DELETE FROM $table WHERE id = ?', [d.entityId]);
      }
    }
    await _db.delete(_db.pendingDeletions).go();

    await _setWatermark(_pushKey, now);
  }

  // ---- powersync -> drift ---------------------------------------------------

  Future<void> _applyDownstream() async {
    final ps = _ps;
    if (ps == null) return;
    final since = await _watermark(_pullKey);
    final now = DateTime.now().toUtc();

    final rows = await ps.getAll(
        'SELECT * FROM tasks WHERE modified_at > ?',
        [since.toIso8601String()]);
    for (final row in rows) {
      final id = row['id'] as String;
      final remoteModified = DateTime.parse(row['modified_at'] as String);
      final local = await (_db.select(_db.tasks)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (local != null &&
          !remoteModified.isAfter(local.modifiedAt.toUtc())) {
        continue;
      }
      DateTime? date(String key) => row[key] == null
          ? null
          : DateTime.parse(row[key] as String).toLocal();
      await _db.into(_db.tasks).insertOnConflictUpdate(TasksCompanion.insert(
            id: id,
            type: _enumFrom(row['type'], ItemTypeValues.values),
            title: (row['title'] as String?) ?? '',
            notes: Value((row['notes'] as String?) ?? ''),
            status: _enumFrom(row['status'], ItemStatusValues.values),
            startBucket:
                _enumFrom(row['start_bucket'], StartBucketValues.values),
            startDate: Value(date('start_date')),
            isEvening: Value((row['is_evening'] as int? ?? 0) != 0),
            deadline: Value(date('deadline')),
            reminderMinutes: Value(row['reminder_minutes'] as int?),
            areaId: Value(row['area_id'] as String?),
            projectId: Value(row['project_id'] as String?),
            headingId: Value(row['heading_id'] as String?),
            orderIndex:
                Value((row['order_index'] as num? ?? 0).toDouble()),
            todayIndex:
                Value((row['today_index'] as num? ?? 0).toDouble()),
            repeatMode:
                Value(_enumFrom(row['repeat_mode'], RepeatModeValues.values)),
            repeatEveryN: Value(row['repeat_every_n'] as int? ?? 1),
            repeatUnit:
                Value(_enumFrom(row['repeat_unit'], RepeatUnitValues.values)),
            isRepeatTemplate:
                Value((row['is_repeat_template'] as int? ?? 0) != 0),
            repeaterTemplateId:
                Value(row['repeater_template_id'] as String?),
            nextInstanceDate: Value(date('next_instance_date')),
            completionDate: Value(date('completion_date')),
            trashedAt: Value(date('trashed_at')),
            createdAt: date('created_at') ?? DateTime.now(),
            modifiedAt: date('modified_at') ?? DateTime.now(),
          ));
    }

    final areaRows = await ps.getAll(
        'SELECT * FROM areas WHERE modified_at > ?',
        [since.toIso8601String()]);
    for (final row in areaRows) {
      final id = row['id'] as String;
      final remoteModified = DateTime.parse(row['modified_at'] as String);
      final local = await (_db.select(_db.areas)
            ..where((a) => a.id.equals(id)))
          .getSingleOrNull();
      if (local != null &&
          !remoteModified.isAfter(local.modifiedAt.toUtc())) {
        continue;
      }
      await _db.into(_db.areas).insertOnConflictUpdate(AreasCompanion.insert(
            id: id,
            title: (row['title'] as String?) ?? '',
            orderIndex:
                Value((row['order_index'] as num? ?? 0).toDouble()),
            createdAt:
                DateTime.parse(row['created_at'] as String).toLocal(),
            modifiedAt: remoteModified.toLocal(),
          ));
    }

    await _setWatermark(_pullKey, now);
  }

  // ---- SyncService ----------------------------------------------------------

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

  @override
  Future<void> dispose() async {
    _stop();
    await _authSub?.cancel();
    await _ps?.close();
    await _statusController.close();
  }

  // ---- Helpers ----------------------------------------------------------------

  T _enumFrom<T>(Object? index, List<T> values) =>
      values[(index as int?) ?? 0];

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
}

/// Factory used by the provider: PowerSync when configured.
Future<PowerSyncSyncService> createPowerSyncService(AppDatabase db) async {
  final service = PowerSyncSyncService(db, supabaseClient());
  await service.init();
  return service;
}

// Enum lookups (drift stores enum indexes as ints).
abstract final class ItemTypeValues {
  static const values = ItemType.values;
}

abstract final class ItemStatusValues {
  static const values = ItemStatus.values;
}

abstract final class StartBucketValues {
  static const values = StartBucket.values;
}

abstract final class RepeatModeValues {
  static const values = RepeatMode.values;
}

abstract final class RepeatUnitValues {
  static const values = RepeatUnit.values;
}
