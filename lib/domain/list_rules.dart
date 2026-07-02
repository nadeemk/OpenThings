import '../data/db/database.dart';
import '../data/db/enums.dart';
import 'dates.dart';

/// Pure membership rules for the built-in lists.
///
/// These are THE core semantics of the app, mirroring Things 3:
/// list membership is always derived from the item's state + today's
/// date — never stored. Every predicate takes [todayDate] so the rules
/// are deterministic and testable.
///
/// All predicates assume headings and repeat templates are filtered out
/// (they never appear in built-in lists) — [isListable] handles that.
abstract final class ListRules {
  /// Whether a row can ever appear in a built-in list.
  static bool isListable(Task t) =>
      t.type != ItemType.heading && !t.isRepeatTemplate && t.trashedAt == null;

  static bool _openListable(Task t) =>
      isListable(t) && t.status == ItemStatus.open;

  /// Inbox: captured, untriaged to-dos.
  static bool isInInbox(Task t) =>
      _openListable(t) &&
      t.type == ItemType.todo &&
      t.startBucket == StartBucket.inbox;

  /// Today: start date has arrived (or passed), or the deadline is due
  /// today / overdue — a due deadline surfaces the item regardless of
  /// its bucket, matching Things.
  static bool isInToday(Task t, DateTime todayDate) {
    if (!_openListable(t)) return false;
    final startArrived = t.startBucket == StartBucket.anytime &&
        t.startDate != null &&
        !t.startDate!.isAfterDay(todayDate);
    final deadlineDue = t.deadline != null && !t.deadline!.isAfterDay(todayDate);
    return startArrived || deadlineDue;
  }

  /// The This Evening section within Today.
  static bool isInThisEvening(Task t, DateTime todayDate) =>
      isInToday(t, todayDate) && t.isEvening;

  /// Upcoming: hibernating until a future start date. Items whose only
  /// future date is a deadline also appear (on the deadline day).
  static bool isInUpcoming(Task t, DateTime todayDate) {
    if (!_openListable(t)) return false;
    final futureStart = t.startBucket == StartBucket.anytime &&
        t.startDate != null &&
        t.startDate!.isAfterDay(todayDate);
    final futureDeadline = t.startBucket != StartBucket.someday &&
        t.deadline != null &&
        t.deadline!.isAfterDay(todayDate) &&
        // Only when not already scheduled later than the deadline view day:
        (t.startDate == null || !t.startDate!.isAfterDay(t.deadline!));
    return futureStart || (futureDeadline && !futureStart);
  }

  /// The date under which an item is shown in Upcoming.
  static DateTime? upcomingDay(Task t, DateTime todayDate) {
    if (!isInUpcoming(t, todayDate)) return null;
    final futureStart = t.startDate != null &&
        t.startDate!.isAfterDay(todayDate) &&
        t.startBucket == StartBucket.anytime;
    if (futureStart) return dateOnly(t.startDate!);
    return dateOnly(t.deadline!);
  }

  /// Anytime: active now — no future start date, not someday, not inbox.
  /// Items that are in Today are ALSO in Anytime (starred there).
  static bool isInAnytime(Task t, DateTime todayDate) {
    if (!_openListable(t)) return false;
    if (t.startBucket != StartBucket.anytime) return false;
    return t.startDate == null || !t.startDate!.isAfterDay(todayDate);
  }

  /// Whether an Anytime row gets the yellow Today star.
  static bool isStarredInAnytime(Task t, DateTime todayDate) =>
      isInAnytime(t, todayDate) && isInToday(t, todayDate);

  /// Someday: on hold. Hidden from Anytime and Upcoming.
  static bool isInSomeday(Task t) =>
      _openListable(t) && t.startBucket == StartBucket.someday;

  /// Logbook: completed or cancelled, not trashed.
  static bool isInLogbook(Task t) =>
      isListable(t) && t.status != ItemStatus.open;

  /// Trash.
  static bool isInTrash(Task t) =>
      t.trashedAt != null && t.type != ItemType.heading && !t.isRepeatTemplate;

  /// Deadlines list: any open item carrying a deadline, chronological.
  static bool isInDeadlines(Task t) => _openListable(t) && t.deadline != null;
}
