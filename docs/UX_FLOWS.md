# UX Flows

## 方向

The Direction screen manages only user-editable Directions:

- `通常`;
- `習慣`;
- `ナイス`.

The system Direction `その他` is not shown here and cannot be edited from this screen.

## 今日

今日 shows scheduled tasks for the current day.

Sections:

- `習慣`: automatically generated habit tasks;
- `通常`: normal scheduled tasks;
- `ナイス`: optional positive tasks.

Task rows:

- empty title displays `(方向)`;
- completed tasks are visually muted, struck through, and sorted below active tasks;
- Direction color is used unless the Direction is `その他`;
- `チェック` shows a checkbox;
- `集中ブロック` shows a filling ring;
- `分` shows minute progress.

Quick capture behaves like a messenger composer. The user can set measurement, Direction, priority, and date from compact controls.

`日付なし` sends the task to Inbox, not 今日.

## Inbox

Inbox shows active tasks with no scheduled date.

The user can quickly move a task to:

- 今日;
- 明日;
- another date through edit.

## Flow Player

The Flow player is always available and behaves like a compact media player.

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
