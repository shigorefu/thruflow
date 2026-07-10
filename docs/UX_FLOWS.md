# UX Flows

## 方向

The Direction screen manages only user-editable Directions:

- `通常`;
- `習慣`;
- `ナイス`.

The system Direction `その他` is not shown here and cannot be edited from this screen.

## タスク

タスク shows scheduled tasks for the current day.

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

## Flow Player

The Flow player is always available as a top header. It is not placed below the Task input.

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
