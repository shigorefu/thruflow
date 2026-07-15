# Technical Plan

## Architecture

Keep separation between:

- domain models: Direction, Todo, FlowSession, FlowSegment, FlowBreak;
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
- `FlowSegment` stores Task/Direction intervals and cumulative focused-second boundaries within a FlowSession.
- `FlowBreak` stores explicit rest and UUID links between adjacent sessions in a Flow series; `FlowSeriesPolicy` owns continuation windows and Long Break thresholds.
- `Todo.completedAt` stores the exact completion time for new completions.
- `DayHistoryBuilder` creates daily Task/Direction aggregates and legacy day projections.
- `HistoryCalendarBuilder` creates read-only day/week/month calendar projections from actual Flow and break records; Todo completion never creates a calendar item.
- `FlowDashboardBuilder` groups connected records by `seriesID` into continuous dashboard series spans without mutating calendar history.
- `HistoryDayTimelineWindowBuilder` derives the testable Elastic/full-day hour range independently from SwiftUI, including records that cross midnight.
- `HistoryOverlapLayout` assigns deterministic side-by-side lanes using actual and minimum visual duration so short records cannot overlap in rendering.
- `FlowHistoryEditor` creates independent completed manual Flow records and applies progress deltas when historical Flow records change.
- `FlowDashboardBuilder` derives today's totals, Direction palette, and timeline segments from `FlowSession`, with a live overlay for the active creditable Flow.
- `DashboardStatisticsBuilder` derives 3/7-day bars, previous-day deltas, and the most-grown Direction outside SwiftUI.
- `FlowVisualState` converts 0...6 daily Blocks into clamped speed, volume, layer count, and mode-specific wave character without placing those rules in SwiftUI.
- `FlowStream.metal` renders the broad multi-color stream as one GPU effect. The SwiftUI host supplies only accumulated phase and visual-state uniforms, uses 30 FPS while idle and 60 FPS while active, and pauses when its window is not key, the scene is inactive, or Reduce Motion is enabled. `FlowAnimationClock` preserves phase when speed changes or rendering pauses, so starting Flow and returning to the window never replace the current stream frame.
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
- Manual Flow creation, linked Task progress without implicit completion, and fixed-Direction Task creation.
- Flow series continuation, Long Break thresholds, rest correction, and same-series downstream shifting.
- Flow dashboard totals, palette ordering, day filtering, live minimum-credit behavior, and timeline normalization.
- Dashboard statistics distribution, 3/7-day trend comparisons, and completion projection.

## Migration Caution

Avoid removing SwiftData fields such as `FlowSession.result` without a deliberate migration step. It can remain as legacy-compatible storage while new memo writes go to Todo.
