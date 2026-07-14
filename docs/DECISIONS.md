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

Reason: habit tasks and auto-created Flow tasks should start as lightweight templates.

## D-005: Date-less Task Behavior Is Deferred

There is no separate Inbox navigation item in the current UI. The storage field remains optional, but product behavior for date-less Tasks will be defined later.

Reason: the previous Inbox concept was removed before the replacement workflow was defined.

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

The `タスク` screen combines `1日`, `3日`, `7日`, and `月` ranges. Habit instances remain on the same calendar as normal Tasks and can be isolated with a filter instead of a separate navigation destination.

Reason: users plan work by date and should not need to check separate screens for Tasks and Habits.

## D-012: Calendar Moves Preserve Habit Rules

Drag-and-drop between kanban day columns changes `scheduledDate` only for active normal Tasks and feasible weekly-count Habit Tasks. Month remains an overview. Completed Tasks and fixed-schedule Habit instances remain on their original date.

Reason: calendar planning must not silently invalidate historical completion or recurring commitments.

## D-013: Flow Is The Daily Dashboard

`Flow` is the first/default app section. Its wide dashboard gives roughly three quarters of the content to the animated stream and timeline, with a separate circular player panel on the right and today's Task/Habit/optional Nice sections plus compact Statistics below. It reuses the existing player behavior and derives all visual data from Todo and FlowSession records. A system Metal shader provides the broad, smooth visual layer without adding a persistence model or third-party rendering dependency; visual growth is capped at 6 Blocks and controlled by the testable `FlowVisualState` projection.

Reason: starting focused work and seeing its accumulated shape should be the primary app experience, while Tasks, History, Directions, and Statistics remain dedicated supporting surfaces.

## D-014: Day History Uses Timeline And Inspector

The `日` History range uses a narrow Apple Calendar-style timeline with a persisted `Elastic | 24時間` scale. A right pane contains the only wide-layout date mini-calendar and properties for the selected actual record or manual Flow draft; the wide left rail contains filters only. Compact windows present those properties in a sheet.

Reason: day history needs enough vertical and horizontal space to inspect short Flow records without duplicating editors or compressing the timeline into an unreadable calendar column.

## D-015: Dashboard Timeline Shows Flow Series

The Flow dashboard groups connected Flow and rest entries by `seriesID`. One series has one continuous light-gray base line beneath its Direction-colored work and gray rest segments. A different series starts a separate line. History Calendar keeps every Flow and rest as an independent block.

Double-clicking empty calendar time first creates an in-grid 25-minute draft block. Wide day editing occurs in the right inspector; compact day and week use a sheet. Saving creates a completed FlowSession and FlowSegment with a new independent series, uses the normal progress calculation, and does not support manual rest creation.

Reason: the calendar should communicate uninterrupted Flow rhythm without destroying the exact session and rest records required for editing and statistics.

## Open Questions

- What measurement and planned amount should be used for an auto-created Task when Flow starts with only a Direction or with neither Direction nor Task?
- Should Adaptive/Auto Flow remain, or should MVP expose only Short, Focus, and Deep?
- How exactly should the “continue for longer break” prompt behave when less than 5 minutes remain to the next threshold?
- What is the exact meaning of deleting the “last 1 Block” from a Flow series?
- How should the 4-Block long-break series counter be represented and reset?
