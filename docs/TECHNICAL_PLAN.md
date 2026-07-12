# Technical Plan

## Architecture

Keep separation between:

- domain models: Direction, Todo, FlowSession;
- domain logic: validation, filtering, planning, progress, timer, statistics;
- services: notifications and platform bridges;
- SwiftUI features.

SwiftUI views should call domain logic instead of owning product rules directly.

## Current Data Rules

- `DefaultDirections` resolves system `その他`.
- `TodayTodoFilter` includes only scheduled tasks for the selected day.
- `TaskCalendarBuilder` creates deterministic visible date ranges and month grids.
- `TaskRescheduleService` validates kanban and month-grid drag-and-drop.
- Date-less Task presentation is deferred; no Inbox navigation is exposed.
- `RequiredTodoPlanner` creates scheduled habit tasks.
- `FlowProgressCalculator` writes focused time to Direction and Todo.
- `Todo.notes` stores memo.
- `FlowSession` stores timing/history.
- `Todo.completedAt` stores the exact completion time for new completions.
- `DayHistoryBuilder` creates daily timeline and Task/Direction aggregates.
- `FlowHistoryEditor` applies progress deltas when historical Flow records change.
- `FlowDashboardBuilder` derives today's totals, Direction palette, and normalized 24-hour segments from `FlowSession`, with a live overlay for the active creditable Flow.
- `FlowVisualState` converts 0...6 daily Blocks into clamped speed, volume, layer count, and mode-specific wave character without placing those rules in SwiftUI.
- `FlowStream.metal` renders the broad multi-color stream as one GPU effect. The SwiftUI host supplies only time and visual-state uniforms, uses 30 FPS while idle and 60 FPS while active, and pauses when the scene is inactive or Reduce Motion is enabled.
- The dashboard reuses `FlowMiniPlayerView` behavior through its dedicated dashboard layout instead of creating a second timer controller. `ActiveFlowStore.phaseProgress` provides the circular timer progress.
- The dashboard projects today's Todo groups and uses `RequiredTodoPlanner` to ensure today's Habit instances exist when Flow is the first opened screen.
- `TodoProgressControl` is the shared Check/Block/Minute control used by Tasks and the dashboard.

## Test Expectations

Cover:

- Direction validation and legacy raw value normalization.
- Todo validation and daily Task filtering.
- Calendar range, filtering, and rescheduling tests.
- Habit task generation.
- Block conversion and progress.
- Flow timer transitions.
- Statistics range construction and filters.
- Day-history grouping, legacy untimed completions, and Flow correction deltas.
- Flow dashboard totals, palette ordering, day filtering, live minimum-credit behavior, and timeline normalization.

## Migration Caution

Avoid removing SwiftData fields such as `FlowSession.result` without a deliberate migration step. It can remain as legacy-compatible storage while new memo writes go to Todo.
