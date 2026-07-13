# UX Flows

## 方向

The Direction screen manages only user-editable Directions:

- `通常`;
- `習慣`;
- `ナイス`.

The system Direction `その他` is not shown here and cannot be edited from this screen.

## タスク

タスク shows scheduled tasks for the current day.

Calendar ranges:

- `1日`: detailed list for the selected date;
- `3日`: three kanban columns;
- `7日`: seven horizontally scrollable kanban columns;
- `月`: month grid with completion counts, Direction dots, and incomplete Habit markers.

Filters are `すべて`, `タスク`, and `習慣`. Habit instances stay in the same calendar as normal Tasks but remain visually separated.

Active normal Tasks can be dragged between day columns. Month remains an overview and opens a day for detailed actions. Completed Tasks and fixed daily/weekday Habit Tasks stay on their original date. Weekly-count Habit moves are validated against the remaining weekly target.

Clicking a month cell opens that date in `1日`. The quick composer follows the selected date or kanban column.

Sections:

- `習慣`: automatically generated habit tasks;
- `通常`: normal scheduled tasks;
- `ナイス`: optional positive tasks.

Task rows:

- empty title displays `(方向)` in a translucent italic style;
- completed tasks are visually muted, struck through, and sorted below active tasks;
- Direction color is used unless the Direction is `その他`;
- `チェック` shows a checkbox;
- `集中ブロック` shows a filling ring;
- `分` shows minute progress.

Quick capture behaves like a messenger composer. The user can set measurement, Direction, priority, and date from compact controls.

There is no separate Inbox navigation item. Date-less task behavior is deferred.

Weekly-count habits create one pending task at a time. After completion, the next instance may appear on a later eligible day until the weekly target is met. Moving the pending instance does not create a replacement for today, and dates that would make the target impossible are disabled.

Daily and selected-weekday Habit instances are generated for visible current/future dates. Weekly-count habits are not expanded across future calendar columns.

## Flow Player

`Flow` is the first/default navigation item. In a wide window, its dashboard uses one aligned two-column grid: the animated daily stream and 0:00–24:00 timeline sit above today's Tasks on the left, while the equally tall square player sits above compact Statistics on the right. All lower Task, Habit, optional Nice, and Statistics panels share the height of the tallest lower panel. The left side occupies roughly three quarters of the content. Other app sections keep the player available as a top header; the dashboard does not show a duplicate header.

The header layout is:

- left Task card with Direction icon, Task title, and smaller Direction name;
- Task card opens a picker with `タスク`, `習慣`, and `方向` tabs;
- `タスク` and `習慣` use separate lists of today's items;
- `方向` uses an emoji-and-name grid with `その他` first for Direction-only starts;
- Direction icon color follows the selected Task Direction;
- compact Focus selector opens a separate picker for `Short`, `Focus`, and `Deep`;
- timer and transport controls on the right.

Mode labels:

- `Short 12/3`;
- `Focus 25/5`;
- `Deep 50/10`.

Flow can be started with a selected Task, with only a Direction, or with neither. If no Direction is chosen, the resolved Direction is `その他`.

At the planned focus end, Flow does not auto-switch. The timer continues. The user chooses:

- continue;
- start break;
- stop.

Start break opens a memo prompt. Focus time keeps counting until memo is saved. The memo writes to the Todo.

The daily stream is formed by very broad, bright, softly glowing translucent ribbons. It moves gently and smoothly while idle, immediately accelerates when any Flow starts, then gains speed, volume, layers, and Direction colors as focused Blocks accumulate, reaching its visual maximum at 6 Blocks. Short uses energetic waves, Focus balanced waves, and Deep broad slow bends; the background tint follows the selected mode. The current Flow appears live after its first creditable minute. Reduce Motion keeps the visualization static. Selecting a completed timeline segment opens the existing Flow history inspector.

Below the Flow stage are today's `タスク` and `習慣` columns. `ナイス` is omitted when empty. Rows use the same square Check and circular Block/Minute progress controls as the Tasks screen, and can be completed or opened for editing. A compact `統計` panel shows today's completion rate and Direction focus distribution.

Dashboard Task columns do not contain an add button. In the player Task picker, the `タスク` tab has a trailing `+` beside the segmented control. It morphs into the shared messenger-style composer inside the same popover with Direction, measurement, and priority controls; its date is fixed to `今日`. The new Task is immediately selected for Flow. Habit has no manual add action.

## Statistics

Statistics uses a contribution grid.

Modes:

- `Tasks`: completed tasks;
- `Flow`: focused Block activity.

Ranges:

- current month;
- last 180 days;
- calendar year.

The `その他` Direction may appear in statistics and filters because it represents real captured work.

Selecting any contribution cell switches the app navigation to the single canonical `履歴` section for that day. Statistics never embeds a duplicate Day History view.

Hovering a cell shows its date, completed Task count, Flow count, Blocks, and focused duration. `今月` is arranged as a seven-column month calendar; `180日` uses larger contribution cells than the year view.

## Day History

`履歴` is available directly below `タスク`, owns Day History presentation, and initially opens today. It preserves the date selected from Statistics. The user can move one day backward or forward or choose a date.

- `タイムライン`: chronological Flow sessions and completed Tasks.
- `タスク`: focus totals grouped by Task.
- `方向`: focus totals grouped by Direction.

Completed Tasks with an exact completion timestamp appear in chronology. Legacy completions without one appear under `完了時刻なし`. Selecting a Flow opens its inspector for correction or deletion.
