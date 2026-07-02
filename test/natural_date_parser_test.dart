import 'package:flutter_test/flutter_test.dart';
import 'package:openthings/data/db/enums.dart';
import 'package:openthings/domain/natural_date_parser.dart';

void main() {
  // Fixed clock: Wednesday 2026-07-01.
  final parser = NaturalDateParser(clock: () => DateTime(2026, 7, 1, 10));

  DateTime? dateOf(String s) => parser.parse(s)?.date;

  group('keywords', () {
    test('today / tomorrow / tonight', () {
      expect(dateOf('today'), DateTime(2026, 7, 1));
      expect(dateOf('Tomorrow'), DateTime(2026, 7, 2));
      final tonight = parser.parse('tonight')!;
      expect(tonight.date, DateTime(2026, 7, 1));
      expect(tonight.isEvening, isTrue);
    });

    test('someday / anytime buckets', () {
      expect(parser.parse('someday')!.bucket, StartBucket.someday);
      expect(parser.parse('someday')!.date, isNull);
      expect(parser.parse('anytime')!.bucket, StartBucket.anytime);
    });

    test('next week lands on next monday', () {
      expect(dateOf('next week'), DateTime(2026, 7, 6));
    });

    test('weekend lands on saturday', () {
      expect(dateOf('weekend'), DateTime(2026, 7, 4));
    });
  });

  group('weekdays', () {
    test('bare weekday = next occurrence (this week if ahead)', () {
      expect(dateOf('saturday'), DateTime(2026, 7, 4));
      expect(dateOf('fri'), DateTime(2026, 7, 3));
    });

    test('bare weekday matching today = today', () {
      expect(dateOf('wednesday'), DateTime(2026, 7, 1));
    });

    test('"next friday" skips to the following week', () {
      expect(dateOf('next friday'), DateTime(2026, 7, 10));
    });
  });

  group('relative offsets', () {
    test('in N days/weeks', () {
      expect(dateOf('in 4 days'), DateTime(2026, 7, 5));
      expect(dateOf('in 2 weeks'), DateTime(2026, 7, 15));
    });

    test('in a month clamps day', () {
      final p = NaturalDateParser(clock: () => DateTime(2026, 1, 31));
      expect(p.parse('in one month')!.date, DateTime(2026, 2, 28));
    });
  });

  group('explicit dates', () {
    test('month-day and day-month forms', () {
      expect(dateOf('aug 1'), DateTime(2026, 8, 1));
      expect(dateOf('1 aug'), DateTime(2026, 8, 1));
      expect(dateOf('august 12'), DateTime(2026, 8, 12));
    });

    test('past month-day rolls to next year', () {
      expect(dateOf('jan 5'), DateTime(2027, 1, 5));
    });

    test('ISO and slash dates', () {
      expect(dateOf('2026-08-12'), DateTime(2026, 8, 12));
      expect(dateOf('8/12'), DateTime(2026, 8, 12));
      expect(dateOf('8/12/2027'), DateTime(2027, 8, 12));
    });
  });

  group('rejects noise', () {
    test('non-dates return null', () {
      expect(parser.parse('buy milk'), isNull);
      expect(parser.parse(''), isNull);
      expect(parser.parse('13/45'), isNull);
    });
  });
}
