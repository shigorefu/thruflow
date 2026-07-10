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

Weekly-count Habits create one pending Task at a time. Completion allows the next instance on a later day, while moving the pending Task never creates a duplicate or makes the weekly goal impossible.

Task completion:

- `チェック`: user checks it.
- `集中ブロック`: accumulated focused time reaches planned Blocks.
- `分`: accumulated focused minutes reaches planned minutes.

## Flow

Flow is a media-player-like recorder.

Modes:

- `Short`: 12 focus / 3 break = 0.5 Block.
- `Focus`: 25 focus / 5 break = 1 Block.
- `Deep`: 50 focus / 10 break = 2 Blocks.

Focus does not auto-stop or auto-switch to break. Break starts only after the user confirms memo. Memo is stored on Todo, not FlowSession.

## Statistics

Statistics use a contribution-style grid.

- `Flow`: Blocks per day.
- `Tasks`: completed Tasks per day.

Ranges:

- current month;
- last 180 days;
- current calendar year.

Cell brightness is relative to the maximum day in the selected range.
