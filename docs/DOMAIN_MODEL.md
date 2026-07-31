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

A Habit Direction may also contain one or more paused local-day intervals.
Paused days are ineligible for automatic Todo generation and weekly rescheduling.
Pausing soft-deletes only generated occurrences that have not been completed and
have no measured progress or Flow history. Existing completed/progressed records
remain intact. Resuming re-enables planning from the current logical day.

## Todo

`Todo` is the task model used by the daily `タスク` screen.

Important fields:

- `title`: may be empty;
- `notes`: Todo memo;
- `hashtags`: ordered display tags decoded from optional persistence; normalized without `#` and unique case-insensitively;
- `direction`: resolved Direction, usually never nil in app-created data;
- `measurement`: checkbox, focus blocks, or minutes;
- `priority`: high, medium, low;
- `isRoomIfPossible`: only meaningful for low priority;
- `scheduledDate`: optional task date; nil places an active normal Task in the `日付なし` projection;
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

`mode` records the explicitly selected `Sprint`, `Focus`, or `Deep` preset; it
is not inferred again from elapsed time. Changing mode replaces the total
planned focus duration without resetting elapsed focus. The two seek operations
adjust remaining focus by `-5` or `+5` minutes and preserve both elapsed focus
and mode; subtraction is clamped to one minute remaining and seek is unavailable
during rest. Actual focused seconds remain canonical for history, progress, and
rest calculation. Rest is 3 minutes below 24 focused minutes, 5 minutes from 24
through 48:59, and 10 minutes from 49 minutes onward. Boundary credit normalizes
24 to 25 and 49 to 50 focused minutes; longer actual durations remain exact.

`FlowSession.result` stores the result/memo of that exact Flow recording. This
keeps Direction-only Flow editable and descriptive without inventing a Todo.
When a Flow is linked to a Todo, the current completion/editor workflow also
mirrors the text to `Todo.notes` for the Task-level memo.

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

Every Habit Direction has at most one active Todo occurrence per local calendar day. `HabitTodoMaterializer` is the shared macOS/iOS entry point: it fetches current persisted state, normalizes occurrence dates to the start of day, reconciles duplicates, and only then asks `RequiredTodoPlanner` to create missing occurrences. `HabitTodoReconciler` deterministically preserves the occurrence with history or completion state, reassigns related FlowSession and FlowSegment records, merges user data and progress, and soft-deletes the redundant occurrences. This makes repeated calls and CloudKit race recovery idempotent.

`HabitPauseService` owns pause/resume behavior outside SwiftUI. Pause intervals
use the configured logical-day boundary at their command edge and persist as
normalized local calendar days. Supported commands are one-day rest, inclusive
date-range pause, indefinite pause, and resume. Overlapping or adjacent periods
are merged deterministically.

## Task Calendar

`TaskCalendarBuilder` creates deterministic day, seven-day week, and month-grid date ranges. `TaskRescheduleService` validates calendar drag-and-drop independently from SwiftUI.

Normal active Tasks may change `scheduledDate`. Completed Tasks and fixed daily/weekday Habit instances cannot move. Weekly-count Habit movement delegates to `RequiredTodoPlanner` feasibility rules.

`TaskBacklogBuilder` derives active overdue and undated normal Tasks. It excludes completed, archived, deleted, and Habit Todos. Overdue is evaluated against the calendar start of today so time-of-day and time-zone differences do not change membership.

## Statistics

Flow statistics and day history are derived from FlowSession actual focus seconds. Task statistics use `Todo.completedAt`, with `updatedAt` as a legacy date fallback. Legacy completed Todos without `completedAt` are displayed without an invented clock time.

Paused Habit days do not contribute a planned Todo, so they are excluded from
the completion-rate denominator and never count as missed. Previously completed
Todos and actual Flow recorded for that Habit remain visible in history and
focused-time statistics.

`DayHistoryBuilder` produces daily Task/Direction aggregates. Its Task summaries require positive recorded focused time, so scheduled or completed Todos with `0分` never appear as worked History on either platform. `HistoryTaskRecordEditor` separately resolves eligible Todo occurrences for one exact day, including zero-Flow occurrences, and owns cross-platform retrospective recording. It can materialize a missing historical Habit occurrence directly from an eligible Habit Direction without disturbing the planner's current pending occurrence. Task context preserves unit semantics: Check updates manual completion at an optional historical timestamp without creating Flow, while Block or Minute delegates to `FlowHistoryEditor` and reconciliation. Flow context always creates a completed independent Flow and treats the selected Todo as an optional link, so linking a checkbox Todo never completes it. Direction context creates Flow without a Todo. `HistoryCalendarBuilder` projects actual FlowSession, FlowSegment, and FlowBreak records into separate date-range calendar items without persistence; Todo completion remains aggregate data rather than a calendar item. `FlowDashboardBuilder` derives connected `seriesSpans` from `seriesID` for the dashboard's continuous line without changing calendar records. `DashboardStatisticsBuilder` derives Task/Direction time distribution, seven-day Flow values, previous-day deltas, completion status, and Direction growth without persistence. `HistoryDayTimelineWindowBuilder` derives the day view's Elastic/full-day hour range, while `HistoryOverlapLayout` assigns lanes to colliding actual or minimum-visual intervals independently from SwiftUI. `FlowHistoryEditor` creates independent manual Flow records and corrects Direction and measured Todo totals when a historical Flow is changed or deleted.
