import '../data/db/enums.dart';
import 'dates.dart';

/// A parsed "When" expression.
typedef ParsedWhen = ({StartBucket bucket, DateTime? date, bool isEvening});

/// Parses the natural-language date expressions Things accepts in its
/// Jump Start picker: "today", "tomorrow", "this evening", "someday",
/// "next monday", "saturday", "in 4 days", "in 2 weeks", "aug 1",
/// "1 aug", "august 12", "12/8", "2026-08-12", "next month", ...
///
/// Pure and clock-injectable for tests.
class NaturalDateParser {
  NaturalDateParser({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const _weekdays = {
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };

  static const _months = {
    'january': 1, 'jan': 1,
    'february': 2, 'feb': 2,
    'march': 3, 'mar': 3,
    'april': 4, 'apr': 4,
    'may': 5,
    'june': 6, 'jun': 6,
    'july': 7, 'jul': 7,
    'august': 8, 'aug': 8,
    'september': 9, 'sep': 9, 'sept': 9,
    'october': 10, 'oct': 10,
    'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };

  /// Returns null when [input] isn't a recognizable date expression.
  ParsedWhen? parse(String input) {
    final raw = input.trim().toLowerCase();
    if (raw.isEmpty) return null;
    final todayDate = dateOnly(_clock());

    ParsedWhen scheduled(DateTime date, {bool evening = false}) => (
          bucket: StartBucket.anytime,
          date: date,
          isEvening: evening,
        );

    // ---- Keywords ----
    switch (raw) {
      case 'today' || 'tod':
        return scheduled(todayDate);
      case 'this evening' || 'evening' || 'tonight':
        return scheduled(todayDate, evening: true);
      case 'tomorrow' || 'tom' || 'tmr':
        return scheduled(todayDate.add(const Duration(days: 1)));
      case 'someday':
        return (bucket: StartBucket.someday, date: null, isEvening: false);
      case 'anytime':
        return (bucket: StartBucket.anytime, date: null, isEvening: false);
      case 'next week':
        return scheduled(_nextWeekday(todayDate, DateTime.monday));
      case 'this weekend' || 'weekend':
        return scheduled(_nextWeekday(todayDate, DateTime.saturday));
      case 'next month':
        return scheduled(DateTime(todayDate.year, todayDate.month + 1, 1));
    }

    // ---- "next monday" / bare weekday ----
    final weekdayMatch =
        RegExp(r'^(next\s+)?([a-z]+)$').firstMatch(raw);
    if (weekdayMatch != null) {
      final day = _weekdays[weekdayMatch.group(2)];
      if (day != null) {
        var date = _nextWeekday(todayDate, day);
        // "next monday" skips to the following week when the bare
        // weekday would land within this week.
        if (weekdayMatch.group(1) != null &&
            date.difference(todayDate).inDays < 7 &&
            _isSameWeek(todayDate, date)) {
          date = date.add(const Duration(days: 7));
        }
        return scheduled(date);
      }
    }

    // ---- "in N days/weeks/months/years" ----
    final inMatch = RegExp(
            r'^in\s+(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten)\s+(day|week|month|year)s?$')
        .firstMatch(raw);
    if (inMatch != null) {
      final n = _wordToNumber(inMatch.group(1)!);
      final unit = inMatch.group(2)!;
      return scheduled(switch (unit) {
        'day' => todayDate.add(Duration(days: n)),
        'week' => todayDate.add(Duration(days: 7 * n)),
        'month' => addMonthsClamped(todayDate, n),
        _ => addMonthsClamped(todayDate, 12 * n),
      });
    }

    // ---- "aug 1" / "august 12" / "1 aug" / "12 august" ----
    final monthDay = RegExp(r'^([a-z]+)\s+(\d{1,2})$').firstMatch(raw);
    final dayMonth = RegExp(r'^(\d{1,2})\s+([a-z]+)$').firstMatch(raw);
    int? month;
    int? day;
    if (monthDay != null && _months.containsKey(monthDay.group(1))) {
      month = _months[monthDay.group(1)];
      day = int.parse(monthDay.group(2)!);
    } else if (dayMonth != null && _months.containsKey(dayMonth.group(2))) {
      month = _months[dayMonth.group(2)];
      day = int.parse(dayMonth.group(1)!);
    }
    if (month != null && day != null && day >= 1 && day <= 31) {
      var date = DateTime(todayDate.year, month, day);
      if (date.isBefore(todayDate)) {
        date = DateTime(todayDate.year + 1, month, day);
      }
      return scheduled(date);
    }

    // ---- ISO / numeric dates: 2026-08-12, 12/8, 8/12/2026 ----
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(raw);
    if (iso != null) {
      return scheduled(DateTime(int.parse(iso.group(1)!),
          int.parse(iso.group(2)!), int.parse(iso.group(3)!)));
    }
    final slash =
        RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?$').firstMatch(raw);
    if (slash != null) {
      final m = int.parse(slash.group(1)!);
      final d = int.parse(slash.group(2)!);
      var year = slash.group(3) == null
          ? todayDate.year
          : int.parse(slash.group(3)!);
      if (year < 100) year += 2000;
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        var date = DateTime(year, m, d);
        if (slash.group(3) == null && date.isBefore(todayDate)) {
          date = DateTime(year + 1, m, d);
        }
        return scheduled(date);
      }
    }

    return null;
  }

  /// Next occurrence of [weekday] strictly after today... except that a
  /// bare weekday matching today means today.
  DateTime _nextWeekday(DateTime from, int weekday) {
    final delta = (weekday - from.weekday) % 7;
    return from.add(Duration(days: delta == 0 ? 0 : delta));
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    final startOfWeek = a.subtract(Duration(days: a.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return !b.isBefore(startOfWeek) && b.isBefore(endOfWeek);
  }

  int _wordToNumber(String w) {
    const words = {
      'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
      'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    };
    return words[w] ?? int.parse(w);
  }
}
