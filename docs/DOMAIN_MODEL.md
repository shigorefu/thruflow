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
- `completedAt`: optional exact completion timestamp; nil on active and legacy completed records.

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

## FlowSegment

`FlowSegment` records a Task/Direction interval inside one `FlowSession`. It stores wall-clock start/end dates and cumulative focused-second offsets at both boundaries, so pauses are excluded deterministically. Switching Task while focusing or paused closes the current segment and opens another without resetting the timer. Progress is credited from segment durations; legacy FlowSession records without segments keep the previous session-level fallback.

## FlowBreak

`FlowBreak` persists explicit rest between Flow sessions using stable session UUID references. It stores the series ID, previous/next session IDs, rest start, timer-stop, connection, optional adjusted-end timestamps, planned duration, and Long Break state. Sessions started within planned rest × 1.5 share the same series ID. A Long Break lasts 20 minutes after every 4 accumulated Blocks in a series and permits continuation for 30 minutes from rest start. `FlowBreakEditor` applies manual duration corrections and pushes only overlapping downstream records from the same series.

The Flow dashboard is a projection, not a persisted model. `FlowDashboardBuilder` derives today's totals, Direction color palette, timeline segments, breaks, and connected series spans from `FlowSession` and `FlowBreak`; the active session contributes a live overlay only after the one-minute credit threshold. See `DATA_MODEL.md` for the complete persistence inventory.

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

Flow statistics and day history are derived from FlowSession actual focus seconds. Task statistics use `Todo.completedAt`, with `updatedAt` as a legacy date fallback. Legacy completed Todos without `completedAt` are displayed without an invented clock time.

`DayHistoryBuilder` produces daily Task/Direction aggregates. `HistoryCalendarBuilder` projects actual FlowSession, FlowSegment, FlowBreak, exact Todo completions, and legacy untimed completions into date-range calendar items without persistence; pending Tasks are excluded. `HistoryDayTimelineWindowBuilder` derives the day view's Elastic/full-day hour range, while `HistoryOverlapLayout` assigns lanes to colliding actual or minimum-visual intervals independently from SwiftUI. `FlowHistoryEditor` corrects Direction and measured Todo totals when a historical Flow is changed or deleted.
