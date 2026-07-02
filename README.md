# OpenThings

A cross-platform clone of [Things 3](https://culturedcode.com/things/) built with Flutter — **one codebase for iOS, Android, macOS, Windows, Linux, and Web**. Local-first: every feature works fully offline; sync is additive.

## Features

- **The Things model, faithfully**: Inbox · Today (with **This Evening**) · Upcoming · Anytime (Today items starred) · Someday · Logbook · Trash — all derived live from the data, never stored
- **Three independent date concepts** per item: *When* (start date), *Deadline* (red countdown flag, overdue surfaces in Today), *Reminder* (notification time)
- **Areas › Projects › Headings › To-dos › Checklists**, with tags
- **Repeaters, both modes**: fixed calendar schedule (pre-generated) and after-completion
- **Natural-language dates**: "tomorrow", "next monday", "in 4 days", "aug 1", "someday"
- **Quick Find** (⌘K): type-travel to any list, project, tag, or to-do
- **Quick Entry** (⌃Space): capture dialog with NL scheduling
- **Magic Plus**: drag the + button to insert a to-do exactly where you drop it
- Multi-select + batch edit, swipe actions, keyboard-first (⌘N, ⌘1–5, ⌘T/⌘E/⌘O, ⌘., ⌘←/→…)
- Project **progress pies**, Markdown notes, light/dark mode
- **Reminders** as local notifications; read-only **calendar mirror** in Today
- `things://` / `openthings://` deep links (`/add?title=…&when=tomorrow`)
- Optional **multi-device sync** via Supabase (offline-first, LWW, tombstoned deletes)

## Architecture

```
lib/
  core/       Design tokens (Things-blue palette, typography, spacing)
  data/       drift (SQLite) schema, repositories, reactive list queries
  domain/     Pure logic: date model, list-membership rules (ListRules),
              repeat engine, natural-language date parser
  app/        Router, adaptive shell (sidebar / bottom-nav), providers
  features/   UI: lists, editor, project view, quick find/entry, shortcuts
  integrations/  Notifications, calendar mirror
  sync/       SyncService seam + Supabase implementation
supabase/     Remote schema migration (RLS per user, tombstones)
```

A single `tasks` table holds to-dos, projects, and headings (mirroring Things' own TMTask design). List membership is pure functions over `(startBucket, startDate, isEvening, deadline, status)` + today's date — see `domain/list_rules.dart`, exhaustively unit-tested.

## Running

```sh
flutter pub get
dart run build_runner build    # generate drift code
flutter run -d chrome          # Web (works out of the box)
flutter run -d macos           # macOS (requires Xcode)
flutter run -d windows         # Windows (requires VS C++ toolchain)
flutter run -d linux           # Linux (requires ninja + GTK headers)
flutter run                    # iOS / Android (Xcode / Android SDK)
```

Tests: `flutter test` (68 tests: list rules, repeaters, repositories, NL parser)

CI builds all six targets on every push (`.github/workflows/ci.yml`).

## Enabling sync

1. Create a [Supabase](https://supabase.com) project
2. Apply `supabase/migrations/0001_schema.sql` (SQL editor or `supabase db push`)
3. Build with your keys:

```sh
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJ…
```

Sign in from the sidebar footer. Sync is watermark-based push/pull with row-level last-writer-wins, realtime nudge for instant propagation, and tombstones for hard deletes. Without keys the app runs 100% local.

## Known gaps vs. Things 3

- Home-screen/lock-screen widgets (needs per-platform native widget code)
- Mail-to-Things email capture
- Global OS-level Quick Entry hotkey outside the app window
- Tag filtering UI (tags render on rows; the data layer supports filtering)
