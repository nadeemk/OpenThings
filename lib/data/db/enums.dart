/// Core enums for the OpenThings data model.
///
/// The model mirrors Things 3's semantics: a single `tasks` table holds
/// to-dos, projects, and headings (discriminated by [ItemType]), and the
/// "When" concept is stored as a [StartBucket] plus an optional start date.
library;

/// What kind of row a task record is. Mirrors Things' TMTask.type.
enum ItemType {
  /// A regular to-do.
  todo,

  /// A project: a completable container of to-dos and headings.
  project,

  /// A heading: a section divider inside a project.
  heading,
}

/// The coarse "When" bucket. Mirrors Things' TMTask.start.
///
/// Combined with `startDate` this fully determines list membership:
/// - [inbox]: captured, not yet triaged. No start date.
/// - [anytime]: active. With `startDate == null` it lives in Anytime;
///   with `startDate <= today` it appears in Today; with a future
///   `startDate` it hibernates in Upcoming.
/// - [someday]: on hold; hidden from Anytime/Upcoming until reactivated.
enum StartBucket { inbox, anytime, someday }

/// Open/closed state of a to-do or project.
enum ItemStatus { open, completed, cancelled }

/// How a repeating template spawns instances.
enum RepeatMode {
  /// Not repeating.
  none,

  /// Fixed calendar schedule: every N units regardless of completion.
  /// The next instance is pre-generated.
  fixedSchedule,

  /// Next instance is created N units after the previous one is
  /// checked off.
  afterCompletion,
}

/// Unit for repeat intervals.
enum RepeatUnit { day, week, month, year }
