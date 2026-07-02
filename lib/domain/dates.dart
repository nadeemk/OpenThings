/// Date-only helpers. All scheduling in OpenThings is date-based (times
/// only exist for reminders), so we normalize every date to local
/// midnight and compare those.
library;

/// Local midnight for [dt].
DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Local midnight today.
DateTime today({DateTime? clock}) => dateOnly(clock ?? DateTime.now());

extension DateOnlyX on DateTime {
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool isBeforeDay(DateTime other) => dateOnly(this).isBefore(dateOnly(other));

  bool isAfterDay(DateTime other) => dateOnly(this).isAfter(dateOnly(other));
}

/// Adds [n] months clamping the day to the target month's length
/// (Jan 31 + 1 month = Feb 28/29), matching calendar-app conventions.
DateTime addMonthsClamped(DateTime date, int n) {
  final totalMonths = date.year * 12 + (date.month - 1) + n;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;
  return DateTime(year, month, day);
}
