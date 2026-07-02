import '../data/db/enums.dart';
import 'dates.dart';

/// Pure logic for computing repeat occurrences.
///
/// Two modes, matching Things 3:
/// - [RepeatMode.fixedSchedule]: occurrences fall every N units on the
///   calendar, anchored to the template's schedule, regardless of when
///   (or whether) the previous instance was completed. The next instance
///   is pre-generated as soon as the current one exists.
/// - [RepeatMode.afterCompletion]: the next instance is created only when
///   the previous one is checked off, scheduled N units after the
///   completion day.
abstract final class RepeatEngine {
  /// Next occurrence strictly after [current] for a fixed-schedule rule.
  static DateTime nextFixed({
    required DateTime current,
    required int everyN,
    required RepeatUnit unit,
  }) {
    assert(everyN >= 1);
    final base = dateOnly(current);
    return switch (unit) {
      RepeatUnit.day => base.add(Duration(days: everyN)),
      RepeatUnit.week => base.add(Duration(days: 7 * everyN)),
      RepeatUnit.month => addMonthsClamped(base, everyN),
      RepeatUnit.year => addMonthsClamped(base, 12 * everyN),
    };
  }

  /// Start date for the instance spawned when an after-completion repeater
  /// is checked off on [completionDay].
  static DateTime nextAfterCompletion({
    required DateTime completionDay,
    required int everyN,
    required RepeatUnit unit,
  }) =>
      nextFixed(current: completionDay, everyN: everyN, unit: unit);

  /// For fixed-schedule templates: catch up [nextDate] so it is not in the
  /// past (e.g. app unused for weeks). Walks forward in rule-sized steps
  /// so occurrences stay anchored to the original schedule.
  static DateTime catchUpFixed({
    required DateTime nextDate,
    required int everyN,
    required RepeatUnit unit,
    required DateTime todayDate,
  }) {
    var next = dateOnly(nextDate);
    final limit = dateOnly(todayDate);
    while (next.isBefore(limit)) {
      next = nextFixed(current: next, everyN: everyN, unit: unit);
    }
    return next;
  }
}
