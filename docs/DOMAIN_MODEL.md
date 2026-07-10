# Domain Model

## Direction

`Direction` is a persistent area of activity.

Stable type raw values:

- `neutral` -> `通常`;
- `habit` -> `習慣`;
- `nice` -> `ナイス`.

Legacy raw values `must` and `bonus` are normalized to `habit` and `nice`.

`その他` is represented as a system `Direction` so Tasks and Flow always have a stable Direction relationship. It is hidden from the Direction management screen to prevent editing. It can still appear in task context and statistics.

Habit Directions may have:

- schedule kind: every day, weekly count, or selected weekdays;
- target amount;
- goal unit: occurrences, focus blocks, minutes, or hours.

## Todo

`Todo` is the task model used by the daily `タスク` screen.

Important fields:

- `title`: may be empty;
- `notes`: Todo memo;
- `direction`: resolved Direction, usually never nil in app-created data;
- `measurement`: checkbox, focus blocks, or minutes;
- `priority`: high, medium, low;
- `isRoomIfPossible`: only meaningful for low priority;
- `scheduledDate`: optional task date; the UI behavior for nil is deferred;
- `plannedAmount` and `actualProgress`;
- `focusDurationSeconds`: exact accumulated focused seconds.

Display rule:

- non-empty title displays as title;
- empty title displays as `(Direction name)`;
- no visible Direction fallback displays as `(その他)`.
- an empty-title fallback is rendered as translucent italic text.

Completion:

- checkbox: completed by user check;
- focus blocks: completed when accumulated block progress reaches planned amount;
- minutes: completed when accumulated focused minutes reaches planned amount.

## FlowSession

`FlowSession` stores timing/history:

- Direction;
- optional Todo;
- mode;
- phase/status;
- planned and actual focused seconds;
- break duration;
- timestamps;
- pause/interruption data.

Todo memo is not stored in FlowSession. The current model may keep legacy `result` storage for migration compatibility, but new memo writes go to `Todo.notes`.

## Block

Block display is derived from focused seconds:

- under 12 focused minutes: `0 Block`;
- 12 focused minutes: `0.5 Block`;
- 24 focused minutes: `1 Block`;
- 25 focused minutes: `1 Block`;
- 37 focused minutes: `1.5 Blocks`;
- 50 focused minutes: `2 Blocks`.

The exact seconds are preserved. Block UI displays half-block credits; minute UI displays exact minutes.

## Weekly Habit Generation

Weekly-count Habit Directions create one pending Todo at a time. A completed Todo permits the next instance on a later eligible day in the same week. A rescheduled pending Todo blocks duplicate generation, and rescheduling cannot leave too few eligible days to meet the weekly target.

## Task Calendar

`TaskCalendarBuilder` creates deterministic one-day, three-day, seven-day, and full-week month-grid date ranges. `TaskRescheduleService` validates calendar drag-and-drop independently from SwiftUI.

Normal active Tasks may change `scheduledDate`. Completed Tasks and fixed daily/weekday Habit instances cannot move. Weekly-count Habit movement delegates to `RequiredTodoPlanner` feasibility rules.

## Statistics

Flow statistics are derived from FlowSession actual focus seconds. Task statistics are derived from completed Todos.
