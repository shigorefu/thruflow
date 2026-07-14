# ThruFlow Data Model

This document is the canonical inventory of persisted application data. ThruFlow uses local SwiftData as the primary store. CloudKit capability does not change or gate local persistence.

## Persistence Rules

- Every domain record has a stable `UUID` identifier.
- Enum values are persisted through stable English raw values.
- Historical records use archive or soft-delete timestamps where removal must not destroy reporting context.
- `FlowSession`, `FlowSegment`, and `FlowBreak` preserve exact seconds and dates. Blocks and dashboard values are derived projections.
- A Flow series is a lightweight UUID association. Its sessions are not merged into one database row.

## Direction

`Direction` groups work and supplies the emoji, color, behavior type, goal, schedule, and accumulated progress.

Persisted data includes:

- identity, name, emoji, color, and sort order;
- type (`neutral`, `habit`, or `nice`);
- goal unit, target, period, and schedule configuration;
- accumulated occurrences, focused seconds, and supporting progress state;
- creation/update timestamps and archive state.

System Direction `その他` is stored like other Directions but hidden from Direction management.

## Todo

`Todo` is the actionable record for both manually created Tasks and generated Habit instances.

Persisted data includes:

- identity, title, notes (`メモ`), Direction, and scheduled date;
- priority and optional `余裕があれば` state;
- measurement type (`check`, `focusBlocks`, or `minutes`), planned amount, actual progress, and focused seconds;
- active/completed status, completion timestamp, generation metadata, and sort order;
- creation/update timestamps and deletion state.

User-facing Flow memo is stored on `Todo`, not on a new memo entity. `FlowSession.result` remains only for migration compatibility.

## FlowSession

`FlowSession` stores one focused-work recording.

Persisted data includes:

- `id` and optional migration-safe `seriesID`;
- current Direction and optional Todo;
- intent and legacy result text;
- Flow mode, phase, and status raw values;
- start, planned end, actual end, and create/update timestamps;
- planned and actual focus seconds, planned break seconds, pause duration, pause flag, and interruption count;
- a cascade relationship to its `FlowSegment` records.

Existing records with no `seriesID` are treated as a one-session series whose ID is the session ID.

## FlowSegment

`FlowSegment` stores a Task/Direction interval inside one `FlowSession`. Switching Task during focus closes one segment and opens another without resetting the timer.

Persisted data includes:

- identity and parent FlowSession;
- Direction and optional Todo used in that interval;
- wall-clock start/end dates;
- cumulative focused-second offsets at start/end.

The focused offsets exclude pauses and provide deterministic progress attribution.

## FlowBreak

`FlowBreak` stores an explicit rest between Flow sessions.

Persisted data includes:

- identity and `seriesID`;
- previous FlowSession ID and optional next FlowSession ID;
- rest start, timer-stop, series-connection, and optional manually adjusted end timestamps;
- planned rest duration and Long Break flag;
- creation/update timestamps and soft-delete timestamp.

The continuation deadline is derived as `startedAt + plannedDurationSeconds × 1.5`. A next Flow started on or before that deadline receives the same `seriesID`; a later Flow starts a new series. `connectedUntil` stores the original series connection point. Optional `adjustedEndAt` stores a historical duration correction without rewriting the planned break used by product policy.

When an adjusted end overlaps the next session, `FlowBreakEditor` shifts that session and every later FlowSession, FlowSegment, and FlowBreak in the same series by the overlap. Other series are never shifted. A shorter duration leaves a gap rather than pulling later history backward.

Normal continuation windows are:

| Flow size | Planned break | Series window |
| --- | ---: | ---: |
| Short | 3 min | 4 min 30 sec |
| Focus | 5 min | 7 min 30 sec |
| Deep | 10 min | 15 min |
| Long Break | 20 min | 30 min |

A 20-minute Long Break is selected after each additional 4 accumulated Blocks in the same series. It still starts only when the user manually starts rest.

## Transient And Derived Data

The following are not separate database entities:

- `FlowTimerState`: in-memory active timer state;
- dashboard stream shape, speed, palette, totals, and timeline geometry;
- contribution-grid cells, calendar items, overlap lanes, and history sections;
- Block display values derived from exact focused seconds;
- the Flow series itself, which is reconstructed from `seriesID`, `FlowSession`, and `FlowBreak` records.

The active timer is restored from absolute timestamps and persisted FlowSession fields where supported; decorative animation state is never persisted.

`履歴` does not add a calendar table. `HistoryCalendarBuilder` projects `FlowSession`/`FlowSegment` as timed focus entries and `FlowBreak` as timed rest entries. Completed and pending Todos are excluded from calendar projection; completion timestamps remain available to Task statistics and summaries. Calendar range, day `Elastic | 24時間` preference, selected inspector item, filtering, responsive breakpoints, scroll position, compact rendering, minimum visual duration, and overlap lanes are presentation state.
