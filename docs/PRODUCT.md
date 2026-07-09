# Product

ThruFlow / スルフロ is a personal attention-management app for Apple platforms.

It combines:

- Directions: recurring areas of life or work.
- Todos: concrete one-time tasks inside a Direction.
- Flow sessions: focused work segments with intent and result.
- Must, Neutral, and Bonus goal categories.
- Daily and weekly norms.
- A future continuous day timeline.
- History and statistics.
- Future AI summaries.

## Canonical Block

The canonical productivity unit is:

`1 Block = 25 focused minutes`.

Breaks are excluded. Blocks are computed from actual focus duration and are not stored as standalone completed entities. `FlowSession` stores what actually happened; Todo and Direction progress accumulate focus duration and display it as Blocks.

MVP display uses product-friendly values:

- 12 focused minutes: `0.5 Block`;
- 24 focused minutes: `1 Block`;
- 25 focused minutes: `1 Block`;
- 37 focused minutes: `1.5 Blocks`;
- 50 focused minutes: `2 Blocks`.

For block-based tasks, do not show raw minute totals like `24分 / 2 Blocks`. Exact minute accounting belongs to the `分` record type.

## Product Principle

ThruFlow trains returning to work. It must not punish distraction, breaks, or uneven work patterns.

A user may complete one block in the morning, one at lunch, and two in the evening. If the required Must volume is complete by the end of the day, the app treats the day as successfully completed.

## Tone

The product voice is:

- calm;
- supportive;
- concrete;
- non-infantile;
- non-accusatory.

The app must not use red-screen failure language, punishment framing, or streak destruction as its primary motivator.

## Platforms

MVP development is iPhone-first. iPad and macOS should remain viable through SwiftUI layout choices and shared domain logic.

## Language

Default user-facing language is Japanese. Code identifiers, stable raw values, and internal technical documentation stay English unless they are directly shown to the user.

Deferred platforms:

- Apple Watch;
- widgets;
- Live Activities;
- Shortcuts;
- web client;
- AWS backend.

## Product Boundaries

ThruFlow is not:

- a pure Pomodoro app;
- a standalone habit tracker;
- a generic todo list;
- a social productivity app;
- an AI automation tool in MVP 0.1.

The first release should prove the core loop: define Directions, plan Today, run Flow, record progress, and determine whether the required day is complete.
