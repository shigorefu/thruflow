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

`タスク` supports `日`, `週`, and `月` calendar ranges. Day uses a compact seven-day strip above the Task list and opens a full month only in a date-picker popover. Week is a seven-column kanban, while month is a calendar overview. Filters stay centered and `今日` remains prominent. Active Tasks can be moved between dates subject to Habit rules.

Weekly-count Habits create one pending Task at a time. Completion allows the next instance on a later day, while moving the pending Task never creates a duplicate or makes the weekly goal impossible.

Task completion:

- `チェック`: user checks it.
- `集中ブロック`: accumulated focused time reaches planned Blocks.
- `分`: accumulated focused minutes reaches planned minutes.

## Flow

Flow is a media-player-like recorder.

`Flow` is the first/default navigation section and today's primary dashboard. In wide layout, one grid aligns the stream/timeline above Tasks on the left and the square player above Statistics on the right. The left column occupies roughly three quarters of the content. Direction colors compose the stream palette, while focus duration and session count control its visual volume.

The stream is a field of broad, bright, softly glowing translucent ribbons rendered on the GPU around one shared S-shaped channel with three levels of depth. It remains smooth while idle and immediately accelerates when Flow starts. Its occupied area stops growing at 4 Blocks so depth, transparency, and motion preserve the silhouette without black carved stripes; progress through 6 Blocks instead adds internal detail, parallax, saturation, and motion. A restrained light pulse crosses the stream at each completed half-Block. Short, Focus, and Deep change the wave character, while a subtle mode-specific tint is applied to the dashboard. Below it, today's normal Tasks and Habits remain actionable with the same Check, Block, and Minute indicators as Tasks; Nice appears only when present. Fixed-height compact Statistics form a three-page carousel for Task/Direction time distribution, a seven-day Flow trend with day-over-day deltas, and today's completion status.

Modes:

- `Short`: 12 focus / 3 break = 0.5 Block.
- `Focus`: 25 focus / 5 break = 1 Block.
- `Deep`: 50 focus / 10 break = 2 Blocks.

Focus does not auto-stop or auto-switch to break. Break starts only after the user confirms memo. The dashboard and menu bar use the same square memo panel with cancel, no-memo, and save actions. Memo is stored on Todo, not FlowSession, and rest completion never prompts again. The rest timer ring is neutral gray and drains while the focus ring fills with the selected Direction color.

Flow sessions may share a stable series ID when the next session starts within 1.5 times the planned rest. The next rest after each 4 accumulated Blocks is a 20-minute Long Break with a 30-minute continuation window. History preserves separate Flow and rest records; only the dashboard renders their series as one continuous rail.

The active creditable Flow updates the dashboard live. Completed timeline segments open the existing historical Flow inspector.

Flow may start with a Task, only a Direction, or neither. Direction-only work is persisted without an implicit Todo; work without either resolves to system `その他`. Automatic Task creation is deferred until its measurement and planned amount have explicit defaults.

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

It provides a primary `Flow` calendar mode with `日・週・月`, plus `タスク` and `方向` aggregates. Day uses a narrow Apple Calendar-style timeline with an Elastic scale and a right mini-calendar/properties inspector. Week uses a vertically scrolling 24-hour grid with fixed headers; month is an overview. Calendar blocks represent separate actual Flow and rest records; the continuous series line belongs only to the Flow dashboard timeline. Completed Flow records can be dragged between exact day/time positions in day and week, or between dates in month; the session and all task-switch segments preserve their duration and progress. Active Flow and rest records remain fixed. Todo completion remains in Task summaries and Statistics. Historical Flow and rest entries open their canonical editors. Double-clicking empty time creates a manual independent Flow, never a manual rest. Historical Flow changes must adjust Direction totals and measured Todo progress by the same delta. Linking a manual Flow to a Task does not automatically complete it.
