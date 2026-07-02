import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/db/database.dart';
import '../data/db/enums.dart';
import '../domain/dates.dart';

/// Schedules local notifications for to-do reminders.
///
/// Watches the database and (re)schedules a notification for every open,
/// non-trashed to-do that has a start date and a reminder time in the
/// future. Fires "fast": any edit reschedules within the debounce window,
/// so a reminder set on this device is armed immediately.
///
/// No-op on web (no local notification support).
class NotificationService {
  NotificationService(this._db);

  final AppDatabase _db;
  final _plugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<List<Task>>? _sub;
  Timer? _debounce;
  bool _initialized = false;

  Future<void> init() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to the package default (UTC).
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );
    _initialized = await _plugin.initialize(settings) ?? false;
    if (!_initialized) return;

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Reschedule whenever reminder-relevant rows change.
    _sub = (_db.select(_db.tasks)
          ..where((t) =>
              t.reminderMinutes.isNotNull() &
              t.trashedAt.isNull() &
              t.status.equals(ItemStatus.open.index)))
        .watch()
        .listen((tasks) {
      _debounce?.cancel();
      _debounce = Timer(
          const Duration(milliseconds: 400), () => _reschedule(tasks));
    });
  }

  Future<void> _reschedule(List<Task> tasks) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    final now = DateTime.now();
    // Platforms cap pending notifications (iOS: 64); schedule the soonest.
    final upcoming = tasks
        .where((t) => t.startDate != null && t.reminderMinutes != null)
        .map((t) => (
              task: t,
              fireAt: dateOnly(t.startDate!)
                  .add(Duration(minutes: t.reminderMinutes!)),
            ))
        .where((e) => e.fireAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.fireAt.compareTo(b.fireAt));

    for (final (i, e) in upcoming.take(60).indexed) {
      await _plugin.zonedSchedule(
        i,
        e.task.title.isEmpty ? 'To-Do' : e.task.title,
        e.task.notes.isEmpty ? null : e.task.notes,
        tz.TZDateTime.from(e.fireAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders',
            'Reminders',
            channelDescription: 'To-do reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: e.task.id,
      );
    }
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _sub?.cancel();
  }
}
