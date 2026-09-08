# Handover — chukdoo (2026-09-08)

Read this plus `CLAUDE.md` before continuing. It records what the app is made
of and which rules exist, not a change log — `git log` has that.

## The design system: use it, never rebuild it

Every one of these exists because the same thing had been hand-built three
times with three different results. Adding a fourth variant is the bug.

| Widget | What it is |
|---|---|
| `lib/shared/widgets/app_scaffold.dart` | THE page frame. `AppScaffold` gives the title row, an optional `headerBottom`, the body and a lifted FAB. `AppPageHeader`/`AppHeaderAction` are its parts. No page builds its own `Scaffold`+`AppBar`. |
| `lib/shared/widgets/app_drawer_panel.dart` | THE side panel. `AppDrawerPanel` + `AppDrawerSection` + `AppDrawerTile` + `AppDrawerActionTile`. Every section's drawer is built from these. |
| `lib/shared/widgets/entity_edit_sheet.dart` | THE form for anything with a name, a colour and maybe an icon: project, calendar, ICS feed, note folder, habit. `EntityFlushGrid` lays out swatches and icons so a full row ends flush right. |
| `lib/shared/widgets/picker_sheet.dart` | THE modals. `showAppPicker` (card that flies in), `showPickerSheet` (option list), `showDateTimeSheet`. No bare `AlertDialog`, no bare `showModalBottomSheet`. |
| `lib/shared/widgets/app_field.dart` | THE input. Filled block, never an outline. |
| `lib/shared/widgets/app_check.dart` | THE tick. Task rows, habit days, calendar visibility. |
| `lib/shared/widgets/connected_group.dart` | THE segmented control. The SELECTED segment is strongly rounded on both sides; its neighbours stay nearly square. |
| `lib/shared/widgets/rounded_group.dart` | A list section as one group. |
| `lib/core/theme/app_shapes.dart` | Radii, gaps, and `AppShapes.contentBottom(context)`. |

### Hard rules

- **No `Border.all`, no `BorderSide`, no `Divider` as a separator.** Separation
  is a filled block plus the 3px gap. The one sanctioned exception is the
  selection ring around a colour swatch or an icon tile.
- **Colours only from `AppColors`**, radii only from `AppShapes`.
- **`AppShapes.contentBottom(context)` is the bottom padding of every
  scrollable.** It reads the gesture inset from the *view*, not from
  `MediaQuery`: inside a page the `Scaffold` has already eaten that inset and
  `MediaQuery.viewPaddingOf` answers 0, which silently made every padding one
  gesture bar too short.
- **A page paints no background.** The shell's background is what the floating
  nav bar blurs; a page that paints its own turns the glass into a grey slab.
- The shell (`features/todos/presentation/pages/home_page.dart`) picks the side
  panel of the current tab. Settings has none, so its page shows no hamburger.

## Sections

- **Tasks** — list, quick-add dock, projects. Swiping a row left crosses
  release-driven zones (Delete, Pin, Date, Move) with a haptic tick per zone;
  the action runs on release, a full swipe opens the menu instead of deleting.
  `swipe_zone_row.dart` owns that; `flutter_slidable` is gone from the tile
  (the dependency and the leftover `SlidableAutoCloseBehavior` wrappers can be
  removed).
- **Calendar** — day, three days, week, month, agenda. Periods are pages
  (`period_pager.dart`) with a guard between page index and focused date.
  `DayWindow.covering` widens the drawn day window until every item fits, so a
  06:00 item shows under an 08:00 setting. Blocks are placed by the minute;
  only creating and dragging snap to a quarter hour. Two fingers zoom the hour
  height (28–140, persisted); in the month view they scale the week row
  height (72–220, or "fit to screen"). Both go through `PinchScaler`, which
  reads raw pointers — a scale recognizer would steal the page swipe. The
  month strip is a connected bar, years are quiet markers.
- **Notes** — folders, markdown. The editor is one writing surface with
  autosave (600ms, on pop, on background) and a format bar over the keyboard;
  preview checkboxes write back into the source.
- **Habits** — daily/weekly filter from its panel, ticks from `AppCheck`.
- **Settings** — a hub with a sub-page per section (tasks, calendar, notes,
  habits). Everything is stored in the Hive settings box; the calendar and the
  notes read their settings.

## Gestures: what a screenshot cannot show

Two bugs in this session were invisible in pictures and cost hours:

- A `GestureDetector` inside a horizontal list loses the gesture arena to the
  scroll view as soon as the finger travels a pixel, so the month strip looked
  right and never reacted to a real finger. It reads the raw pointer now
  (`_TapTolerant` in `month_strip.dart`).
- A `ScaleGestureRecognizer` enters the arena with a single pointer and would
  steal the page swipe, so the pinch zoom listens to raw pointers too and only
  starts on the second finger.

**Test interaction with widget tests, not screenshots.** Screenshots are for
layout, and only from the device (`adb exec-out screencap -p > shot.png`).
`_scratch/walkthrough.sh` walks every screen and drops a picture per step; it
restarts the app between sections because one stuck sheet used to swallow all
following taps and the rest of the run photographed the wrong screen.

## Home screen widgets (Android)

Four separate widgets, each its own provider, layout, `appwidget-provider`
XML and picker entry: **Tasks**, **Calendar**, **Notes**, **Habits**. The code
lives in `android/app/src/main/kotlin/doo/chuk/dev/widgets/`; every provider
extends `ChukdooWidgetProvider` (header, list, empty state) and every list is
drawn by one `WidgetListFactory` parameterised by `WidgetKind`.

- **Data goes out through SharedPreferences, not through a channel.** A widget
  is redrawn by the launcher at times when no Flutter engine exists — after a
  reboot, for instance — so `lib/features/widget/widget_service.dart` writes one
  JSON blob per widget into `FlutterSharedPreferences` and the widgets read it
  there. `WidgetService.startWatching()` (called once in `main.dart`) watches the
  Hive boxes, so a sync pull refreshes the widgets exactly like a swipe does.
  Do not add per-notifier `updateWidget()` calls; the box watcher already sees
  every write.
- **Ticks come back as a pending queue.** A widget cannot write to Hive. A tick
  writes `widget_pending_tasks` / `widget_pending_habits` and updates the stored
  blob optimistically, so the row looks right at once; `processPending()` applies
  it for real on the next start or resume (`AutoSyncManager`). Nothing is lost,
  but nothing reaches Supabase until the app is opened again.
- **Every tap goes through `WidgetActionActivity`.** A row has to be able to
  tick *and* to open, and a collection carries exactly one PendingIntent
  template — so the template is an activity PendingIntent and the branch happens
  in that invisible activity. It must not become a broadcast: a receiver may not
  start an activity from the background, which is what a widget tap is.
- **Previews are real.** Each widget ships `previewLayout` (a static twin of the
  layout with sample rows) for API 31+ and a hand-built vector `previewImage` as
  the fallback. Never point one at `@mipmap/ic_launcher` again.
- The old single `ChukdooWidget` is gone. Widgets placed by an earlier build
  disappear from the home screen and have to be added again.

## Server side

Run `supabase/apply_pending.sql` in the SQL editor (idempotent). It creates
`calendars`, `calendar_events`, `habits` and `note_folders`; `notes` already
exists. `supabase/dump_schema.sql` prints the whole schema in one cell.

`todos` and `projects` are blob-only (`id, user_id, encrypted_payload,
updated_at`) — do not add columns, the rest lives in the encrypted payload.
That is also where a task's `end_time` and a note's `folderId` ride.

Synced: todos, projects, calendars, calendar events, habits, notes, note
folders. Subscribed ICS feeds stay on the device (`user_id` starts with
`feed:`), and so does their visibility.

## Build

`material_design_icons_flutter` does not compile on Flutter 3.47 (IconData is
final now) and upstream is dead — a patched copy lives in `third_party/` and is
wired through `dependency_overrides`.

```bash
source .env.local
memguard-allow 8G flutter build apk --target-platform android-arm64 \
  --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Kill the Gradle daemon when a build is done; it holds ~2GB and this machine
runs out.

## Open

- The quick-add dock cannot set a task's end time yet; only the detail page can.
- No "all day" switch in the event card — that still needs the full editor.
- Calendar metrics were set from Google Calendar's published sizing, not
  measured: Google Calendar lives on a second Android user on the test phone
  and the shell cannot reach it.
- `auto_sync_manager` refreshes every provider after a pull now, but a pull
  still never runs while the app is in the foreground without connectivity
  changes.
