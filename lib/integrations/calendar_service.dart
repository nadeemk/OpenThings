import 'dart:io' show Platform;

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';

/// A calendar event mirrored into Today/Upcoming (read-only, like
/// Things: events are displayed, never synced or edited).
typedef MirroredEvent = ({String title, DateTime? start, DateTime? end});

/// Read-only mirror of the device calendar. Only meaningful on
/// iOS/Android (device_calendar); other platforms return no events.
class CalendarService {
  final _plugin = DeviceCalendarPlugin();

  bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Events between [from] and [to], across all readable calendars.
  /// Returns an empty list when unsupported or permission is denied.
  Future<List<MirroredEvent>> eventsBetween(
      DateTime from, DateTime to) async {
    if (!isSupported) return const [];
    try {
      var permitted = await _plugin.hasPermissions();
      if (permitted.data != true) {
        permitted = await _plugin.requestPermissions();
        if (permitted.data != true) return const [];
      }
      final calendars = await _plugin.retrieveCalendars();
      final events = <MirroredEvent>[];
      for (final cal in calendars.data ?? const <Calendar>[]) {
        final result = await _plugin.retrieveEvents(
          cal.id,
          RetrieveEventsParams(startDate: from, endDate: to),
        );
        for (final e in result.data ?? const <Event>[]) {
          events.add((
            title: e.title ?? '(untitled event)',
            start: e.start,
            end: e.end,
          ));
        }
      }
      events.sort((a, b) => (a.start ?? DateTime(0))
          .compareTo(b.start ?? DateTime(0)));
      return events;
    } catch (_) {
      return const [];
    }
  }
}
