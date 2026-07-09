# UX Flows

ThruFlow should make the common path fast and calm. The app should reduce friction before a Flow while still capturing enough structured data for future history and AI summaries.

## Today

Today is the primary daily screen.

Sections:

- 習慣: recurring Direction goals that apply today and are generated automatically.
- 通常: scheduled or manually added Todos.
- ナイス: optional positive activities.

Today should show progress in concrete terms:

- Anki: 0/1 block
- Reading: 0/1 block
- IT: 1/2 blocks
- Prepare slides: 1/3 blocks

Empty states should suggest creating a Direction or Todo without implying the day has failed.

Today tasks are visually grouped by Direction type:

- 習慣;
- 通常;
- ナイス, only when there are Nice tasks.

Generated Habit tasks start as editable task fields with the Direction in the placeholder, so the user can replace "タスク (読書)" with a concrete book or action.

Quick task capture uses a bottom composer. The description field is the primary surface, with Direction, priority, date, and record-type controls in the lower row. Direction is displayed as full emoji plus Direction name, not emoji alone. Record type controls the trailing visual: checkbox for `チェック`, a filling ring for `ブロック`, and a remaining-time ring for `分`.

## Direction Management

Core actions:

- list Directions;
- create Direction;
- edit name, type, symbol, color, and goal;
- archive Direction.

Validation:

- name is required;
- Direction type is required;
- goal values must be positive when a goal is enabled.

Archived Directions should not appear in normal creation pickers unless the UI explicitly supports viewing archived data.

## Todo Management

Core actions:

- create Todo inside a Direction;
- set measurement type;
- set planned target;
- update progress or checkbox status;
- schedule or reschedule;
- archive or delete without damaging historical Flow sessions.

Neutral Direction Todos may be moved, edited, or removed without affecting successful day completion.

## Starting Flow

The start path should be short:

1. Choose Direction.
2. Choose Todo when relevant.
3. Enter Intent.
4. Choose mode.
5. Start.

Quick-start affordances should later support:

- last Direction;
- last Todo;
- recent Intents;
- continuing the previous task;
- "just start" using Adaptive Flow.

## During Flow

Basic controls:

- Start;
- Pause;
- Resume;
- Stop and save focused time;
- Destroy the current Flow without saving progress.

The timer should derive actual duration from timestamps, not only in-memory ticks.

## Finishing Flow

After finish, prompt gently for Result. Result can be optional, but the interface should make it clear that capturing the result improves history.

Finishing a Flow may update Direction and Todo progress based on deterministic rules, but AI must never close a Todo without user confirmation.

Stopping a Flow also preserves the focused time and opens the same memo prompt. The memo is stored as the FlowSession result.

On macOS, the menu bar label for an active Flow should show the current context as `Direction emoji: task name - remaining time`.

## Adaptive Flow

Adaptive Flow starts at 12 minutes.

At 12 minutes, offer:

- continue 13 minutes;
- rest 3 minutes;
- finish.

At 25 minutes, offer:

- continue 25 minutes;
- rest 5 minutes;
- finish.

At 50 minutes, offer:

- rest 10 minutes;
- finish.

All extensions belong to the same FlowSession.

## Statistics

Statistics is a separate app section. The main view uses a contribution-style heatmap with a segmented control for `達成` and `Flow`.

Filters:

- period: 90 days, 180 days, or 1 year;
- Direction: all Directions or one selected Direction.

Each cell represents one local calendar day. In `Flow`, cell intensity represents total focused time. In `達成`, cell intensity represents completed task count. If multiple Directions contributed on the same day, the cell uses a weighted color mix based on the selected mode.

## Day Completion Feedback

When the day first becomes complete, record one DailyCompletion event and show a simple visual feedback in MVP.

Do not replay the reward every time the app opens an already completed day.

## Accessibility

MVP UI should be compatible with:

- Light Mode;
- Dark Mode;
- Dynamic Type;
- VoiceOver;
- Reduce Motion;
- Reduce Transparency.
