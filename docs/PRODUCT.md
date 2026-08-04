# Product

ThruFlow / スルフロ records focused work and turns it into visible task progress.

Core loop:

```text
方向 -> Task -> Flow -> focused time -> progress -> statistics
```

## 方向

`方向` is a persistent area of activity.

- `通常`: normal area. No automatic daily task.
- `習慣`: scheduled recurring requirement. Creates automatic habit tasks.
- `ナイス`: optional positive activity. Does not block day completion.
- `その他`: system Direction for tasks/flows without a chosen Direction. It is hidden only from Direction management, not from statistics.

## Tasks

Tasks are the daily Todo surface.

Task title may be empty. When empty, UI displays `(方向)`, for example `(読書)` or `(その他)`.

The screen is named `タスク`. There is no separate Inbox navigation item. When today is selected, overdue active normal Tasks appear in a leading `期限切れ` section. A toolbar `日付なし` button with a count opens an inspector for active normal Tasks without a date. Habit instances are excluded from both projections because their schedule is owned by the Habit planner.

`タスク` supports `日`, `週`, and `月` calendar ranges. Day uses a compact seven-day strip above the Task list and opens a full month only in a date-picker popover. Week is a seven-column kanban, while month is a calendar overview. Filters stay centered and `今日` remains prominent. Active Tasks can be moved between dates subject to Habit rules.

On iPhone, the compact day and week period strips scroll horizontally with
native view-aligned snapping. Day advances one date card at a time and week
advances one complete seven-day card at a time. A direct tap selects a card
immediately; a drag commits the selected period only after the finger is
released and native snapping becomes idle. The Task list below keeps independent
vertical scrolling, and a horizontal swipe across its content card animates to
the previous or next day/week only after release. While native search is active,
the calendar workspace is replaced by results from the complete Task database,
grouped by scheduled date with a separate `日付なし` section. Matching uses
Task title, Direction, emoji, and hashtag without changing stored records or
Habit materialization. macOS exposes the same database-wide search semantics
through its native toolbar search field.

Weekly-count Habits create one pending Task at a time. Completion allows the next instance on a later day, while moving the pending Task never creates a duplicate or makes the weekly goal impossible.

Task completion:

- `チェック`: user checks it.
- `集中ブロック`: accumulated focused time reaches planned Blocks.
- `分`: accumulated focused minutes reaches planned minutes.

## Flow

Flow is a media-player-like recorder.

`Flow` is the first/default navigation section and today's primary dashboard. In wide layout, one grid aligns the stream/timeline above Tasks on the left and the square player above Statistics on the right. The left column occupies roughly three quarters of the content. Direction colors compose the stream palette, while focus duration and session count control its visual volume.

The stream is a field of broad, bright, softly glowing translucent ribbons rendered on the GPU around one shared S-shaped channel with three levels of depth. It remains smooth while idle and immediately accelerates when Flow starts. Its occupied area stops growing at 4 Blocks so depth, transparency, and motion preserve the silhouette without black carved stripes; progress through 6 Blocks instead adds internal detail, parallax, saturation, and motion. A restrained light pulse crosses the stream at each completed half-Block. Sprint, Focus, and Deep change the wave character, while a subtle mode-specific tint is applied to the dashboard. Below it, today's normal Tasks and Habits remain actionable with the same Check, Block, and Minute indicators as Tasks; Nice appears only when present. The dashboard Task card switches between `すべて / タスク / 習慣 / ナイス`. Fixed-height compact Statistics form the same three-page carousel on macOS and iPhone for Task/Direction time distribution, a seven-day Flow trend with day-over-day deltas, and today's completion status.

Modes:

- `Sprint`: 12 focus / 3 break = 0.5 Block.
- `Focus`: 25 focus / 5 break = 1 Block.
- `Deep`: 50 focus / 10 break = 2 Blocks.

Focus does not auto-stop or auto-switch to break. Break starts only after the user confirms memo. The dashboard and menu bar use the same square memo panel with two stable actions: cancel on the left and a checkmark submit action on the right. The submit label is `メモなしで送信` while the editor is empty and `送信` after text is entered. Memo is stored on Todo, not FlowSession, and rest completion never prompts again. The rest timer ring is neutral gray and drains while the focus ring fills with the selected Direction color.

Flow sessions may share a stable series ID when the next session starts within 1.5 times the planned rest. The next rest after each 4 accumulated Blocks is a 20-minute Long Break with a 30-minute continuation window. History preserves separate Flow and rest records; only the dashboard renders their series as one continuous rail.

The active creditable Flow updates the dashboard live. Completed timeline segments open the existing historical Flow inspector.

Flow may start with a Task, only a Direction, or neither. Direction-only work is persisted without an implicit Todo; work without either resolves to system `その他`. Automatic Task creation is deferred until its measurement and planned amount have explicit defaults.

## Statistics

The standalone macOS Statistics workspace is a card-based period report. Its
toolbar provides Direction filter, Task/Direction search, and a direct Share
action for configurable CSV export.
The persistent calendar column on the right centers the `週・月・年` control and
places an icon-only `期間を指定` action at the trailing edge. It opens an exact
inclusive start/end date picker; navigation moves either the anchored preset or
the whole custom range.

The report contains combined summary cards, a period trend with comparison to
the previous equivalent period, a focused-time distribution by Task or
Direction, and contribution Dots. Trend and Dots each provide an independent
`Flow | タスク` switch. Week trends use days, Month trends use seven-day totals,
and Year trends use months; current and previous values are separate direct
linear series. Week and
Year use full-width Dots, while Month may share a row with Pie. Responsive Dots
fit inside the card without horizontal scrolling. The preset Month stretches
its seven columns across the available card width. A custom range of up to seven days uses the
stretched Week row; every longer custom range uses small cells, adding
calendar cells through the selected end date before switching to compact week
columns. Hovering a real day cell shows a system bubble above all card content
with its date, focus time, Flow count, and completed Task count. The summary always
presents both recorded focus and completed Tasks. Search is segment-aware, so
matching one Task within a switched Flow credits only that Task's persisted
interval. The export popover independently chooses combined, Flow-only, or
Task-only CSV, exact inclusive start/end dates, Direction, and text filter. A
Pie sector can be selected to dim the other sectors and isolate its value and
legend row. The Statistics Direction filter uses the same Direction symbol as
the main navigation. The current Week, Month, Year, and custom ranges stop at
today; future calendar dates and forward navigation are unavailable. Year Dots
are display-only because their cells are too small for reliable inspection.

The iPhone Statistics workspace uses the same period report as macOS: anchored
Week, Month, Year, or an exact custom date range; Summary, Trend, focused-time
Pie, and Dots cards; Direction and text filters; and combined, Flow-only, or
Task-only CSV export. Its presentation is touch-native: cards form one vertical
scroll, period/calendar controls and export use system sheets, and tapping a
Week or Month Dots day opens a compact detail sheet before navigating to
History. Year Dots remain a non-interactive full-width overview. Search starts
as a magnifying-glass toolbar action, and every iPhone navigation title uses the
same centered inline presentation. The Flow
Dots widgets keep their separate compact 30/60/90-day snapshots.

## History

`履歴` is the single canonical History surface and a dedicated navigation item below `タスク`. Clicking a statistics cell switches navigation to this section on that date; Statistics does not embed another history view. Its toolbar filter follows the active tab: calendar visibility for `Flow`, `タスク / 習慣 / ナイス` for Task summaries, and `通常 / 習慣 / ナイス` for Direction summaries. In the day range, the right calendar column also shows `この日の記録`.

Completed breaks are edited with synchronized end-time and minute-duration controls. The start remains fixed; extending a break shifts only later records in the same Flow series when they overlap.

It provides a primary `Flow` calendar mode with `日・週・月`, plus `タスク` and `方向` aggregates. Day directly presents the selected day's actual Flow and rest records as one vertically ordered timeline; long internal gaps are labeled as having no records with deliberate vertical spacing, while short records retain a full-size interactive card. Selecting a Day record opens its canonical editor in a separate system sheet. Week uses a vertically scrolling seven-column hour grid and projects each connected Flow series as one composite block. Opening that block shows the same vertical record timeline in a separate sheet, where every underlying Flow or rest remains independently editable and Back returns to the series timeline. The Flow editor reuses the player's Task, Habit, and Direction picker, including inline Task creation, so Direction is derived from the selected item rather than edited in a second control. Rest editing uses a compact, content-fitted sheet. On iPhone, Month is one vertical surface: the month calendar scrolls directly into `この日の記録`, which reuses the complete Day timeline for the selected date; scrolling back restores the calendar. These are UI projections only: the persisted Flow and rest records remain separate. Completed Flow records can be moved between exact day/time positions where the calendar editor supports it; the session and all task-switch segments preserve their duration and progress. Active Flow and rest records remain fixed. Todo completion remains in Task summaries and Statistics. Manual History creation creates an independent Flow, never a manual rest. Historical Flow changes must adjust Direction totals and measured Todo progress by the same delta. Linking a manual Flow to a Task does not automatically complete it.

On iPhone, `日`, `週`, and `月` consume the same chronology, connected-series,
gap, and aggregate projections as macOS. Day is the complete vertical
Flow/rest timeline, Week is the seven-column elastic series grid, and Month
places the selected day's complete timeline directly below the calendar in the
same scroll surface. iOS keeps touch-native period navigation and system sheets
instead of compiling the desktop views. Search is an icon-only system toolbar
action that expands on demand. While native search is active, results come from the complete History database
instead of the selected period. Matching uses record title, Direction, emoji,
hashtag, intent, or memo in `Flow`, `タスク`, and `方向` modes. macOS provides
the same database-wide filtering through its native toolbar search field.

## Settings

The native Settings surfaces group appearance, language, calendar, clock, and
Task preferences into separate categories. They store appearance, application
language, first weekday, 12/24-hour clock, Task quick-input legend visibility,
and the configurable start hour of an app day locally. The default boundary is
`00:00`. Choosing `02:00`, for example, keeps
Tasks, generated Habits, Flow summaries, Statistics, History, and widgets on the
previous logical day until 02:00. Stored Task dates remain calendar dates; the
setting changes day assignment and does not migrate SwiftData records.
Appearance and regional calendar/clock preferences apply immediately to every
app scene.
Language follows the shared String Catalog and takes effect after relaunch;
available languages are discovered from the bundle so contributors can add a
locale without changing Settings code.

## Apple Watch

The watchOS companion provides a compact four-page vertical Flow dashboard:

- `タイマー` is the first page and contains the complete Watch Flow player,
  with the mode selector above, timer ring on the left, and transport controls
  on the right;
- `Flow` presents the animated stream fullscreen without a timeline; one tap
  hides or restores all informational overlays;
- `タスク` presents today's Tasks and Habits and can create a Task through a
  compact picker-based form that never opens a keyboard;
- `統計` presents today's completion, focus, Block, and Flow summary.

The user moves between pages with the system vertical page gesture or Digital
Crown. Each page occupies the display instead of acting as a navigation card.

The Watch does not own a second timer or separate progress model. It restores
the canonical active `FlowSession` from the shared SwiftData/CloudKit store and
controls the same `ActiveFlowStore` operations as iPhone and macOS. Task Check
completion is interactive; Block and Minute progress remains Flow-derived.
