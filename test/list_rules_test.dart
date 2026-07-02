import 'package:flutter_test/flutter_test.dart';
import 'package:openthings/data/db/database.dart';
import 'package:openthings/data/db/enums.dart';
import 'package:openthings/domain/list_rules.dart';

/// Fixed "today" for all rules: 2026-07-01.
final today = DateTime(2026, 7, 1);
final yesterday = DateTime(2026, 6, 30);
final tomorrow = DateTime(2026, 7, 2);
final nextWeek = DateTime(2026, 7, 8);

Task task({
  ItemType type = ItemType.todo,
  ItemStatus status = ItemStatus.open,
  StartBucket bucket = StartBucket.anytime,
  DateTime? startDate,
  bool isEvening = false,
  DateTime? deadline,
  DateTime? trashedAt,
  DateTime? completionDate,
  bool isRepeatTemplate = false,
  String? projectId,
  String? areaId,
}) =>
    Task(
      id: 'id',
      type: type,
      title: 't',
      notes: '',
      status: status,
      startBucket: bucket,
      startDate: startDate,
      isEvening: isEvening,
      deadline: deadline,
      reminderMinutes: null,
      areaId: areaId,
      projectId: projectId,
      headingId: null,
      orderIndex: 0,
      todayIndex: 0,
      repeatMode: RepeatMode.none,
      repeatEveryN: 1,
      repeatUnit: RepeatUnit.day,
      isRepeatTemplate: isRepeatTemplate,
      repeaterTemplateId: null,
      nextInstanceDate: null,
      completionDate: completionDate,
      trashedAt: trashedAt,
      createdAt: today,
      modifiedAt: today,
    );

void main() {
  group('Inbox', () {
    test('bare captured to-do is in Inbox', () {
      expect(ListRules.isInInbox(task(bucket: StartBucket.inbox)), isTrue);
    });

    test('anytime/someday items are not', () {
      expect(ListRules.isInInbox(task()), isFalse);
      expect(ListRules.isInInbox(task(bucket: StartBucket.someday)), isFalse);
    });

    test('completed or trashed inbox items are hidden', () {
      expect(
          ListRules.isInInbox(
              task(bucket: StartBucket.inbox, status: ItemStatus.completed)),
          isFalse);
      expect(
          ListRules.isInInbox(task(bucket: StartBucket.inbox, trashedAt: today)),
          isFalse);
    });
  });

  group('Today', () {
    test('startDate == today', () {
      expect(ListRules.isInToday(task(startDate: today), today), isTrue);
    });

    test('overdue start date still shows in Today', () {
      expect(ListRules.isInToday(task(startDate: yesterday), today), isTrue);
    });

    test('future start date is not Today', () {
      expect(ListRules.isInToday(task(startDate: tomorrow), today), isFalse);
    });

    test('deadline due today surfaces regardless of schedule', () {
      expect(ListRules.isInToday(task(deadline: today), today), isTrue);
    });

    test('overdue deadline surfaces even from Someday', () {
      expect(
          ListRules.isInToday(
              task(bucket: StartBucket.someday, deadline: yesterday), today),
          isTrue);
    });

    test('unscheduled Anytime item is not in Today', () {
      expect(ListRules.isInToday(task(), today), isFalse);
    });

    test('This Evening requires Today membership + flag', () {
      expect(
          ListRules.isInThisEvening(
              task(startDate: today, isEvening: true), today),
          isTrue);
      expect(
          ListRules.isInThisEvening(
              task(startDate: tomorrow, isEvening: true), today),
          isFalse);
      expect(ListRules.isInThisEvening(task(startDate: today), today), isFalse);
    });

    test('projects can appear in Today too', () {
      expect(
          ListRules.isInToday(
              task(type: ItemType.project, startDate: today), today),
          isTrue);
    });
  });

  group('Upcoming', () {
    test('future start date hibernates in Upcoming', () {
      final t = task(startDate: nextWeek);
      expect(ListRules.isInUpcoming(t, today), isTrue);
      expect(ListRules.upcomingDay(t, today), nextWeek);
    });

    test('start date today is NOT Upcoming (it is Today)', () {
      expect(ListRules.isInUpcoming(task(startDate: today), today), isFalse);
    });

    test('future deadline without start date appears on deadline day', () {
      final t = task(deadline: nextWeek);
      expect(ListRules.isInUpcoming(t, today), isTrue);
      expect(ListRules.upcomingDay(t, today), nextWeek);
    });

    test('future start wins over future deadline for display day', () {
      final t = task(startDate: tomorrow, deadline: nextWeek);
      expect(ListRules.upcomingDay(t, today), tomorrow);
    });

    test('someday items never appear in Upcoming', () {
      expect(
          ListRules.isInUpcoming(
              task(bucket: StartBucket.someday, deadline: nextWeek), today),
          isFalse);
    });
  });

  group('Anytime', () {
    test('unscheduled active to-do is in Anytime', () {
      expect(ListRules.isInAnytime(task(), today), isTrue);
    });

    test('Today items are also in Anytime, starred', () {
      final t = task(startDate: today);
      expect(ListRules.isInAnytime(t, today), isTrue);
      expect(ListRules.isStarredInAnytime(t, today), isTrue);
    });

    test('unscheduled items are not starred', () {
      expect(ListRules.isStarredInAnytime(task(), today), isFalse);
    });

    test('deadlined item stays in Anytime (still actionable)', () {
      expect(ListRules.isInAnytime(task(deadline: nextWeek), today), isTrue);
    });

    test('future-scheduled and someday items are excluded', () {
      expect(ListRules.isInAnytime(task(startDate: nextWeek), today), isFalse);
      expect(
          ListRules.isInAnytime(task(bucket: StartBucket.someday), today),
          isFalse);
    });

    test('inbox items are excluded', () {
      expect(
          ListRules.isInAnytime(task(bucket: StartBucket.inbox), today), isFalse);
    });
  });

  group('Someday', () {
    test('someday flag hides item from Anytime/Upcoming, shows in Someday', () {
      final t = task(bucket: StartBucket.someday);
      expect(ListRules.isInSomeday(t), isTrue);
      expect(ListRules.isInAnytime(t, today), isFalse);
      expect(ListRules.isInUpcoming(t, today), isFalse);
    });
  });

  group('Logbook & Trash', () {
    test('completed and cancelled land in Logbook', () {
      expect(
          ListRules.isInLogbook(
              task(status: ItemStatus.completed, completionDate: today)),
          isTrue);
      expect(
          ListRules.isInLogbook(
              task(status: ItemStatus.cancelled, completionDate: today)),
          isTrue);
      expect(ListRules.isInLogbook(task()), isFalse);
    });

    test('trashed items only appear in Trash', () {
      final t = task(trashedAt: today);
      expect(ListRules.isInTrash(t), isTrue);
      expect(ListRules.isInAnytime(t, today), isFalse);
      expect(ListRules.isInLogbook(t), isFalse);
    });
  });

  group('never listable', () {
    test('headings and repeat templates are invisible to built-in lists', () {
      expect(ListRules.isListable(task(type: ItemType.heading)), isFalse);
      expect(ListRules.isListable(task(isRepeatTemplate: true)), isFalse);
      expect(
          ListRules.isInToday(
              task(isRepeatTemplate: true, startDate: today), today),
          isFalse);
    });
  });

  group('Deadlines list', () {
    test('any open item with a deadline', () {
      expect(ListRules.isInDeadlines(task(deadline: nextWeek)), isTrue);
      expect(ListRules.isInDeadlines(task()), isFalse);
    });
  });
}
