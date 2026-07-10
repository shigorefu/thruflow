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

## Migration Caution

Avoid removing SwiftData fields such as `FlowSession.result` without a deliberate migration step. It can remain as legacy-compatible storage while new memo writes go to Todo.
