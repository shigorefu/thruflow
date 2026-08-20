# Decisions

## D-001: Product Documentation Is Split By Responsibility

`docs/PRODUCT.md` defines the product overview, while the domain, data,
architecture, UX, localization, release, and roadmap documents own their
respective details. This decision log records accepted changes and explicitly
marks superseded behavior.

Reason: focused documents are easier to keep current and review than a second,
monolithic product specification that duplicates them.

## D-002: Area Types

Current visible Area types are:

- `いつでも` / Anytime / Обычное;
- `習慣` / Habit / Привычка;
- `できたら` / Optional / Если получится.

The persisted `DirectionType` raw values remain `neutral`, `habit`, and `nice`.

Reason: the visible names describe when work belongs on the daily surface,
while stable internal identifiers preserve existing data.

## D-003: System Area

Tasks and Flow without a user-selected Area are assigned to the system Area
`その他` / Other / Другое. Internally, it remains a `Direction` relationship.

`その他` is hidden only from Area management to prevent editing. It may appear
in Task context and Statistics.

Reason: the app needs a stable Area relationship without forcing the user to
choose one every time.

## D-004: Empty Todo Title Is Valid

Todo title may be empty. UI displays `(Area name)` when title is empty.

Reason: generated Habit tasks should start as lightweight templates, and the same display rule remains available if automatic Flow Task creation is defined later.

## D-005: Backlog Lives Inside Tasks

There is no separate Inbox navigation item. Overdue normal Tasks appear in Today, while active normal Tasks with no date are available through a counted `日付なし` inspector in `タスク`. Habit instances are excluded because their dates are owned by Habit scheduling rules.

Reason: calendar planning should expose work that needs attention without adding another primary destination or mixing automatically generated Habit history into a manual backlog.

## D-006: FlowSession Owns The Per-Flow Memo

Each submitted Flow memo is stored in `FlowSession.result`. When the Flow is
linked to a Task, the same non-empty text is mirrored to `Todo.notes` for
Task-level continuity. Submitting without text never clears an existing Task
memo.

Reason: History must preserve what happened in each individual Flow, while the
linked Task still benefits from the latest useful working note.

## D-007: Block Display Uses Half-Block Credits

Exact focused seconds are preserved. Block display converts accumulated task focus into half-block credits:

- 12 minutes -> 0.5 Block;
- 24 minutes -> 1 Block;
- 25 minutes -> 1 Block.

Reason: short Flow sessions on the same task should combine into useful Block progress.

## D-008: Flow Does Not Auto-Switch

When planned focus time ends, the timer continues. Break starts only after user action and memo confirmation.

Reason: ThruFlow records actual work rhythm rather than forcing automatic Pomodoro transitions.

## D-009: Statistics Ranges

Status: superseded by D-025, D-030, and D-031. Retained only as historical
context for the original Statistics scope.

Statistics ranges are:

- current month;
- last 180 days;
- current calendar year.

Reason: these matched the original Statistics scope and kept GitHub-like statistics understandable.

## D-010: Weekly Habits Are Sequential

A weekly-count Habit creates one pending Task at a time. Moving it does not create a duplicate, and a move is blocked when the remaining eligible days cannot satisfy the weekly target.

Reason: the daily surface stays focused while the weekly commitment remains achievable.

## D-011: Tasks Use A Calendar Kanban

The `タスク` screen combines `日`, `週`, and `月` ranges. Week replaces the overlapping 3-day/7-day concepts with one predictable seven-column board. Habit instances remain on the same calendar as normal Tasks and can be isolated with a filter instead of a separate navigation destination.

Reason: users plan work by date and should not need to check separate screens for Tasks and Habits.

## D-012: Calendar Moves Preserve Habit Rules

Drag-and-drop in day, week, and month changes `scheduledDate` only for active normal Tasks and feasible weekly-count Habit Tasks. Completed Tasks and fixed-schedule Habit instances remain on their original date.

Reason: calendar planning must not silently invalidate historical completion or recurring commitments.

## D-013: Flow Is The Daily Dashboard

`Flow` is the first/default app section. Its wide dashboard gives roughly three quarters of the content to the animated stream and timeline, with a separate circular player panel on the right and today's Task/Habit/optional `できたら` sections plus compact Statistics below. It reuses the existing player behavior and derives all visual data from Todo and FlowSession records. A system Metal shader provides the broad, smooth visual layer without adding a persistence model or third-party rendering dependency; visual growth is capped at 6 Blocks and controlled by the testable `FlowVisualState` projection.

Reason: starting focused work and seeing its accumulated shape should be the primary app experience, while Tasks, History, Areas, and Statistics remain dedicated supporting surfaces.

## D-014: Day History Uses A Direct Record Timeline

The `日` History range directly renders every actual Flow and rest record for the selected app day as a chronological vertical timeline. Cards have a stable interactive size independent of recorded duration, and internal gaps of at least one hour are represented by a quiet, vertically spacious `記録なし` row. There is no `Elastic | 24時間` choice in this view. Selecting a record opens its canonical editor in a separate system sheet so the Day timeline remains stable. A right pane retains only the wide-layout date mini-calendar; record properties are not duplicated below it. Inside a Week series sheet, record editing remains an animated push transition with a leading Back control, and the sheet animates between the timeline, Flow editor, and compact rest editor sizes.

Reason: day history needs enough vertical and horizontal space to inspect short Flow records without duplicating editors or compressing the timeline into an unreadable calendar column.

`タスク` and `分野` reuse the two-column History workspace: aggregates on the left, mini-calendar and daily totals on the right. This keeps date navigation and visual hierarchy stable when switching modes.

Wide `週` keeps a week-selecting mini-calendar on the right; wide `月` replaces it with a twelve-month year picker. Week projects each connected Flow series as one composite block positioned by its exact outer interval. Selecting the block opens a vertical series timeline whose underlying Flow and rest records remain individually editable. A record editor is pushed inside the same sheet, and Back restores the series timeline. The projection does not merge persistence records or alter progress calculations.

## D-015: Dashboard Timeline Shows Flow Series

The Flow dashboard groups connected Flow and rest entries by `seriesID`. One series has one continuous light-gray base line beneath its Area-colored work and gray rest segments. A different series starts a separate line. History Calendar keeps every Flow and rest as an independent block.

Double-clicking empty calendar time first creates an in-grid 25-minute draft block. Wide day editing occurs in the right inspector; compact day and week use a sheet. Saving creates a completed FlowSession and FlowSegment with a new independent series, uses the normal progress calculation, and does not support manual rest creation.

Reason: the dashboard should communicate uninterrupted Flow rhythm without destroying the exact session and rest records required for editing and statistics.

## D-016: Dashboard Statistics Are A Derived Carousel

The fixed-height compact Dashboard Statistics card cycles between Flow-time distribution, a 7-day Flow trend with previous-day comparisons, and today's completion status. Distribution switches between Task and Area without changing persistence. `DashboardStatisticsBuilder` owns historical calculations so SwiftUI only renders derived values.

Reason: the first screen should answer where time went, how the recent rhythm changed, and what remains today without duplicating the full Statistics screen.

## D-017: Manual History Reuses Domain Records

Manual History entry creates a completed independent `FlowSession` and `FlowSegment`. A fixed linked Task receives measured progress but is never automatically completed. The Area aggregate action creates a new Task with that Area fixed and does not create Flow.

Reason: correction workflows must use the same accounting path as timer-created work while keeping Task completion an explicit or measurement-driven action.

## D-018: Measured Progress Is Read-Only

Only `チェック` indicators are directly interactive. `集中ブロック` and `分` indicators are read-only in Tasks, History, the dashboard, and the player because persisted Flow time owns their progress.

Measured Todo progress is reconciled from credited Flow history after every FlowSession/FlowSegment creation, edit, or deletion. The same idempotent reconciliation runs once at app launch to repair legacy drift. Relative progress deltas are not authoritative because deleting or reassigning old history must also recompute completion state.

Reason: one source of truth prevents UI taps from disagreeing with recorded focus history.

## D-019: Shared Core With Platform-Owned UI

Persisted models, domain rules, application state, shared services, and small
reusable controls live under `Shared`. The current navigation, windows,
menu-bar integration, feature views, and AppKit adapters live under
`Platforms/macOS`. The separate iOS layer depends on `Shared` without importing
macOS presentation code.

Reason: macOS behavior must remain stable while iOS receives a layout and scene
model appropriate to its platform. One shared product and persistence layer
prevents business-rule drift between the apps.

## D-020: Private CloudKit Over One Shared SwiftData Schema

Signed macOS and iOS application runs use the private CloudKit database in
`iCloud.com.shigorefu.thruflow`. Tests remain in-memory and local-only; developers
can use `THRUFLOW_DISABLE_CLOUDKIT=1` or `--local-store` when CloudKit is not
available. Relationships have explicit optional inverses and persisted scalar
properties have declaration defaults required by the synchronized schema.

Reason: one schema prevents device-specific data drift while retaining a
deterministic offline/test path and avoiding a second persistence stack.

## D-021: Narrow Native iPhone MVP

Status: superseded by D-022, D-031, and D-032. Retained as the first iPhone
scope decision.

The first iPhone target uses iOS 17.0 as its minimum deployment version and
uses Flow as its root and default screen. Bottom navigation from Flow opens
Tasks, History, and Areas, while Settings lives in the hamburger menu.
The timer and animated Flow stream share the first viewport; Tasks and compact
Statistics are horizontal dashboard pages. History provides native day, week,
and month browsing. Advanced Statistics and full calendar/history editing are
deferred to the next iPhone stage. The iPhone uses native compact navigation
rather than shrinking the macOS dashboard and calendar screens.

Reason: the core daily loop must be useful and stable on a phone before desktop
analysis and editing surfaces are redesigned for touch.

## D-022: Material iPhone Shell and Shared Flow Mode Selector

Status: navigation and Statistics scope are superseded by D-031 and D-032. The
shared mode-selector and touch-presentation decisions remain active.

The iPhone shell amends D-021 with four floating material navigation actions:
Flow, Tasks, History, and Statistics. Settings moves to the trailing More menu.
Area management remains reachable from that menu. The Flow stream appears
before the player, and both platforms use one shared segmented Sprint, Focus,
and Deep selector with a separate help presentation for work/rest duration and
usage guidance. The iPhone Statistics screen is a compact contribution summary;
advanced analysis remains deferred. The iPhone Task composer uses material
surfaces, shared quick-input parsing, autocomplete, and an explicit arbitrary
date picker. The iPhone selector presents Help as a system bottom sheet, while
macOS keeps a popover. Both platforms render the animated stream through the
same shared Metal surface and shader. The iPhone transport exposes destroy,
stop, break, subtract five minutes, Play/Pause, and add five minutes without changing the
established player-card dimensions.

Reason: the primary touch targets must remain stable and legible on iPhone,
while mode meaning and task syntax should not drift between platforms.

## D-023: Live Activity Is A Projection Of ActiveFlowStore

The iPhone app owns one ActivityKit adapter behind the shared
`LiveActivityService` protocol. `ActiveFlowStore` publishes an immutable
`FlowLiveActivityContent` snapshot after every relevant timer or context
transition. Shared `FlowActivityAttributes`, formatting, and App Intents are
compiled into both the iOS app and its Widget Extension. The extension renders
Lock Screen and Dynamic Island surfaces but does not access SwiftData or run an
independent timer engine. Date-backed timer ranges let ActivityKit update time
and progress while the app is suspended. Expanded Dynamic Island actions for
subtracting five minutes, pause/resume, and adding five minutes resolve the app-owned store
through `AppDependencyManager`; they do not duplicate timer rules in the Widget
Extension. Lock Screen content remains read-only, and the activity URL returns
to the Flow tab.

Reason: system surfaces must remain synchronized with the canonical timer state.
Dynamic Island regions remain self-sizing: an unbounded `.infinity` frame inside
an expanded region produced a `NaN` layout origin and terminated Apple's
`WidgetRenderer_Activities` process on iOS 26.5. A static action registry is also
prohibited because it cannot bridge the application and extension processes.
The archived ActivityKit view tree must use system date-backed `Text` and
`ProgressView` implementations. A custom `DiscreteFormatStyle` in the running
clock caused WidgetRenderer to replace the whole activity with gray placeholder
redaction even though the extension compiled successfully. The system
`Text(timerInterval:countsDown:showsHours:)` keeps the clock numeric instead of
adaptively replacing short values with localized unit text such as `1分` or
`<1 min`. Countdown uses the planned timer range; overtime uses a count-up range
beginning at `plannedEndAt`. `ActiveFlowStore` publishes one boundary update
when an active app observes the sign change so the extension can switch ranges
and add the explicit overtime `+`; custom per-second formatting and per-second
ActivityKit updates are not allowed in the extension.
When the app is suspended at the boundary, the system timer can reach `00:00`
without reevaluating the conditional overtime view. Guaranteeing the switch to
`+00:01` in that state requires an ActivityKit push update through APNs.
`staleDate`, WidgetKit timelines, background tasks, and local notifications do
not provide an exact or guaranteed boundary update.
The dynamic timer text must remain flexible inside ActivityKit's compact,
expanded, and Lock Screen regions; `fixedSize()` is prohibited because it can
collapse the archived timer label at runtime.

## D-024: Home Screen Timer Widget Is A Read-Only Snapshot

The Small and Medium `Flowタイマー` widgets reuse the existing multiplatform Widget Extension
but do not reuse ActivityKit rendering or create another timer controller. The
iOS Live Activity adapter and macOS Widget projection service write one Codable `FlowTimerWidgetSnapshot` to App
Group `group.com.shigorefu.thruflow` whenever the canonical
`FlowLiveActivityContent` changes, clears it when Flow ends, and requests a
targeted WidgetKit reload. The extension uses date-backed system timer and
progress views, and tapping the widget deep-links to Flow. Transport controls
remain in the app and Live Activity.

Reason: a Home Screen widget must stay glanceable and current while respecting
WidgetKit's update budget. Sharing an immutable cross-process snapshot preserves
one timer source of truth and avoids per-second timelines, SwiftData access, and
business-rule duplication in the extension.

## D-025: Product Widgets Use Application-Built Immutable Snapshots

The Widget Extension exposes three independent Home Screen/macOS desktop configurations:
`Flowタイマー`, `今日のタスク`, and `Flow Dots`. The timer remains a projection
of `FlowLiveActivityContent`. The iOS and macOS applications build Tasks with the
canonical Today filter and dashboard ordering, and builds Dots with the
canonical 180-day statistics heatmap. It serializes these immutable Codable
snapshots into the shared App Group and requests targeted WidgetKit reloads.

The extension is presentation-only: it does not open SwiftData or CloudKit and
does not reproduce filtering, sorting, progress, color-mixing, or timer rules.
Small/Medium/Large Tasks and Small/Medium/Large Dots are different layouts over
the same snapshots, not separate data pipelines. Dots use exact family-sized
grids (`5 × 6`, `12 × 5`, `9 × 10`) with 30, 60, or 90 visible days, four
relative activity levels, and no placeholder cells.

Reason: WidgetKit has a constrained execution and refresh budget. Computing
product projections in the application preserves one source of truth, keeps the
extension deterministic, and prevents persistence or migration failures from
terminating the widget process.

## D-026: Retrospective Task Records Reuse Todo And Flow

History exposes one shared macOS/iOS `+` command for recording forgotten work.
It is a trailing toolbar action across History modes. macOS opens a trailing
inspector and iOS opens the shared form in a sheet. Its Flow-style picker
separates Tasks, Habits, and Areas. It can select an existing Todo
occurrence, create a new Task, materialize an eligible
missing historical Habit occurrence from its internal `Direction` template, or
record Area-only Flow. Recording Check needs only a date, accepts optional time,
writes manual completion, and creates no Flow. Recording Block, Minute, or
Area-only work requires start/end time, creates the normal completed manual
FlowSession/FlowSegment pair, and relies on standard history reconciliation for
measured progress. Zero-Flow Todos remain absent from actual History summaries.

Reason: forgotten completion and forgotten focused work are different facts.
Reusing existing entities preserves that distinction and avoids a second
history model or fabricated focus time.

## D-027: Active Flow Runtime Synchronizes Through FlowSession

The active Flow timer is persisted in the same `FlowSession` record that owns
its history. `FlowSession` stores the complete reconstructable
`FlowTimerState`, including pause and break anchors, plus a monotonically
advanced runtime revision and mutation identifier. `ActiveFlowStore` remains
the only timer state machine; a shared coordinator only resolves the newest
active persisted session and adopts its absolute timestamp-based state.

macOS and iOS reconcile on launch, foreground entry, and while their scene is
active. A command made on either platform updates the shared session, and the
other active application adopts that revision without restarting elapsed time.
If concurrent offline starts produce multiple active sessions, the coordinator
selects one deterministically and marks the others interrupted. Local-only and
test stores use exactly the same reconciliation behavior without requiring
CloudKit.

CloudKit delivery is opportunistic. It can synchronize the active runtime and
restore it when the receiving app runs, but it cannot guarantee waking a fully
suspended iPhone or starting its Live Activity immediately. Guaranteed
background Dynamic Island updates require ActivityKit push tokens and an APNs
provider, which are a separate future transport and do not change this runtime
contract.

Reason: persisting the canonical runtime alongside its session avoids a second
timer entity, preserves offline operation, and gives macOS, iOS, and watchOS
one conflict and restoration model.

## D-028: Habit Pause Removes Expectations, Not History

A Habit Direction can be paused for today, through an inclusive date, or until
the user resumes it. Pause periods are optional JSON-backed scalar data on the
Direction and are interpreted by shared `HabitPauseService` and
`RequiredTodoPlanner` logic. They do not add a second schedule entity.

Paused days cannot generate or receive a Habit Todo. When a pause begins, only
uncompleted occurrences with zero measured progress and zero focused seconds
are soft-deleted. Completed occurrences, partial progress, and Flow history are
preserved. Because no planned Todo exists for a paused day, that day is excluded
from the completion denominator and cannot count as a failure; actual Flow
continues to count in focused-time statistics.

Reason: a deliberate break changes what the user intended to do, not what the
user already did. Keeping planning and actual history separate avoids false
failures without rewriting historical records.

## D-029: Version 1.x Does Not Require An APNs Backend

ThruFlow 1.x remains fully usable without an author-operated server. The
canonical active Flow continues to use absolute timestamps in SwiftData and
CloudKit even while an application is suspended. However, if iOS suspends the
application before the planned boundary, its Live Activity can remain visually
at `00:00` until the application next launches, enters the foreground, or
otherwise publishes new ActivityKit content. This is an accepted presentation
limitation of 1.x, not a loss or pause of canonical timer state.

An ActivityKit APNs provider and all external Connectors are deferred together
to 2.0. The future provider must remain optional: local Flow recording and
CloudKit synchronization stay the source of truth and must continue working
without the provider, its credentials, AWS, or network access.

Reason: an open-source core release should not depend on the maintainer running
and funding a backend. APNs transport and OAuth/webhook Connectors introduce
operational cost, secret management, abuse protection, and privacy obligations
that belong to a separate product stage.

## D-030: macOS Statistics Is A Filtered Period Report

The standalone macOS Statistics workspace uses anchored Week, Month, and Year
periods plus an exact inclusive custom date range with summary, trend,
focused-time distribution, and Dots cards. A persistent calendar centers the
Week/Month/Year control and selects the anchored period; a trailing icon-only
`期間を指定` action opens the custom start/end popover. Trend and Dots
own independent `Flow | タスク` display switches so comparison and contribution
views can be inspected without rebuilding the projection. Area filter and
text search apply before every aggregation, and CSV exports the combined visible
projection by default. A direct Share action opens export controls for combined,
Flow-only, or Task-only data, exact inclusive start/end dates, Area, and
text filter. Pie selection is presentation-only: the chosen sector remains
bright while other sectors are dimmed and the legend isolates that category.
The toolbar Area filter shares the navigation Area symbol. Month trends
use seven-day totals rather than one noisy point per day and render current and
previous values as separate line series. Month can place Pie and Dots in one row;
its Dots columns fill their card, while Week and Year keep full-width Dots.
Custom Dots stretch up to seven actual days, then use small cells for every
longer range, adding calendar cells for medium ranges and compact week columns
for long ranges; preset Month retains the regular calendar-cell size, and every
real cell exposes a system hover bubble above the card layer with its daily
metrics, except Year Dots, which remain display-only because their cells are too
small for dependable targeting. Current ranges stop at today: future calendar
dates, export/custom dates, Trend/Dots buckets, and forward navigation are
disabled or clipped. The Year calendar lists the
current year first and does not offer future years.
Flow switching is resolved per segment; the model does not add a Project
entity. The compact iPhone and widget contribution ranges from D-009 remain
unchanged until explicitly superseded.

Reason: desktop space supports comparison and investigation while one shared,
segment-aware projection keeps cards, search, and export numerically
consistent. Task titles already provide the lightweight grouping needed for
work such as repeated sessions on one book.

## D-031: iPhone Statistics Reuses The Complete Period Report

The standalone iPhone Statistics screen now consumes the same
`StatisticsPeriodSnapshot` as macOS and supersedes only the compact-Statistics
limits in D-021, D-022, and D-030. It exposes anchored Week, Month, Year, and
exact custom periods; Summary, Trend, focused-time distribution, and Dots;
independent Trend/Dots Flow/Task modes; Area and text filters; interactive
Pie isolation; and combined, Flow-only, or Task-only CSV export. The shared
actor, period builder, export serializer, comparison interval, and bounded
four-projection cache remain the numeric source of truth.

iPhone owns a touch-native renderer rather than compiling the macOS view: one
vertical card scroll, graphical period and two-date custom-range sheets, a
native export sheet and ShareLink, a compact full-width Canvas for Year Dots,
and a daily detail sheet that can open History. Year Dots are intentionally
non-interactive. Search begins as a toolbar magnifier and expands on demand;
Search stays trailing while context actions occupy the leading side: Tasks and
Areas use `その他`, History uses its report mode, and Statistics groups
Share with the Area filter. Creation actions remain trailing. The shared
principal title stays centered. All iPhone navigation destinations use this centered inline title
contract. The widget Dots projection
remains separate and compact.

Reason: analysis should give the same answer on Mac and iPhone, while platform
navigation, density, pointer behavior, and sharing must continue to follow the
system conventions of each device.

## D-032: iPad Uses The Universal Adaptive iOS Target

`ThruFlow iOS` supports both iPhone and iPad rather than shipping a second app
bundle. Compact widths retain the system tab bar; regular widths switch to a
Mac-like `NavigationSplitView` with a persistent sidebar and wide feature
detail. The iPad presentation reuses the iOS-owned feature renderers and shared
application/domain state instead of compiling AppKit-owned macOS views or
forking SwiftData and CloudKit configuration. Narrow Split View and Stage
Manager windows return to the compact shell, and iPad enables all portrait and
landscape orientations.

Reason: one universal bundle preserves installation identity, CloudKit data,
deep links, and release versioning while allowing each available width to use
space appropriately.

## D-033: Guided Onboarding Teaches The Real Loop Safely

Version 1.0.2 replaces the passive seven-card introduction with one shared
ten-step journey on macOS, iPhone, and iPad: Welcome, Area, Task, Flow overview,
timer guidance, a transient Flow demo, History, Statistics, workflow summary,
and a final data/core-features card.
Guidance stays independent of target geometry and presents the real Area editor
and Task composer through platform-native surfaces.

An empty first installation may offer localized Work and report drafts. Opening
a draft writes nothing; only the user's normal Save or Submit action creates the
Area or Task. Those confirmed records are real user data and follow the standard
SwiftData and private CloudKit path. The Flow preview reuses the complete
production player appearance in a scripted, non-interactive sequence: Task
selection, visual Play, accelerated Short focus from `12:00` to `00:00`, visual
break action, and the demonstrated regular-break state at `03:00`. The demo
transition omits the note panel; the real player keeps focus running and starts
the break only after the user confirms that note. Demo controls, timer, phase,
and progress are presentation state only. They create no session, segment,
break, Task completion, focused progress, History, Statistics, Live Activity,
notification, or CloudKit record.

If user content already exists, first-run onboarding is a read-only tour.
Settings replay is always read-only, dismisses Settings before it begins, and
restarts from Welcome without clearing or modifying data. Every card has an
icon-only Close control. Dedicated preview schemes use an in-memory store, and watchOS does not
repeat onboarding because it is a companion surface.

On signed CloudKit runs, an initially empty query snapshot is not accepted as
final immediately. Onboarding waits for the first successful import event or a
bounded four-second grace period, then inspects again. It performs the same fresh
inspection before accepting an onboarding Area or Task save. Late imported
content switches the remaining journey to read-only without silently discarding
an editor draft.

Reason: performing one real, user-confirmed Area and Task action teaches the
product loop more clearly than a passive screen description, while a transient
Flow preview and read-only replay protect History, Statistics, and existing
CloudKit data from fabricated examples.

## D-034: Support Is Voluntary And Never Interrupts Work

The app does not send promotional notifications. StoreKit's review prompt may
be requested only at a natural post-Flow moment after seven days and either
five active Flow days or ten completed Flows, at most once per app version.
Settings owns permanent GitHub, Coffee JPY 100, and Ramen JPY 500 support
actions. Coffee and Ramen are consumable StoreKit products, unlock
nothing, and create no entitlement. Tasks, the Flow focus timer, History, and
Statistics are free and ad-free and require no payment. This decision makes no
pricing promise for possible future optional integrations or services.

Reason: support should remain visible to people who seek it without turning a
focus tool into an advertising surface, gating its core loop, or pressuring a
new user, while leaving future optional services to be evaluated separately
against their actual costs.

## D-035: Settings Owns Complete App-Data Reset

macOS exposes the native Settings scene through a gear at the bottom of its
sidebar. macOS, iPhone, and iPad Settings can delete every `Direction`, `Todo`,
`FlowSession`, `FlowSegment`, and `FlowBreak` after an irreversible
confirmation. The operation is unavailable while a restorable Flow runtime is
active and runs as one model-actor transaction. Private CloudKit propagates the
deletions to the user's other devices. Local appearance, language, calendar,
and time preferences remain. After success, the timer selection is reset and
the first-run onboarding journey begins again.

Reason: users need one clear release-grade way to start over without leaving
related Tasks, Areas, notes, history, or computed progress behind, while keeping
device preferences that are not part of their productivity data.

## D-036: Feedback Stays Outside The Settings Menu

macOS, iPhone, and iPad Settings do not include a separate feedback section.
TestFlight testers use TestFlight's native feedback tools, while the public
GitHub repository remains available from the support section. ThruFlow does not
add a custom feedback server, analytics SDK, mail recipient, or undocumented
TestFlight deep link. The support section keeps the explicit App Store rating
action, and the app may also request a system review at an appropriate post-Flow
moment under the review policy.

Reason: the Settings screen stays compact while TestFlight and GitHub continue
to provide established feedback channels without another account or data-
collection service.

## D-037: The Flow Stream Acknowledges The Rest Lifecycle

The shared Flow stream runs its existing idle and active phase-speed curves 25
percent faster without changing the 30/60 FPS cadence. A restrained idle-only
inner current makes the low end of that curve readable without applying another
speed multiplier. Every valid `休憩`
selection publishes one sequenced, non-persisted request cue and produces a
short reverse release wave. This acknowledges the tap but does not represent a
started rest. Only the actual `beginBreak` transition publishes the start cue;
user-facing controls reach that transition after memo confirmation. A regular rest
uses a soft exhale; a confirmed `長休憩` uses a stronger four-second fan and
bloom followed by a calm breathing spread. The canonical timer remains the
source of the ongoing regular/long-rest style, including after restoration. On
watchOS, where the stream is on another page, the rest control also bounces and
provides light sensory feedback immediately. Reduce Motion suppresses transient
stream movement without hiding the rest state.

Reason: the stream should feel directly connected to the player's controls and
reward the four-Block milestone, while memo cancellation, timer history,
CloudKit synchronization, and render performance retain their existing
semantics.
