# Domain Model

This document defines the durable product model for ThruFlow. SwiftData implementation details may evolve, but the terminology and relationships should stay stable.

## Direction

`Direction` is the central persistent object. In Japanese UI it is displayed as "方向".

A Direction represents an area of activity, habit-like commitment, category of work, or life domain.

Examples:

- Work
- Anki
- Reading
- IT
- Training
- Cleaning
- AWS
- Japanese

### Direction Type

`DirectionType` has stable raw values:

- `must`: required direction that can affect Today and successful day completion.
- `neutral`: optional work direction; its Todos matter only when manually created or planned.
- `bonus`: positive optional direction; activity counts as an extra positive result but never blocks day completion.

Neutral must never be framed as bad or unimportant. Bonus must never be framed as required.

### Direction Goal Rule

A Direction may have an optional goal rule.

Supported periods:

- `daily`
- `weekly`
- later: `monthly`

Supported units:

- `occurrences`
- `focusBlocks`
- `minutes`
- `hours`

Examples:

- Anki: 1 focus block daily.
- Reading: 1 focus block daily.
- IT: 2 focus blocks daily.
- Training: 3 occurrences weekly.
- Japanese: 5 hours weekly.

Weekly goals are evaluated by week totals. Empty individual days do not automatically mean an unsuccessful day.

## Todo

`Todo` is a concrete one-time task. Every Todo belongs to exactly one Direction.

Fields:

- stable `id`;
- `title`;
- `direction`;
- optional `notes`;
- `createdAt`;
- `updatedAt`;
- optional `scheduledDate`;
- optional `deadline`;
- planned amount;
- actual progress;
- status;
- reschedule support;
- archive or soft delete support.

Todos can be measured by:

- checkbox completion;
- focus blocks;
- minutes.

A Todo must not automatically become a Habit or Direction.

## Today

`Today` is not a separate permanent habit database. It is a view of the current daily plan.

It combines:

- Must goal items generated from Direction rules;
- manually added or scheduled Todos;
- planned weekly Direction occurrences;
- carried tasks;
- Bonus activities.

Minimum sections:

- Must
- Tasks
- Bonus

Neutral Directions do not appear in Today by themselves. Their Todos appear only when created or scheduled.

## Successful Day

A day is complete when every Must requirement that applies to that day is complete.

Non-required Todos and Bonus items do not block day completion.

Weekly goals enter the required daily list only when:

- the user explicitly scheduled the weekly goal for today;
- deterministic rules show that the goal cannot otherwise be completed by week end;
- a later strict planning mode is enabled.

When a day first transitions to complete, one `DailyCompletion` event is recorded. Reopening an already complete day must not replay the reward event.

## FlowSession

`FlowSession` represents one focused work segment.

Fields:

- stable `id`;
- `direction`;
- optional `todo`;
- `intent`;
- optional `result`;
- `startedAt`;
- optional `endedAt`;
- planned duration;
- actual duration derived from start/end times;
- mode;
- status;
- completion or interruption metadata;
- `createdAt`;
- `updatedAt`.

Intent answers "What am I going to do?" Result answers "What actually happened?" These fields must stay separate.

## Flow Modes

Stable mode raw values:

- `twelveThree`
- `twentyFiveFive`
- `fiftyTen`
- `adaptive`
- future: `recovery`

Adaptive Flow uses one session whose planned duration can extend through:

- 12 minutes;
- 25 minutes;
- 50 minutes.

Extending an Adaptive Flow must not create a second FlowSession.

## Flow Cycle

A Flow cycle is different from:

- completing one FlowSession;
- completing a large work cycle;
- completing the daily Must plan.

These events must remain distinct in the model.

## Timeline Segment

The continuous timeline is deferred from MVP 0.1, but the model must not block it.

Future segment types:

- focusFlow;
- workWithoutTimer;
- rest;
- meal;
- sleep;
- commute;
- games;
- socialMedia;
- household;
- exercise;
- unknown;
- custom.

Unknown time is acceptable and not an error. FlowSession must link to a timeline segment or become its specialized representation without double-counting duration.

## CloudKit and Optionality

For MVP 0.1, SwiftData should be local-first. Models should use stable UUIDs, stable enum raw values, and archive/delete timestamps where history matters.

CloudKit compatibility argues for careful schema evolution:

- avoid using display names as identifiers;
- prefer optional fields for data that may be introduced later;
- avoid making future CloudKit migrations depend on destructive changes;
- still keep fields non-optional when the domain genuinely requires them, such as a Todo's title and Direction relationship.
