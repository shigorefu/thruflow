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

## D-005: Inbox Is Date-less Tasks

`scheduledDate == nil` means Inbox. Inbox tasks do not appear in 今日.

Reason: date-less tasks should not automatically become daily noise.

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

## Open Questions

- What measurement and planned amount should be used for an auto-created Task when Flow starts with only a Direction or with neither Direction nor Task?
- Should Adaptive/Auto Flow remain, or should MVP expose only Short, Focus, and Deep?
- How exactly should the “continue for longer break” prompt behave when less than 5 minutes remain to the next threshold?
- What is the exact meaning of deleting the “last 1 Block” from a Flow series?
- How should the 4-Block long-break series counter be represented and reset?
