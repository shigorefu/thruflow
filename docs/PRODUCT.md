# Product

ThruFlow / スルフロ records focused work and turns it into visible task progress.

Core loop:

```text
方向 -> Task -> Flow -> focused time -> progress -> statistics
```

## 方向

`方向` is a persistent area of activity.

- `通常`: normal area. No automatic daily task.
- `習慣`: scheduled recurring requirement. Creates automatic habit tasks.
- `ナイス`: optional positive activity. Does not block day completion.
- `その他`: system Direction for tasks/flows without a chosen Direction. It is hidden only from Direction management, not from statistics.

## Tasks

Tasks are the daily Todo surface.

Task title may be empty. When empty, UI displays `(方向)`, for example `(読書)` or `(その他)`.

The screen is named `タスク`. There is no separate Inbox navigation item; date-less Task behavior is deferred.

`タスク` supports `1日`, `3日`, `7日`, and `月` calendar ranges. The multi-day modes are kanban boards, while the month mode is a calendar overview. Filters show all work, normal Tasks, or Habit instances. Active Tasks can be moved between dates subject to Habit rules.

Weekly-count Habits create one pending Task at a time. Completion allows the next instance on a later day, while moving the pending Task never creates a duplicate or makes the weekly goal impossible.

Task completion:

- `チェック`: user checks it.
- `集中ブロック`: accumulated focused time reaches planned Blocks.
- `分`: accumulated focused minutes reaches planned minutes.

## Flow

Flow is a media-player-like recorder.

`Flow` is the first/default navigation section and today's primary dashboard. In wide layout, one grid aligns the stream/timeline above Tasks on the left and the square player above Statistics on the right. The left column occupies roughly three quarters of the content. Direction colors compose the stream palette, while focus duration and session count control its visual volume.

The stream is a field of very broad, bright, softly glowing translucent ribbons rendered on the GPU. It remains smooth while idle, immediately accelerates when Flow starts, and gains movement, volume, and saturation from today's focused Blocks, reaching its visual maximum at 6 Blocks. Short, Focus, and Deep change the wave character, while a subtle mode-specific tint is applied to the dashboard. Below it, today's normal Tasks and Habits remain actionable with the same Check, Block, and Minute indicators as Tasks; Nice appears only when present, and compact Statistics show completion and Direction focus distribution.

Modes:

- `Short`: 12 focus / 3 break = 0.5 Block.
- `Focus`: 25 focus / 5 break = 1 Block.
- `Deep`: 50 focus / 10 break = 2 Blocks.

Focus does not auto-stop or auto-switch to break. Break starts only after the user confirms memo. Memo is stored on Todo, not FlowSession.

The active creditable Flow updates the dashboard live. Completed timeline segments open the existing historical Flow inspector.

## Statistics

Statistics use a contribution-style grid.

- `Flow`: Blocks per day.
- `Tasks`: completed Tasks per day.

Ranges:

- current month;
- last 180 days;
- current calendar year.

Cell brightness is relative to the maximum day in the selected range.

## History

`履歴` is the single canonical Day History surface and a dedicated navigation item below `タスク`. Clicking a statistics cell switches navigation to this section on that date; Statistics does not embed another history view.

It provides `タイムライン`, `タスク`, and `方向` modes with a daily summary of focus time, Blocks, Flow count, and completed Tasks. Historical Flow entries may be corrected or deleted; Direction totals and measured Todo progress must be adjusted by the same delta.
