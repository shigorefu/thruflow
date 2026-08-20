# Vocabulary

The canonical translator glossary is `Localisation/TERMS.csv`. This page is a
compact product reference; additions and translation changes belong in the CSV
first so GitHub contributors have one shared terminology table.

| Visible English | Russian UI | Japanese UI | Source key |
| --- | --- | --- | --- |
| ThruFlow | ThruFlow | スルフロ | `スルフロ` |
| Area | Сфера | 分野 | `分野` |
| Anytime | Обычное | いつでも | `通常` |
| Habit | Привычка | 習慣 | `習慣` |
| Optional | Если получится | できたら | `ナイス` |
| Other | Другое | その他 | `その他` |
| Task | Задача | タスク | `対象タスク` |
| Tasks navigation | Задачи | タスク | `タスク` |
| Areas navigation | Сферы | 分野 | `方向` |
| No-date Tasks / Inbox | Без даты / Входящие | 日付なし | `日付なし` / `Inbox` |
| All task filter | Все | すべて | `すべて` |
| Day range | День | 日 | `日` |
| Week range | Неделя | 週 | `週` |
| Month range | Месяц | 月 | `月` |
| Note | Заметка | メモ | `メモ` |
| Check | Отметка | チェック | `チェック` |
| Focus Blocks | Блоки фокуса | 集中ブロック | `集中ブロック` / `フローブロック` |
| Block unit (short label) | Блок | ブロック | `ブロック` |
| Minutes measurement | Минуты | 分 | `分単位` |
| Minute unit (short label) | мин | 分 | `分` |
| High priority | Высокий | 高 | `高` |
| Medium priority | Средний | 中 | `中` |
| Low priority | Низкий | 低 | `低` |
| If there is room | Если останется время | 余裕があれば | `余裕があれば` |
| Main Flow section | Flow | 流れ | `Flow` |
| Saved Flow session | Flow | 集中記録 | `集中記録` |
| Flow action | Фокус | 集中 | `集中` |
| Flow count | Сессии Flow | 集中回数 | `集中回数` |
| Flow Mode | Режим Flow | 集中モード | `Flowタイプ` / `集中モード` |
| Break | Перерыв | 休憩 | `休憩` |
| Long Break | Длинный перерыв | 長休憩 | `長休憩` |
| Short | Короткий | 短め | `Sprint` |
| Standard | Обычный | 標準 | `Focus` |
| Deep | Глубокий | じっくり | `Deep` |
| Auto | Авто | 自動 | `オート` |
| Habit schedule: several times per week | Несколько раз в неделю | 週に数回 | `週回` |
| Statistics | Статистика | 統計 | `統計` |
| Time Distribution | Распределение времени | 時間配分 | `時間配分` |
| By Task | По задачам | タスク別 | `タスク別` |
| By Area | По сферам | 分野別 | `方向別` |
| Trend | Динамика | 推移 | `傾向` |
| Focus Calendar | Календарь фокуса | 集中カレンダー | `Dots` |
| Completion | Выполнение | 達成状況 | `達成状況` |
| Completed-task statistics label | Задачи | 達成 | `達成` |
| History | История | 履歴 | `履歴` |
| Today's Timeline | Хронология за сегодня | 今日のタイムライン | `今日のタイムライン` |
| Today | Сегодня | 今日 | `今日` |
| Add Task | Добавить задачу | タスクを追加 | `タスクを追加` |
| Completion time unavailable | Время завершения неизвестно | 完了時刻なし | `完了時刻なし` |
| Statistics Task mode | Задачи | タスク | `タスク` |
| Statistics focus mode | Фокус | 集中 | `集中` |

`Flow` does not have one global Japanese replacement. Use `流れ` for the main
workspace and its visual stream, `集中記録` for a persisted session or history
record, `集中` for an action, and `集中回数` for a count. Translate the intended
meaning in each UI context instead of performing a project-wide text
replacement.

Visible English uses `Area` / `Areas`, while visible Russian uses
`Сфера` / `Сферы`. `Direction` remains the Swift model name,
property name, persisted identifier, and stable machine-readable CSV column.
The source keys `Sprint`, `Focus`, `Deep`, and `Dots` are likewise implementation
details: the visible English labels are `Short`, `Standard`, `Deep`, and
`Focus Calendar`.
