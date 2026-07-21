# Decisions

## D-001: CONCEPT.md Is Product Source Of Truth

`CONCEPT.md` defines the product model. `CODEX.md` and `docs/` summarize it for implementation.

Reason: the product direction changed, and older Must/Bonus/Result wording is deprecated.

## D-002: Direction Types

Current visible Direction types are:

- `通常`;
- `習慣`;
- `ナイス`.

Reason: these terms match the current Japanese UI model.

## D-003: System Direction

Tasks and Flow without a user-selected Direction are assigned to system Direction `その他`.

`その他` is hidden only from Direction management to prevent editing. It may appear in task context and statistics.

Reason: the app needs a stable Direction relationship without forcing the user to choose one every time.

## D-004: Empty Todo Title Is Valid

Todo title may be empty. UI displays `(Direction name)` when title is empty.

Reason: generated Habit tasks should start as lightweight templates, and the same display rule remains available if automatic Flow Task creation is defined later.

## D-005: Backlog Lives Inside Tasks

There is no separate Inbox navigation item. Overdue normal Tasks appear in Today, while active normal Tasks with no date are available through a counted `日付なし` inspector in `タスク`. Habit instances are excluded because their dates are owned by Habit scheduling rules.

Reason: calendar planning should expose work that needs attention without adding another primary destination or mixing automatically generated Habit history into a manual backlog.

## D-006: Todo Owns Memo

Flow memo is written to the associated Todo. FlowSession stores timing/history, not user-facing memo.

Reason: the user describes what was done for the task, not for an abstract timer record.

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

Statistics ranges are:

- current month;
- last 180 days;
- current calendar year.

Reason: these match the current concept and keep GitHub-like statistics understandable.

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

`Flow` is the first/default app section. Its wide dashboard gives roughly three quarters of the content to the animated stream and timeline, with a separate circular player panel on the right and today's Task/Habit/optional Nice sections plus compact Statistics below. It reuses the existing player behavior and derives all visual data from Todo and FlowSession records. A system Metal shader provides the broad, smooth visual layer without adding a persistence model or third-party rendering dependency; visual growth is capped at 6 Blocks and controlled by the testable `FlowVisualState` projection.

Reason: starting focused work and seeing its accumulated shape should be the primary app experience, while Tasks, History, Directions, and Statistics remain dedicated supporting surfaces.

## D-014: Day History Uses Timeline And Inspector

The `日` History range uses a narrow Apple Calendar-style timeline with a persisted `Elastic | 24時間` scale. A right pane contains the only wide-layout date mini-calendar and properties for the selected actual record or manual Flow draft. Flow/rest filters live in a compact `表示` menu instead of a separate rail. Compact windows present those properties in a sheet.

Reason: day history needs enough vertical and horizontal space to inspect short Flow records without duplicating editors or compressing the timeline into an unreadable calendar column.

`タスク` and `方向` reuse the two-column History workspace: aggregates on the left, mini-calendar and daily totals on the right. This keeps date navigation and visual hierarchy stable when switching modes.

Wide `週` keeps a week-selecting mini-calendar on the right; wide `月` replaces it with a twelve-month year picker. Calendar lanes use exact stored intervals rather than minimum visual height, so contiguous Flow and rest records stay in one lane while true overlaps remain side by side.

## D-015: Dashboard Timeline Shows Flow Series

The Flow dashboard groups connected Flow and rest entries by `seriesID`. One series has one continuous light-gray base line beneath its Direction-colored work and gray rest segments. A different series starts a separate line. History Calendar keeps every Flow and rest as an independent block.

Double-clicking empty calendar time first creates an in-grid 25-minute draft block. Wide day editing occurs in the right inspector; compact day and week use a sheet. Saving creates a completed FlowSession and FlowSegment with a new independent series, uses the normal progress calculation, and does not support manual rest creation.

Reason: the dashboard should communicate uninterrupted Flow rhythm without destroying the exact session and rest records required for editing and statistics.

## D-016: Dashboard Statistics Are A Derived Carousel

The fixed-height compact Dashboard Statistics card cycles between Flow-time distribution, a 7-day Flow trend with previous-day comparisons, and today's completion status. Distribution switches between Task and Direction without changing persistence. `DashboardStatisticsBuilder` owns historical calculations so SwiftUI only renders derived values.

Reason: the first screen should answer where time went, how the recent rhythm changed, and what remains today without duplicating the full Statistics screen.

## D-017: Manual History Reuses Domain Records

Manual History entry creates a completed independent `FlowSession` and `FlowSegment`. A fixed linked Task receives measured progress but is never automatically completed. The Direction aggregate action creates a new Task with that Direction fixed and does not create Flow.

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

The first iPhone target uses iOS 17.0 as its minimum deployment version and
uses Flow as its root and default screen. Bottom navigation from Flow opens
Tasks, History, and Directions, while Settings lives in the hamburger menu.
The timer and animated Flow stream share the first viewport; Tasks and compact
Statistics are horizontal dashboard pages. History provides native day, week,
and month browsing. Advanced Statistics and full calendar/history editing are
deferred to the next iPhone stage. The iPhone uses native compact navigation
rather than shrinking the macOS dashboard and calendar screens.

Reason: the core daily loop must be useful and stable on a phone before desktop
analysis and editing surfaces are redesigned for touch.

## D-022: Material iPhone Shell and Shared Flow Mode Selector

The iPhone shell amends D-021 with four floating material navigation actions:
Flow, Tasks, History, and Statistics. Settings moves to the trailing More menu.
Direction management remains reachable from that menu. The Flow stream appears
before the player, and both platforms use one shared segmented Short, Focus,
and Deep selector with a separate help presentation for work/rest duration and
usage guidance. The iPhone Statistics screen is a compact contribution summary;
advanced analysis remains deferred. The iPhone Task composer uses material
surfaces, shared quick-input parsing, autocomplete, and an explicit arbitrary
date picker. The iPhone selector presents Help as a system bottom sheet, while
macOS keeps a popover. Both platforms render the animated stream through the
same shared Metal surface and shader. The iPhone transport exposes destroy,
stop, break, seek backward, Play/Pause, and seek forward without changing the
established player-card dimensions.

Reason: the primary touch targets must remain stable and legible on iPhone,
while mode meaning and task syntax should not drift between platforms.

## Open Questions

- What measurement and planned amount should be used for an auto-created Task when Flow starts with only a Direction or with neither Direction nor Task?
- Should Adaptive/Auto Flow remain, or should MVP expose only Short, Focus, and Deep?
- How exactly should the “continue for longer break” prompt behave when less than 5 minutes remain to the next threshold?
- What is the exact meaning of deleting the “last 1 Block” from a Flow series?
