# Handover — chukdoo redesign session (2026-09-07)

State of the working tree at the end of a long redesign session. Read this
plus `CLAUDE.md` before continuing.

## What the app is now

- **Free app.** No Pro tier, no paywall, no entitlement. Cloud sync is free.
  RevenueCat only sells one-off donations (`lib/features/donations/`).
- **One design system**, Material 3 Expressive:
  - `lib/core/theme/app_shapes.dart` — groupOuter 26, groupInner 6, groupGap 3,
    listInset 12, sheetTop 28, dockField 20, dockChip 16, dockMargin 8,
    navBarHeight 72.
  - `lib/core/theme/app_theme.dart` — every component theme (sheets, dialogs,
    date/time pickers, menus, chips, switches, buttons). Missing component
    themes were the reason pickers used to look unstyled; do not remove them.
  - `lib/shared/widgets/app_field.dart` — THE input surface. Filled block,
    optional label, never an outline. Use `AppField.decoration(hint)`.
  - `lib/shared/widgets/picker_sheet.dart` — THE modal surface.
    `showAppPicker` (a card that flies in: scale + fade, centred),
    `showPickerSheet` (option list), `showDateTimeSheet` (calendar + time).
  - `lib/shared/widgets/rounded_group.dart` — list section as one group.
  - `lib/shared/widgets/connected_group.dart` — segmented control
    (`ConnectedButtonGroup`), used by the calendar view switcher.
  - `lib/shared/widgets/bottom_nav_bar.dart` — floating glass pill, gliding
    highlight, collapses its labels while scrolling down.
  - `lib/shared/widgets/lifted_fab.dart` — lifts a page FAB clear of the bar.
- **Rule everywhere:** no `Border.all`, no `BorderSide`, no `Divider` as a
  separator. Separation is a filled block plus the 3px gap. Only the outer
  corners of a grid or group are strongly rounded.

## Known open bugs (the owner's list, unfinished)

1. **FAB position is still wrong** in at least one place. The shell uses
   `extendBody: true` + `bottomNavigationBar`, so Flutter adds the bar height
   to the body's bottom inset ONCE — do not inject it again (that caused a dead
   strip). Inner pages run their own Scaffold and place the FAB against the
   screen edge, hence `LiftedFab`. Its lift is
   `viewPadding.bottom + navBarHeight + 8`. Verify against a real screenshot,
   in every tab, before claiming it is fixed.
2. **Calendar view reported as "completely broken"** by the owner after the
   view-switcher change. The switcher now sits on its own full-width row
   (`ConnectedButtonGroup`); before that its segments were pushed off screen by
   a `reverse: true` horizontal scroll view. Needs a look on a device.
3. **Transparency**: the nav bar blur reads differently over the calendar than
   over the lists — the calendar page paints an opaque background.
4. Day/week grid: scrolling down "gets cramped" (owner). Not diagnosed.
5. Notes editor does not render Markdown (only the task description does).

## Server side

Run `supabase/apply_pending.sql` in the SQL editor (idempotent). It creates
`calendars`, `calendar_events` and `habits`; `notes` already exists.
`supabase/dump_schema.sql` prints the whole schema as one text cell —
use it before writing any migration.

Important: `todos` and `projects` are blob-only tables
(`id, user_id, encrypted_payload, updated_at`) and the app writes exactly those
four columns. Do not add status/is_completed columns; the rest lives encrypted
in the payload.

Synced: todos, projects, calendars, calendar events, habits, notes.
Not synced on purpose: ICS feed events (`user_id` starts with `feed:`).

## Things that were real bugs and are fixed

- Subscribed ICS feed events were filtered out of every view (they belong to no
  known calendar) — they never showed up at all.
- ICS import overwrote a whole series with its exception (same UID) and mangled
  umlauts.
- Event colour was silently dropped on save.
- Quick-add dock menus (project, priority) opened downwards behind the keyboard.
- Auth: the "instant auth" path never wired the Supabase listener, so the UI and
  the sync layer read two different truths; sessions are refreshed now.
- Notes had no sync at all.
- Event reminders were stored but never scheduled.

## Build

`material_design_icons_flutter` does not compile on Flutter 3.47 (IconData is
final now) and upstream is dead — a patched copy lives in `third_party/` and is
wired through `dependency_overrides`.

```bash
source .env.local
flutter build apk --target-platform android-arm64 --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Gradle needs a memory exception on this machine: prefix with
`memguard-allow 8G`.

## Open work items, in the owner's words

- The calendar's own "Inputbox" (event editor) is close but the owner still
  wants every control identical to the rest; check location, description,
  repeat, reminder once more on a device.
- Task row density: `CheckboxSize` is now small/medium/large driven by a slider
  in Settings (medium = default, tighter than before). Check it feels right.
- Drawer is a floating rounded panel from the left (like the quick-add dock).
- Sidebar-driven view changes are instant, only the bottom nav animates.
- Back gesture walks a view history in the shell, and a view-mode history in
  the calendar, before leaving the app.
- Calendar: full feature set is the goal (colours done; check recurrence,
  reminders, all-day, calendar assignment against a normal calendar app).

## Working rule learned the hard way

Do not claim a layout fix without looking at a screenshot from the device
(`adb exec-out screencap -p > shot.png`, then crop and inspect). Several
"fixed" claims in this session were wrong because the measurement was guessed.
