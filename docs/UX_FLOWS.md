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

`Flow` is the first/default navigation item. In a wide window, its dashboard uses one aligned two-column grid: the animated daily stream and 0:00–24:00 timeline sit above today's Tasks on the left, while the equally tall square player sits above compact Statistics on the right. All lower Task, Habit, optional Nice, and Statistics panels share one height and stretch to the bottom of the viewport; short windows retain a minimum lower-row height and scroll vertically. The left side occupies roughly three quarters of the content. Other app sections do not repeat the player as a top header; the macOS menu bar opens this same square player. A horizontal compact menu-bar layout is retained in product documentation as a deferred design only and is not part of the current UI.

The player layout is:

In the narrow vertical dashboard layout, the player comes first, followed by the Flow stream/timeline, Tasks/Habits, and Statistics. The narrow player and Flow stage use stable heights so resizing does not reorder controls or cause layout jumps.

- left Task card with Direction icon, Task title, and smaller Direction name;
- Task card opens a picker with `タスク`, `習慣`, and `方向` tabs;
- `タスク` and `習慣` use separate lists of today's items;
- `方向` uses an emoji-and-name grid with `その他` first for Direction-only starts;
- Direction icon color follows the selected Task Direction;
- compact Focus selector opens a separate picker for `Short`, `Focus`, and `Deep`;
- selecting another Focus mode during focus or pause preserves elapsed time and only moves the planned end, matching the seek controls;
- break time counts down past zero with a positive overtime sign; its progress ring drains while the focus ring fills. Starting work during rest completes the previous Flow and immediately starts the next one, while menu bar status becomes `☕️ 休憩 - time` or `☕️ Long Break - time`;
- choosing another Task during focus or pause keeps the current Flow running and starts a new history segment; no memo prompt is shown for this switch;
- the Task card reuses the canonical completion/progress control and shows remaining Blocks or Minutes;
- generated titles for empty Tasks and Habits are consistently italic and visually muted in the player, picker, Tasks screen, and dashboard panels;
- dashboard `タスク` rows show priority before progress, including `余裕があれば` for low-priority optional work; fixed Habit priority is not displayed;
- the centered dashboard completion donut uses Direction-colored segments for completed items and leaves the remaining daily plan as a neutral track;
- double-clicking the selected Task title edits it inline; Enter or focus loss saves and Escape cancels. Double-click recognition is limited to the visible title bounds so the rest of the Task card opens the picker immediately;
- the Task card provides the same short pressed-state feedback as the Focus selector without changing its single/double-click actions;
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

The daily stream is formed by very broad, bright, softly glowing translucent ribbons. Today's focused Blocks permanently amplify movement until the day changes, reaching their visual maximum at 6 Blocks. Idle stays in a calm `0.06...0.28` speed range, from very slow to moderately slow; an active Flow uses a separate `1.10...2.80` range so accumulated daily progress becomes much more visible while working. Volume, layers, and Direction colors also grow from recorded activity. Short uses energetic waves, Focus balanced waves, and Deep broad slow bends; the background tint follows the selected mode. The current Flow appears live after its first creditable minute. Reduce Motion keeps the visualization static. Selecting a completed timeline segment opens the existing Flow history inspector.

The timeline defaults to a locally persisted `Elastic` scale, with `24時間` available in a segmented control. An empty Elastic timeline covers the current full hour and the following hour. Once activity exists, it expands from the first Flow's full hour through the full hour after the last Flow, never below two hours; this keeps short sessions visually meaningful. Hovering a dashboard timeline segment shows an immediate compact card with Task, clock interval, and focused duration. Clicking resolves one selected segment ID and opens one popover anchored to that exact timeline position, with Task, Direction, interval, focused duration, and Flow size. A red trash button deletes only that completed segment after confirmation and subtracts its progress; deleting the only segment deletes the Flow. Completed segments can continue to the canonical Flow history inspector; the active segment is read-only and marked `実行中`.

Explicit rests are persisted and drawn as light-gray intervals between Flow segments. If the next Flow begins within 1.5 times the planned rest from rest start, both sessions retain separate history records but share one series ID and receive a visible enclosing series outline. Continuation windows are Short 4:30, Focus 7:30, Deep 15:00, and Long Break 30:00. After every 4 accumulated Blocks in the series, the next manually started rest becomes a 20-minute Long Break. Missing the window simply starts a new series.

Hovering a rest shows its type, interval, and duration above the timeline. Clicking a completed rest opens a duration editor anchored to that rest. Start time is fixed. If the new end overlaps the next Flow, that Flow and all later Flow/rest records in the same series move forward by the overlap. Free space absorbs an extension without shifting, shortening does not pull history backward, and unrelated series never move.

Below the Flow stage are today's `タスク` and `習慣` columns. `ナイス` is omitted when empty. Rows use the same square Check and circular Block/Minute progress controls as the Tasks screen, and can be completed or opened for editing. A compact `統計` panel shows today's completion rate and Direction focus distribution.

The Dashboard Task header `+` opens the shared messenger-style composer in a separate popover. The Flow Task picker's `タスク` tab also ends with an add row that opens the same popover; a Task created there is immediately selected for Flow. Direction, measurement, and priority remain editable, while the date is fixed to `今日`. The composer has an explicit close button that discards the unfinished action. Habit has no manual add action.

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

Selecting any contribution cell switches the app navigation to the single canonical `履歴` section for that day. Statistics never embeds a duplicate History view.

Hovering a cell shows its date, completed Task count, Flow count, Blocks, and focused duration. `今月` is arranged as a seven-column month calendar; `180日` uses larger contribution cells than the year view.

## History Calendar

`履歴` is available directly below `タスク`, owns the canonical History presentation, and initially opens today. It preserves the date selected from Statistics. The user can move backward or forward by the selected range, choose a date, or use the mini-calendar on wide macOS windows.

The primary `カレンダー` mode provides:

- `日`: a narrow scrollable timeline with `Elastic | 24時間` scale and a right inspector;
- `週`: seven synchronized day columns in one vertically scrollable 24-hour grid;
- `月`: a seven-column month overview.

In `日`, the right pane keeps a mini-calendar above the selected record properties. Selecting a Flow or rest updates that pane; changing the day clears the selection. Elastic includes the day's timed records and current hour with one-hour context and a four-hour minimum. `24時間` shows the full day, and the preference persists locally. At compact widths, selection opens the same inspector as a sheet so the timeline retains useful width.

Week keeps date headers fixed while hours scroll. Opening a day/week grid scrolls near the current time when today is visible, otherwise near the first Flow. A red line marks the current time. Medium/narrow headers wrap into two rows and stable-width week columns scroll horizontally. Month keeps a minimum full-grid width and scrolls horizontally rather than crushing cells.

Calendar tracks are grouped by `seriesID`. Flow and FlowSegment records from one series share one continuous track and keep their Direction colors; FlowBreak records occupy the same track as light-gray rest segments. A new series starts a separate track. Todo completions and pending Tasks never become independent History Calendar blocks.

Timed records keep a small minimum clickable height. Entries below 15 minutes use compact title-only rendering and expose exact time through hover and accessibility. Lane assignment uses the minimum visual duration as well as actual overlap, preventing nearby short records from painting over one another.

Selecting an entry reuses `FlowHistoryInspectorView` or `FlowBreakEditor`. Double-clicking empty time opens `Flowを追加` with Task, Direction, Short/Focus/Deep, start, end, and minutes. The clicked time is rounded to five minutes, the default duration is 25 minutes, and end/minutes remain linked. Saving creates a completed independent Flow series and applies normal Direction/Todo progress; manual rest creation is intentionally unavailable. The calendar does not provide direct drag/resize and does not persist a second calendar entity.

The Flow inspector limits its Task picker to Tasks scheduled on the Flow date plus the currently assigned Task. It edits time through linked `開始`, `終了`, and direct `分` fields: start/end changes recalculate minutes, and minute changes keep start fixed while moving end.

- `カレンダー`: day, week, and month calendar history.
- `タスク`: focus totals grouped by Task.
- `方向`: focus totals grouped by Direction.

Task completion timestamps remain available to Task summaries and Statistics, but are not rendered in the Flow calendar. Selecting a Flow opens its inspector for correction or deletion.
