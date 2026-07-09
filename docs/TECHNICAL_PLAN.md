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
- `InboxTodoFilter` includes active date-less tasks.
- `RequiredTodoPlanner` creates scheduled habit tasks.
- `FlowProgressCalculator` writes focused time to Direction and Todo.
- `Todo.notes` stores memo.
- `FlowSession` stores timing/history.

## Test Expectations

Cover:

- Direction validation and legacy raw value normalization.
- Todo validation and Inbox/Today filtering.
- Habit task generation.
- Block conversion and progress.
- Flow timer transitions.
- Statistics range construction and filters.

## Migration Caution

Avoid removing SwiftData fields such as `FlowSession.result` without a deliberate migration step. It can remain as legacy-compatible storage while new memo writes go to Todo.
