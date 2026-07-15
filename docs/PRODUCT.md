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

The stream is a field of broad, bright, softly glowing translucent ribbons rendered on the GPU around one shared S-shaped channel with three levels of depth. It remains smooth while idle and immediately accelerates when Flow starts. Its occupied area stops growing at 4 Blocks so dark moving channels preserve the silhouette; progress through 6 Blocks instead adds internal detail, parallax, saturation, and motion. A restrained light pulse crosses the stream at each completed half-Block. Short, Focus, and Deep change the wave character, while a subtle mode-specific tint is applied to the dashboard. Below it, today's normal Tasks and Habits remain actionable with the same Check, Block, and Minute indicators as Tasks; Nice appears only when present, and compact Statistics show total focused time distributed across Tasks.

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

`履歴` is the single canonical History surface and a dedicated navigation item below `タスク`. Clicking a statistics cell switches navigation to this section on that date; Statistics does not embed another history view.

It provides a primary `カレンダー` mode with `日・週・月`, plus `タスク` and `方向` aggregates. Day uses a narrow Apple Calendar-style timeline with a persisted `Elastic | 24時間` scale and a right mini-calendar/properties inspector. Week uses a vertically scrolling 24-hour grid with fixed headers; month is an overview. Calendar blocks represent separate actual Flow and rest records; the continuous series line belongs only to the Flow dashboard timeline. Todo completion remains in Task summaries and Statistics. Historical Flow and rest entries open their canonical editors. Double-clicking empty time creates a manual independent Flow, never a manual rest. Historical Flow changes must adjust Direction totals and measured Todo progress by the same delta.
