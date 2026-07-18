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

- `日`: detailed list for the selected date;
- `週`: seven horizontally scrollable kanban columns;
- `月`: month grid with completion counts, Direction dots, and incomplete Habit markers.

Filters are `すべて`, `タスク`, and `習慣`. Habit instances stay in the same calendar as normal Tasks but remain visually separated.

Active normal Tasks can be dragged between dates in day, week, and month. Month still opens a day for detailed actions when its date header is selected. Completed Tasks and fixed daily/weekday Habit Tasks stay on their original date. Weekly-count Habit moves are validated against the remaining weekly target.

Clicking a month cell opens that date in `日`. The centered filter remains stable across ranges; `今日` and the right period picker navigate dates. The quick composer follows the selected date or kanban column.

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
- `分` shows a filled timer circle, visually distinct from the Block ring.

Quick capture behaves like a messenger composer. The user can set measurement, Direction, priority, date, and multiple hashtags from compact controls. The default measurement control reads `種類`; leaving it untouched creates a Check Task. It is one stable animated control: its leading icon distinguishes Check, Block ring, and filled Minute circle; Block and Minute states expose an inline numeric field and unit before the menu chevron. Hashtags display with `#`, deduplicate case-insensitively, and preserve the first entered casing.

The composer also recognizes `[]`, `[2b]`, `[30m]`, `@Direction`, `!high`, `/today`, and `#tag`. Completed tokens are removed from the persisted plain-text title, update the lower controls, and remain visible as semantic chips inside the input body (`[]` becomes a `チェック` chip). English aliases always work, while Japanese and Russian aliases work in addition. Typing `@` opens Direction autocomplete. An unknown Direction is never guessed: submitting it immediately opens the full Direction creation screen with the name prefilled; after cancellation the user can retry or explicitly create the Task under `その他`. Invalid tokens remain ordinary title text. A dismissible syntax legend is visually separate above the focused composer shell and can be restored from Settings.

When `今日` is selected, active overdue normal Tasks appear in a leading `期限切れ` section. The section supports normal Task actions, drag-to-date, and `すべて今日へ`. Automatically generated Habit instances are excluded.

There is no separate Inbox navigation item. A toolbar `日付なし` button always shows the number of active undated normal Tasks. It opens a trailing inspector on macOS with per-Task `今日へ移動`, drag-to-date, edit, complete, delete, and `すべて今日へ` actions. Returning from the inspector preserves the selected calendar date and range.

Weekly-count habits create one pending task at a time. After completion, the next instance may appear on a later eligible day until the weekly target is met. Moving the pending instance does not create a replacement for today, and dates that would make the target impossible are disabled.

Daily and selected-weekday Habit instances are generated for visible current/future dates. Weekly-count habits are not expanded across future calendar columns.

## Flow Player

`Flow` is the first/default navigation item. In a wide window, its dashboard uses one aligned two-column grid: the animated daily stream and Elastic series timeline sit above today's Tasks on the left, while the equally tall square player sits above compact Statistics on the right. All lower Task, Habit, optional Nice, and Statistics panels share one height and stretch to the bottom of the viewport; short windows retain a minimum lower-row height and scroll vertically. The left side occupies roughly three quarters of the content. Other app sections do not repeat the player as a top header; the macOS menu bar opens this same square player. A horizontal compact menu-bar layout is retained in product documentation as a deferred design only and is not part of the current UI.

The player layout is:

In the narrow vertical dashboard layout, the player comes first, followed by the Flow stream/timeline, Tasks/Habits, and Statistics. The narrow player and Flow stage use stable heights so resizing does not reorder controls or cause layout jumps.

- left Task card with Direction icon, Task title, and smaller Direction name;
- Task card opens a picker with `タスク`, `習慣`, and `方向` tabs;
- `タスク` and `習慣` use separate lists of today's items;
- `方向` uses an emoji-and-name grid with `その他` first for Direction-only starts;
- Direction icon color follows the selected Task Direction;
- compact Focus selector opens a separate picker for `Short`, `Focus`, and `Deep`;
- selecting another Focus mode during focus or pause preserves elapsed time and only moves the planned end, matching the seek controls;
- break time counts down past zero with a positive overtime sign; its neutral-gray progress ring drains while the Direction-colored focus ring fills. Starting work during rest completes the previous Flow and immediately starts the next one, while menu bar status becomes `☕️ 休憩 - time` or `☕️ Long Break - time`;
- choosing another Task during focus or pause keeps the current Flow running and starts a new history segment; no memo prompt is shown for this switch;
- the Task card reuses the canonical completion/progress control; only Check is interactive, while Block and Minute rings are read-only and show progress and the remaining amount;
- generated titles for empty Tasks and Habits are consistently italic and visually muted in the player, picker, Tasks screen, and dashboard panels;
- dashboard `タスク` rows show priority before progress, including `余裕があれば` for low-priority optional work; fixed Habit priority is not displayed;
- the fixed-height dashboard Statistics carousel opens with a centered donut and `タスク別 | 方向別`; its other pages show a 7-day Flow-minute bar chart with previous-day deltas and today's `達成状況`;
- double-clicking the selected Task title edits it inline; Enter or focus loss saves and Escape cancels. Double-click recognition is limited to the visible title bounds so the rest of the Task card opens the picker immediately;
- the Task card provides the same short pressed-state feedback as the Focus selector without changing its single/double-click actions;
- timer and transport controls on the right.

Mode labels:

- `Short 12/3`;
- `Focus 25/5`;
- `Deep 50/10`.

Flow can be started with a selected Task, with only a Direction, or with neither. Direction-only work does not create an implicit Todo. If no Direction is chosen, the resolved Direction is `その他`. Automatic Task creation is deferred until its measurement and planned amount are defined.

At the planned focus end, Flow does not auto-switch. The timer continues. The user chooses:

- continue;
- start break;
- stop.

Stopping focus or starting break opens the same square memo panel in the dashboard and macOS menu bar player. It shows `お疲れ様です。メモを追加しますか？`, a large editor, `キャンセル` on the left, and one checkmark submit button on the right. The submit label is `メモなしで送信` for an empty editor and `送信` when text exists. Focus keeps counting while a break memo is open. Submitting text writes it to Todo; submitting an empty editor continues without changing the memo. Cancelling returns to the state before the prompt: a pending break returns to focus, while a stop prompt restores the previous running or paused Flow and removes its provisional progress. Stopping or skipping an existing rest never asks for memo again.

The trash action is phase-aware. During focus it deletes the current Flow and rolls back any credited Task/Direction progress through the canonical History editor. During rest it deletes only the active FlowBreak and closes the player, preserving the completed focus session and its progress.

The daily stream is formed by broad, bright, softly glowing translucent ribbons following one shared S-shaped channel. Back, middle, and foreground ribbons move at different speeds to create depth; smooth color and alpha variation preserve separation without black negative channels. Today's focused Blocks permanently amplify movement until the day changes, reaching their visual maximum at 6 Blocks. Occupancy stops growing at 4 Blocks; later progress adds detail, parallax, color, and motion rather than filling the stage. Every completed half-Block sends a restrained light pulse through the channel. Idle stays in a calm `0.06...0.28` speed range, while an active Flow uses a separate `1.10...2.80` range. Short uses energetic waves, Focus balanced waves, and Deep broad slow bends; the background tint follows the selected mode. The current Flow appears live after its first creditable minute. Reduce Motion keeps the visualization static. Selecting a completed timeline segment opens the existing Flow history inspector.

The dashboard timeline always uses `Elastic` and has no `24時間` control. When empty, it covers the current full hour and the following hour. Once activity exists, it expands from the first Flow's full hour through the full hour after the last Flow, never below two hours; this keeps short sessions visually meaningful. Hovering a dashboard timeline segment shows an immediate compact card with Task, clock interval, and focused duration. Clicking resolves one selected segment ID and opens one popover anchored to that exact timeline position, with Task, Direction, interval, focused duration, and Flow size. A red trash button deletes only that completed segment after confirmation and subtracts its progress; deleting the only segment deletes the Flow. Completed segments can continue to the canonical Flow history inspector; the active segment is read-only and marked `実行中`.

The dashboard timeline uses a neutral dark rail for time without Flow. Every series containing a persisted rest receives one continuous light-gray underlay from its first Block through its final rest. The underlay and FlowSession Blocks have the same height. Blocks are rounded Direction-colored capsules above that underlay, so exposed gray intervals read as rests without becoming thinner, while unrelated series remain separated by the dark rail. FlowSegments caused by switching Tasks divide the color inside a Block edge-to-edge while sharing one outer capsule; they never appear as separately rounded Blocks. If the next Flow begins within 1.5 times the planned rest from rest start, both sessions retain separate history records but share one series ID and therefore one continuous underlay. Continuation windows are Short 4:30, Focus 7:30, Deep 15:00, and Long Break 30:00. After every 4 accumulated Blocks in the series, the next manually started rest becomes a 20-minute Long Break. Missing the window simply starts a new series.

Hovering a rest shows its type, interval, and duration above the timeline. Clicking a completed rest opens a duration editor anchored to that rest. Start time is fixed. If the new end overlaps the next Flow, that Flow and all later Flow/rest records in the same series move forward by the overlap. Free space absorbs an extension without shifting, shortening does not pull history backward, and unrelated series never move.

Below the Flow stage are today's `タスク` and `習慣` columns. `ナイス` is omitted when empty. Rows use the same square Check and circular Block/Minute progress controls as the Tasks screen. Check can be completed manually; Block and Minute rings are read-only because recorded Flow owns their progress. Rows can be opened for editing. The fixed-height compact `統計` carousel provides Task/Direction focused-time distribution, a seven-day Flow trend with previous-day comparisons, and today's completion status.

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

The History mini-calendar marks only days that contain recorded Flow history, using the corresponding Direction colors. Scheduled, pending, and future Task or Habit dates do not create History dots. Task calendars keep their separate indicators and apply the active `すべて | タスク | 習慣` filter.

The primary `カレンダー` mode provides:

- `日`: a narrow scrollable timeline with `Elastic | 24時間` scale and a right inspector;
- `週`: seven synchronized day columns in one vertically scrollable 24-hour grid;
- `月`: a seven-column month overview.

History has one responsive toolbar with the centered mode switch, prominent `今日`, and Calendar range. Duplicate top date controls are removed because the right period picker owns navigation. `タスク` and `方向` use a wide two-column layout with aggregates on the left and a mini-calendar plus range summary on the right. At compact widths, the calendar and summary stack above the aggregate list.

In `日`, the right pane keeps the only wide-layout mini-calendar above the selected record properties. Flow/rest visibility is exposed by a compact `表示` menu in the timeline header; there is no separate filter rail. Selecting a Flow or rest updates the right pane; changing the day clears the selection. Elastic includes the day's timed records and current hour with one-hour context and a four-hour minimum. `24時間` shows the full day, and the preference persists locally. At compact widths, selection opens the same inspector as a sheet so the timeline retains useful width.

Week keeps date headers fixed while hours scroll. Its right mini-calendar highlights the complete selected week, and choosing any date selects that week. Opening a day/week grid scrolls near the current time when today is visible, otherwise near the first Flow. A red line marks the current time. Month keeps a minimum full-grid width and a right `1月...12月` year picker. Medium/narrow layouts preserve stable calendar widths through horizontal scrolling.

Flow and FlowSegment records remain separate calendar blocks colored by Direction. FlowBreak records remain separate light-gray calendar blocks. Only the Flow dashboard timeline uses `seriesID` to place one continuous light-gray line beneath the colored work and rest segments of a connected series. Todo completions and pending Tasks never become independent History Calendar blocks.

Lane assignment uses exact stored start/end intervals. Contiguous Flow and rest records stay in one vertical lane, and only actual time overlap creates side-by-side lanes. Entries below 15 minutes use compact title-only rendering; short rests become thin gray bars and expose exact time through hover and accessibility.

Selecting an entry reuses `FlowHistoryInspectorView` or `FlowBreakEditor`. A completed Flow can be dragged to another exact day/time in day and week, or to another date in month; the complete session and its task-switch segments move together without changing duration or measured progress. Active Flow and rest records are not draggable. Double-clicking empty time inserts a selected `新しいFlow` draft block directly into the calendar. The clicked time is rounded to five minutes and the default duration is 25 minutes. In wide day view, `Flowを追加` occupies the right inspector; Task, Direction, Short/Focus/Deep, linked start/end, and minutes update the visible draft block immediately. Compact day and week use a sheet while retaining the draft block in the grid. Saving creates a completed independent Flow series and applies normal Direction/Todo progress without completing the Task; manual rest creation is intentionally unavailable. `履歴 > タスク` exposes the same action with the chosen Task fixed. Expanded `履歴 > 方向` ends with `タスクを追加`, which creates a Task with fixed Direction but no Flow. The calendar does not provide direct resize and does not persist a second calendar entity.

## Settings

`設定` opens through the native macOS Settings scene. `テーマ` offers system,
light, and dark appearance. `言語` lists the String Catalog localizations plus
the system language and clearly marks that changing it requires relaunching the
app. `週の開始日` offers system, Sunday, Monday, and Saturday; it updates Task,
History, and Statistics week layouts immediately. `時刻表示` offers system,
12-hour, and 24-hour clocks and updates locale-aware time labels immediately.

The Flow inspector limits its Task picker to Tasks scheduled on the Flow date plus the currently assigned Task. It edits time through linked `開始`, `終了`, and direct `分` fields: start/end changes recalculate minutes, and minute changes keep start fixed while moving end.

- `カレンダー`: day, week, and month calendar history.
- `タスク`: focus totals grouped by Task.
- `方向`: focus totals grouped by Direction.

Task completion timestamps remain available to Task summaries and Statistics, but are not rendered in the Flow calendar. Selecting a Flow opens its inspector for correction or deletion.
