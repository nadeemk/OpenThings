# OpenThings

A cross-platform clone of [Things 3](https://culturedcode.com/things/) built with Flutter — one codebase for **iOS, Android, macOS, Windows, Linux, and Web**. Local-first: every feature works fully offline; sync is additive.

## Architecture

```
lib/
  core/       Design tokens (Things-blue palette, typography, spacing), shared utils
  data/       drift (SQLite) schema + repositories — the source of truth
  domain/     Pure business logic: the three-date model, list-derivation
              rules, repeater engine, natural-language date parsing
  app/        App shell: router, adaptive navigation, DI providers
  features/   UI per feature (lists, editor, project view, quick find, ...)
  sync/       SyncService interface + Supabase/PowerSync implementation
```

### The data model

A single `tasks` table holds to-dos, projects, and headings (discriminated by `type`), mirroring Things' own TMTask design. Every schedulable item carries **three independent date concepts**:

1. **`startBucket` + `startDate` + `isEvening`** — the "When": inbox, anytime, someday, today, this evening, or a future date. Controls list membership.
2. **`deadline`** — independent of the start date; overdue deadlines surface in Today; deadlined items stay in Anytime.
3. **`reminderMinutes`** — clock time on the start date that fires a notification.

Built-in lists (Inbox, Today, Upcoming, Anytime, Someday, Logbook, Trash) are **derived queries** over this model, never stored state.

Repeaters support both Things modes: **fixed schedule** (every N days/weeks/months/years by calendar, next instance pre-generated) and **after completion** (next instance N units after check-off). A hidden template row spawns instances.

## Running

```sh
flutter pub get
dart run build_runner build   # generate drift code
flutter run -d chrome          # web
flutter run -d macos           # macOS (requires Xcode)
flutter run -d windows         # Windows (requires VS C++ toolchain)
flutter run -d linux           # Linux (requires GTK dev headers)
flutter run                    # iOS/Android (requires Xcode / Android SDK)
```

Tests: `flutter test`

CI builds all six targets on every push (see `.github/workflows/ci.yml`).
