import 'package:flutter_test/flutter_test.dart';
import 'package:openthings/data/db/enums.dart';
import 'package:openthings/domain/dates.dart';
import 'package:openthings/domain/repeat_engine.dart';

void main() {
  group('RepeatEngine.nextFixed', () {
    test('daily', () {
      expect(
        RepeatEngine.nextFixed(
            current: DateTime(2026, 7, 1), everyN: 1, unit: RepeatUnit.day),
        DateTime(2026, 7, 2),
      );
    });

    test('every 2 weeks', () {
      expect(
        RepeatEngine.nextFixed(
            current: DateTime(2026, 7, 1), everyN: 2, unit: RepeatUnit.week),
        DateTime(2026, 7, 15),
      );
    });

    test('monthly clamps to shorter months', () {
      expect(
        RepeatEngine.nextFixed(
            current: DateTime(2026, 1, 31), everyN: 1, unit: RepeatUnit.month),
        DateTime(2026, 2, 28),
      );
    });

    test('yearly over leap day', () {
      expect(
        RepeatEngine.nextFixed(
            current: DateTime(2028, 2, 29), everyN: 1, unit: RepeatUnit.year),
        DateTime(2029, 2, 28),
      );
    });
  });

  group('RepeatEngine.catchUpFixed', () {
    test('walks forward to today or later, staying on schedule', () {
      // Weekly anchored on a Wednesday, three weeks stale.
      expect(
        RepeatEngine.catchUpFixed(
          nextDate: DateTime(2026, 6, 10),
          everyN: 1,
          unit: RepeatUnit.week,
          todayDate: DateTime(2026, 7, 1),
        ),
        DateTime(2026, 7, 1),
      );
    });

    test('leaves future dates alone', () {
      expect(
        RepeatEngine.catchUpFixed(
          nextDate: DateTime(2026, 8, 1),
          everyN: 1,
          unit: RepeatUnit.day,
          todayDate: DateTime(2026, 7, 1),
        ),
        DateTime(2026, 8, 1),
      );
    });
  });

  group('date helpers', () {
    test('addMonthsClamped handles year wrap', () {
      expect(addMonthsClamped(DateTime(2026, 11, 30), 3), DateTime(2027, 2, 28));
    });

    test('dateOnly strips time', () {
      expect(dateOnly(DateTime(2026, 7, 1, 23, 59)), DateTime(2026, 7, 1));
    });
  });
}
