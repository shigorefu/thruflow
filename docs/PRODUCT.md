# Product

ThruFlow / スルフロ records focused work and turns it into visible task progress.

Core loop:

```text
Area -> Task -> Flow -> focused time -> progress -> statistics
```

User-facing English uses `Area` / `Areas`, and user-facing Russian uses
`Сфера` / `Сферы`. `Direction` remains the internal Swift model,
property, persistence, and machine-readable CSV identifier.

## 分野

`分野` is the Japanese UI label for the persistent `Direction` model. The same
entity is shown as `Area` in English and `Сфера` in Russian.

- `いつでも` / Anytime / В любое время: no automatic daily Task.
- `習慣` / Habit / Привычка: scheduled recurring requirement that creates Habit Tasks.
- `できたら` / Optional / Если получится: positive activity that does not block day completion.
- `その他` / Other / Другое: system Area for Tasks and Flow without a chosen Area. Its internal role remains a `Direction`; it is hidden only from Area management, not from Statistics.

## Tasks

Tasks are the daily Todo surface.

Task title may be empty. When empty, UI displays `(分野)`, for example `(読書)` or `(その他)`.

The screen is named `タスク`. There is no separate Inbox navigation item. When today is selected, overdue active normal Tasks appear in a leading `やり残し` section. A toolbar `日付なし` button with a count opens an inspector for active normal Tasks without a date. Habit instances are excluded from both projections because their schedule is owned by the Habit planner.

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
Task title, Area, emoji, and hashtag without changing stored records or
Habit materialization. macOS exposes the same database-wide search semantics
through its native toolbar search field.

Weekly-count Habits create one pending Task at a time. Completion allows the next instance on a later day, while moving the pending Task never creates a duplicate or makes the weekly goal impossible.

Task completion:

- `チェック`: user checks it.
- `集中ブロック`: accumulated focused time reaches planned Blocks.
- `分`: accumulated focused minutes reaches planned minutes.

## 流れ

Flow is a media-player-like recorder.

`流れ` is the first/default navigation section and today's primary dashboard. In wide layout, one grid aligns the stream/timeline above Tasks on the left and the square player above Statistics on the right. The left column occupies roughly three quarters of the content. Area colors compose the stream palette, while focus duration and session count control its visual volume.

The stream is a field of broad, bright, softly glowing translucent ribbons rendered on the GPU around one shared S-shaped channel with three levels of depth. Its phase motion is tuned 25 percent faster than the original profile while keeping the same 30/60 FPS render budget. A subtle internal current makes that phase motion legible while idle, and the stream immediately accelerates when Flow starts. Its occupied area stops growing at 4 Blocks so depth, transparency, and motion preserve the silhouette without black carved stripes; progress through 6 Blocks instead adds internal detail, parallax, saturation, and motion. A restrained light pulse crosses the stream at each completed half-Block. Every valid `休憩` press sends a short reverse release wave without implying that rest has started. After note confirmation, a regular rest exhales softly; a confirmed `長休憩` opens all seven ribbons into a brighter fan and then keeps a calm breathing form for the rest of the break. These effects are transient presentation state and never change or persist timer data. `短め`, `標準`, and `じっくり` change the wave character, while a subtle mode-specific tint is applied to the dashboard. Below it, today's Anytime Tasks and Habits remain actionable with the same Check, Block, and Minute indicators as Tasks; the Optional `できたら` group appears only when present. On iPhone and iPad, one dashboard Task card switches between `タスク / 習慣 / できたら`; its header offers quick Task capture next to the Tasks deep link. Compact width uses the bottom composer and regular width anchors it as a popover to `+`. The fixed-height compact Statistics panel forms the same three-page carousel on macOS and iPhone for Task/Area time distribution, a seven-day Flow trend with day-over-day deltas, and today's completion status.

The Flow player uses the same `タスク / 習慣 / 分野` context choice on macOS,
iPhone, and iPad. The touch presentation uses native segmented tabs and lists,
while Area-only selection keeps `その他` first. On iPhone and iPad,
tapping a segment or completed rest in today's dashboard timeline first opens a
compact popover above that exact position. Completed records can continue to the
canonical History detail/editor; a running Flow remains read-only and an active
rest remains non-interactive.

The `集中モード` / Flow Mode choices are:

- `短め` / Short / Короткий: 12 focus / 3 break = 0.5 Block.
- `標準` / Standard / Обычный: 25 focus / 5 break = 1 Block.
- `じっくり` / Deep / Глубокий: 50 focus / 10 break = 2 Blocks.

The internal adaptive mode is labeled `自動` / Auto / Авто whenever it appears
in saved data.

Focus does not auto-stop or auto-switch to break. Break starts only after the user confirms a note. The dashboard and menu bar use the same square note panel with two stable actions: cancel on the left and a checkmark submit action on the right. The submit label is `メモなしで送信` while the editor is empty and `送信` after text is entered. Each submitted note is stored in `FlowSession.result`; a linked Flow also mirrors the text to `Todo.notes`. Submitting without a note preserves an existing Task note, and rest completion never prompts again. The rest timer ring is neutral gray and drains while the focus ring fills with the selected Area color.

Flow sessions may share a stable series ID when the next session starts within 1.5 times the planned rest. The next rest after each 4 accumulated Blocks is a 20-minute `長休憩` with a 30-minute continuation window. History preserves separate Flow and rest records; only the dashboard renders their series as one continuous rail.

The active creditable Flow updates the dashboard live. Completed timeline
segments open the existing platform History detail/editor.

Flow may start with a Task, only an Area, or neither. Area-only work is persisted
through its internal `Direction` relationship without an implicit Todo; work
without either resolves to system `その他`. Version 1.0 never creates a Task
implicitly from Flow.

## Statistics

The standalone macOS Statistics workspace is a card-based period report. Its
toolbar provides an Area filter, Task/Area search, and a direct Share
action for configurable CSV export.
The persistent calendar column on the right centers the `週・月・年` control and
places an icon-only `期間を指定` action at the trailing edge. It opens an exact
inclusive start/end date picker; navigation moves either the anchored preset or
the whole custom range.

The report contains combined summary cards, a period trend with comparison to
the previous equivalent period, a focused-time distribution by Task or Area,
and a `集中カレンダー` / Focus Calendar view. Trend and the focus calendar
each provide an independent `集中 | タスク` switch. Week trends use days, Month trends use seven-day totals,
and Year trends use months; current and previous values are separate direct
linear series. Week and
Year use full-width focus calendars, while Month may share a row with Pie. Responsive focus calendars
fit inside the card without horizontal scrolling. The preset Month stretches
its seven columns across the available card width. A custom range of up to seven days uses the
stretched Week row; every longer custom range uses small cells, adding
calendar cells through the selected end date before switching to compact week
columns. Hovering a real day cell shows a system bubble above all card content
with its date, focus time, `集中回数`, and completed Task count. The summary always
presents both recorded focus and completed Tasks. Search is segment-aware, so
matching one Task within a switched Flow credits only that Task's persisted
interval. The export popover independently chooses `すべて | 集中記録 | タスク`,
exact inclusive start/end dates, Area, and text filter. A
Pie sector can be selected to dim the other sectors and isolate its value and
legend row. The Statistics Area filter uses the same symbol as
the main navigation. The current Week, Month, Year, and custom ranges stop at
today; future calendar dates and forward navigation are unavailable. The Year focus calendar
is display-only because its cells are too small for reliable inspection.

The iPhone Statistics workspace uses the same period report as macOS: anchored
Week, Month, Year, or an exact custom date range; Summary, Trend, focused-time
Pie, and `集中カレンダー` / Focus Calendar cards; Area and text filters; and
`すべて | 集中記録 | タスク` CSV export. Its presentation is touch-native: cards form one vertical
scroll, period/calendar controls and export use system sheets, and tapping a
Week or Month focus-calendar day opens a compact detail sheet before navigating to
History. The Year focus calendar remains a non-interactive full-width overview. Search starts
as a magnifying-glass toolbar action, and every iPhone navigation title uses the
same centered inline presentation. The `集中カレンダー` widgets keep their
separate compact 30/60/90-day snapshots.

## History

`履歴` is the primary History surface and a dedicated navigation item below `タスク`. Clicking a statistics cell switches navigation to this section on that date; Statistics does not embed another history view. Its toolbar filter follows the active tab: calendar visibility for `集中記録`, `タスク / 習慣 / できたら` for Task summaries, and `いつでも / 習慣 / できたら` for Area summaries. In the day range, the right calendar column also shows `この日の記録`.

Completed breaks are edited with synchronized end-time and minute-duration controls. The start remains fixed; extending a break shifts only later records in the same Flow series when they overlap.

It provides a primary `集中記録` calendar mode with `日・週・月`, plus `タスク` and `分野` aggregates. Day directly presents the selected day's actual Flow and rest records as one vertically ordered timeline; long internal gaps are labeled as having no records with deliberate vertical spacing, while short records retain a full-size interactive card. Selecting a Day record opens its canonical editor in a separate system sheet. Week uses a vertically scrolling seven-column hour grid and projects each connected Flow series as one composite block. Opening that block shows the same vertical record timeline in a separate sheet, where every underlying Flow or rest remains independently editable and Back returns to the series timeline. The Flow editor reuses the player's Task, Habit, and Area picker, including inline Task creation, so Area is derived from the selected item rather than edited in a second control. Rest editing uses a compact, content-fitted sheet. On iPhone, Month is one vertical surface: the month calendar scrolls directly into `この日の記録`, which reuses the complete Day timeline for the selected date; scrolling back restores the calendar. These are UI projections only: the persisted Flow and rest records remain separate. Completed Flow records can be moved between exact day/time positions where the calendar editor supports it; the session and all task-switch segments preserve their duration and progress. Active Flow and rest records remain fixed. Todo completion remains in Task summaries and Statistics. Manual History creation creates an independent Flow, never a manual rest. Historical Flow changes must adjust Area totals and measured Todo progress by the same delta. Linking a manual Flow to a Task does not automatically complete it.

On iPhone, `日`, `週`, and `月` consume the same chronology, connected-series,
gap, and aggregate projections as macOS. Day is the complete vertical
Flow/rest timeline, Week is the seven-column elastic series grid, and Month
places the selected day's complete timeline directly below the calendar in the
same scroll surface. iOS keeps touch-native period navigation and system sheets
instead of compiling the desktop views. Search is an icon-only system toolbar
action that expands on demand. While native search is active, results come from the complete History database
instead of the selected period. Matching uses record title, Area, emoji,
hashtag, intent, or memo in `集中記録`, `タスク`, and `分野` modes. macOS provides
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

Version 1.0.2 introduces an eight-step onboarding journey: `ようこそ`, `分野`,
`タスク`, `流れ`, `集中のプレビュー`, `履歴`, `統計`, and `使い方の流れ`.
An empty first installation uses guided mode. It opens the real Area editor and
Task composer with localized starter values, but saves only an Area or Task that
the user explicitly confirms. The Flow preview rapidly time-compresses a
canonical Short focus interval into its regular break while rendering the real
Flow stream. Its timer, phase, and progress are presentation-only: it creates no
`FlowSession`, segment, break, Task progress, History, Statistics, notification,
Live Activity, or CloudKit record. The final step summarizes
`分野 → タスク → 流れ → 履歴・統計 → 次の一歩`.

If first launch already contains user data, onboarding becomes a read-only tour
and creates nothing. `設定 > ヘルプ > 使い方を見る` closes the Settings
presentation before replaying the same read-only journey from the beginning.
Every step can be skipped. Preview schemes isolate guided actions in an
in-memory store, and watchOS remains a companion without a second onboarding.

On macOS, a gear at the bottom of the sidebar opens the same native Settings
window. The `データ` section on macOS, iPhone, and iPad can delete every Flow and
break record after an irreversible-action confirmation. Deletion is unavailable
while a Flow is active, runs away from the main UI, and synchronizes through the
private CloudKit store. Tasks, Areas, Task notes, and manually checked Task state
remain; measured Task and Area progress is reset to zero.

Settings also contains voluntary support actions: App Store review, the public
GitHub project, and two StoreKit consumable tips (`Coffee`, JPY 100, and
`Ramen`, JPY 500). Tips unlock no feature and are not subscriptions. The app
keeps its core productivity features—Tasks, the Flow focus timer, History, and
Statistics—free and ad-free, with no payment required. This promise does not set
terms or prices for possible future optional integrations or services. The app
does not send a promotional notification after one week. Instead, after at
least seven days and either five active Flow days or ten completed Flows, it may
ask for a review at a natural post-Flow moment, at most once per app version.
The system ultimately decides whether the review sheet is shown.

A separate `フィードバック` section opens the repository's public issue-template
chooser and warns the user to remove private Task names and notes. It also
explains that TestFlight testers can submit a screenshot or use the TestFlight
app to include device context. ThruFlow does not operate a separate feedback
backend.

## Apple Watch

The watchOS companion provides a compact four-page vertical Flow dashboard:

- `タイマー` is the first page and contains the complete Watch Flow player,
  with the mode selector above, timer ring on the left, and transport controls
  on the right;
- `流れ` presents the animated stream fullscreen without a timeline; one tap
  hides or restores all informational overlays;
- `タスク` presents today's Tasks and Habits and can create a Task through a
  compact picker-based form that never opens a keyboard;
- `統計` presents a summary of today's completion, focused time, Blocks, and
  `集中回数`.

The user moves between pages with the system vertical page gesture or Digital
Crown. Each page occupies the display instead of acting as a navigation card.

The Watch does not own a second timer or separate progress model. It restores
the canonical active `FlowSession` from the shared SwiftData/CloudKit store and
controls the same `ActiveFlowStore` operations as iPhone and macOS. Task Check
completion is interactive; Block and Minute progress remains Flow-derived.
