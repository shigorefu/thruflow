# UX Flows

The main macOS window opens at an initial size of `1280 × 800` points. This is a
default only: normal macOS window restoration continues to respect a size chosen
by the user.

User-facing English uses `Area` / `Areas`; user-facing Russian uses
`Сфера` / `Сферы`. This document uses `Direction` only when it
refers to the Swift model, a property, persisted data, or the stable
machine-readable CSV column.

## 分野

The Area screen (`分野`; internal model `Direction`) manages only user-editable
Areas:

- `いつでも` / Anytime / В любое время;
- `習慣` / Habit / Привычка;
- `できたら` / Optional / Если получится.

The system Area `その他` / Other / Другое is not shown here and cannot be edited
from this screen.

On macOS, the `いつでも`, `習慣`, and `できたら` groups use an adaptive grid: wide
windows show them side by side, while narrower windows wrap the remaining groups
onto following rows in the same vertical scroll surface instead of clipping them.

On macOS, editing a Habit Area includes `習慣の状態`. An active Habit can
use `今日は休む`, `期間を指定…`, or `再開するまで一時停止`; a paused Habit
shows its effective period and a single `再開` action. While paused, the app
does not generate scheduled Habit Tasks and excludes those days from completion
rate. Existing history and actual Flow remain unchanged. `期間を指定…` opens a
compact calendar popover anchored to the pause control rather than a separate
sheet.

## タスク

タスク shows scheduled tasks for the current day.

Calendar ranges:

- `日`: detailed list for the selected date;
- `週`: seven horizontally scrollable kanban columns;
- `月`: month grid with completion counts, Area dots, and incomplete Habit markers.

Filters are `すべて`, `タスク`, and `習慣`. Habit instances stay in the same calendar as normal Tasks but remain visually separated.

Active normal Tasks can be dragged between dates in day, week, and month. Month still opens a day for detailed actions when its date header is selected. Completed Tasks and fixed daily/weekday Habit Tasks stay on their original date. Weekly-count Habit moves are validated against the remaining weekly target.

Clicking a month cell opens that date in `日`. On macOS, the system title toolbar
centers the compact text segmented filter `すべて | タスク | 習慣`; its trailing
actions contain `やり残し N | 日付なし N` and an icon-only search action that
expands on demand. Both counters open the same trailing backlog inspector with the
corresponding records. The calendar header uses two rows: centered `日 | 週 | 月`
first, then the active date or period on the left and `‹ 今日 ›` navigation on the
right. The embedded month and year pickers do not repeat their own date title or
previous/next controls; the shared header is the only period navigator and updates
the complete Task workspace. On wide macOS layouts, changing `日 | 週 | 月`
animates only the primary Task calendar content; the persistent calendar column
stays visually stable to the right of the Task
workspace in `日`, `週`, and `月`; the former seven-day card strip is not
duplicated above the `日` list. The persistent column derives its width from the
localized period title and `今日` action; text scales down only when the window
cannot provide the preferred intrinsic width.
The quick composer follows the selected date or kanban column.

Sections:

- `習慣`: automatically generated habit tasks;
- `いつでも`: normal scheduled tasks;
- `できたら`: optional positive tasks.

Task rows:

- empty title displays `(分野)` in a translucent italic style;
- completed tasks are visually muted, struck through, and sorted below active tasks;
- Area color is used unless the internal `Direction` is `その他`;
- `チェック` shows a checkbox;
- `集中ブロック` shows a filling ring;
- `分` shows a filled timer circle, visually distinct from the Block ring.

Completing a Check Task draws the checkmark into place and gives the control one
restrained pulse. Reaching a Block or Minute goal uses the same completion pulse
without making its progress control manually clickable. Completion feedback is
triggered only on the incomplete-to-complete transition, respects Reduce Motion,
and produces one system success haptic on iPhone. It may also play the bundled
`task-complete.caf` sound when that optional asset is present. Re-rendering an
already completed Task never repeats the feedback.

Quick capture behaves like a messenger composer. The user can set measurement, Area, priority, date, and multiple hashtags from compact controls. The default measurement control reads `種類`; leaving it untouched creates a Check Task. It is one stable animated control: its leading icon distinguishes Check, Block ring, and filled Minute circle; Block and Minute states expose an inline numeric field and unit before the menu chevron. The remaining metadata controls are text-only on both platforms. Area uses its configured color, priority uses red/neutral/green for high/medium/low, and date always remains neutral. On iOS the metadata row scrolls horizontally instead of compressing or clipping selected values. The priority menu keeps the fixed order `高`, `中`, `低`, `余裕があれば`; the final option persists as low priority with its dedicated room-if-possible flag. Hashtags display with `#`, deduplicate case-insensitively, and preserve the first entered casing.

The composer also recognizes `[]`, `[2b]`, `[30m]`, `@Area`, `!high`, `/today`, and `#tag`. Completed tokens are removed from the persisted plain-text title, update the lower controls, and remain visible in a dedicated upper row inside the composer as semantic chips (`[]` becomes a `チェック` chip); clicking a chip removes its semantic value. English aliases always work, while Japanese and Russian aliases work in addition. Typing `@`, `!`, `/`, or `[` opens a contextual autocomplete surface above the composer. Each suggestion is clickable across its full row, and the current suggestion has an accent highlight. Mouse hover or `Up`/`Down` changes selection; `Return` applies it. An unknown Area is never guessed: submitting it immediately opens the full Area creation screen with the name prefilled; after cancellation the user can retry or explicitly create the Task under `その他`. Invalid tokens remain ordinary title text. A dismissible syntax legend appears above the composer only after typing begins, groups measurement shortcuts (`[ ]`, `[1b]`, `[25m]`) before metadata shortcuts (`@`, `!`, `/`, `#`), and can be restored from Settings. Autocomplete temporarily replaces the legend so the two surfaces never overlap. The primary submit action is an icon button in the composer's upper-right corner; unset Area, priority, and date controls use neutral placeholder labels. Tasks and menu-bar quick creation use this same composer and interaction model.

Inside the Flow task picker, quick creation opens as a separate compact trailing popover. It shows only the messenger composer, without the syntax legend. The add action first closes the Task picker and then presents the composer from the player itself. Avoiding a nested popover keeps controls and submenus interactive in the macOS menu-bar window instead of treating them as outside clicks.

When `今日` is selected on macOS, or the iOS `日` view is showing today, active overdue normal Tasks appear in a leading `やり残し` section. On iOS this is a separate card above the dated Task card and it is not rendered in `週` or `月`. Both platforms use the shared backlog projection and expose normal Task actions plus `すべて今日へ`; macOS additionally supports drag-to-date. Automatically generated Habit instances are excluded.

There is no separate Inbox navigation item. The macOS toolbar counters for
`やり残し` and `日付なし` always show their active normal Task totals and open a
shared trailing inspector. It supports per-Task `今日へ移動`, drag-to-date, edit,
complete, delete, and `すべて今日へ`. Returning from the inspector preserves the
selected calendar date and range.

Weekly-count habits create one pending task at a time. After completion, the next instance may appear on a later eligible day until the weekly target is met. Moving the pending instance does not create a replacement for today, and dates that would make the target impossible are disabled.

Daily and selected-weekday Habit instances are generated for visible current/future dates. Weekly-count habits are not expanded across future calendar columns.

A Todo whose Direction relationship has not resolved is not a normal
`その他` Task. It stays out of Today, calendar, widget, and backlog projections
until the persistence reconciler can restore one unambiguous relationship.

## Flow Player

`流れ` is the first/default navigation item. In a wide window, its dashboard uses one aligned two-column grid: the animated daily stream and Elastic series timeline sit above today's Tasks on the left, while the equally tall square player sits above compact Statistics on the right. Both rows reuse the same explicit column widths, so the player and Statistics always align and have the same width while the window is resized. All lower Task, Habit, optional `できたら`, and Statistics panels share one height and stretch to the bottom of the viewport; short windows retain a minimum lower-row height and scroll vertically. The left side occupies roughly three quarters of the content. Other app sections do not repeat the player as a top header; the macOS menu bar opens this same square player.

The player layout is:

In the narrow vertical dashboard layout, the player comes first, followed by the Flow stream/timeline, Tasks/Habits, and Statistics. The narrow player and Flow stage use stable heights so resizing does not reorder controls or cause layout jumps.

- left Task card with Area icon, Task title, and smaller Area name;
- Task card opens a picker with `タスク`, `習慣`, and `分野` tabs;
- `タスク` and `習慣` use separate lists of today's items;
- `分野` uses an emoji-and-name grid with `その他` first for Area-only starts;
- on iPhone and iPad the same three context tabs use touch-native lists, open on
  the currently selected context type, and keep `その他` first;
- Area icon color follows the selected Task Area;
- compact `集中モード` selector opens a separate picker for `短め`, `標準`, and `じっくり`;
- selecting another `集中モード` during focus or paused focus preserves elapsed time, applies that preset as the new total plan, and moves only the planned end. A shorter preset may immediately show overtime; crossing another preset threshold never renames the selected mode;
- transport seek controls subtract or add exactly five minutes from remaining focus time across macOS, iOS, menu bar, and Live Activity. Subtract stops at one minute remaining, both actions preserve elapsed time and mode, and both are disabled during rest;
- starting rest derives its duration from actual focused time rather than the selected mode: under 24 minutes gives 3 minutes, 24...48:59 gives 5 minutes, and 49 minutes or more gives 10 minutes. The 24- and 49-minute boundaries normalize Block credit to 25 and 50 minutes while longer actual time remains exact;
- break time counts down past zero with a positive overtime sign; its neutral-gray progress ring drains while the Area-colored focus ring fills. Starting work during rest completes the previous Flow and immediately starts the next one, while the Japanese menu bar status becomes `☕️ 休憩 - time` or `☕️ 長休憩 - time`;
- choosing another Task during focus or pause keeps the current Flow running and starts a new history segment; no memo prompt is shown for this switch;
- the Task card reuses the canonical completion/progress control; only Check is interactive, while Block and Minute rings are read-only and show progress and the remaining amount;
- generated titles for empty Tasks and Habits are consistently italic and visually muted in the player, picker, Tasks screen, and dashboard panels;
- dashboard `タスク` rows show priority before progress, including `余裕があれば` for low-priority optional work; fixed Habit priority is not displayed;
- the fixed-height dashboard Statistics carousel opens with a centered donut and `タスク別 | 分野別`; its other pages show a 7-day Flow-minute bar chart with previous-day deltas and today's `達成状況`;
- double-clicking the selected Task title edits it inline; Enter or focus loss saves and Escape cancels. Double-click recognition is limited to the visible title bounds so the rest of the Task card opens the picker immediately;
- the Task card provides the same short pressed-state feedback as the `集中モード` selector without changing its single/double-click actions;
- timer and transport controls on the right.

On iPhone and iPad, today's compact Flow timeline keeps its 14-point visual rail
inside a 44-point touch target. Tapping a Flow segment opens a compact popover
above that exact position with its Task, Area, interval, focused duration,
and mode. A running segment is marked `実行中` and remains read-only. Completed
segments and rests can continue from the popover to the same canonical
detail/editor used by `履歴`; an active rest remains non-interactive. The History
lookup runs only when that action is selected, so the live timeline does not add
a per-tick History projection.

The `集中モード` / Flow Mode labels are:

- `短め 12/3` / Short / Короткий;
- `標準 25/5` / Standard / Обычный;
- `じっくり 50/10` / Deep / Глубокий.

The internal adaptive mode is labeled `自動` / Auto / Авто whenever it appears
in saved data.

Flow can be started with a selected Task, with only an Area, or with neither.
Area-only work does not create an implicit Todo. If no Area is chosen, the
resolved internal `Direction` is `その他`. Version 1.0 never creates a Task
implicitly from Flow.

At the planned focus end, Flow does not auto-switch. The timer continues. The user chooses:

- continue;
- start break;
- stop.

While focus overtime is running, the primary pause control becomes `休憩` on
macOS and iOS. Selecting it opens the normal break-memo flow; the break still
does not start automatically.

Every valid `休憩` selection immediately sends one short reverse release wave
through the visible Flow stream. This is acknowledgement of the control only:
it does not visually claim that rest has begun, and cancelling the memo returns
to focus normally. Each repeated selection receives a unique transient cue. On
watchOS the Timer-page cup also bounces and provides light sensory feedback,
because the stream itself lives on a separate page.
After memo submission actually starts rest, a regular break adds a soft outward
exhale. A confirmed `長休憩` instead runs a four-second full-width fan and bloom,
then retains a subtle breathing spread until the break ends. None of these cues
is persisted or resets the stream phase. Reduce Motion suppresses the transient
movement while keeping the static regular/long-rest appearance and accessible
rest label.

Stopping focus or starting break opens the same square note panel in the dashboard and macOS menu bar player. It shows `お疲れ様です。メモを追加しますか？`, a large editor, `キャンセル` on the left, and one checkmark submit button on the right. The submit label is `メモなしで送信` for an empty editor and `送信` when text exists. Focus keeps counting while a break note is open. Submitting text writes it to `FlowSession.result` and mirrors it to `Todo.notes` when linked; submitting an empty editor continues without clearing an existing Task note. Cancelling returns to the state before the prompt: a pending break returns to focus, while a stop prompt restores the previous running or paused Flow and removes its provisional progress. Stopping or skipping an existing rest never asks for a note again.

On iPhone, successfully submitting the stop memo or starting the requested rest
produces one system success haptic for the completed Flow. Cancelling the memo,
discarding a sub-minute Flow, and ending a rest do not produce completion
feedback.

The trash action is phase-aware. During focus it deletes the current Flow and rolls back any credited Task/Area progress through the canonical History editor. During rest it deletes only the active FlowBreak and closes the player, preserving the completed focus session and its progress.

Before the first Flow, the dashboard uses a familiar neutral six-ribbon S-stream. During the first canonical Block it continuously reveals a seventh ribbon, deterministic topology seeded by the date and the earliest stable internal `Direction` identifier, focus-weighted Area colors, and additional depth. This transition happens inside one shader and never replaces or resets the current frame. The completed daily stream therefore becomes personal while a new user's empty dashboard remains immediately understandable. The resulting seven broad, bright, softly glowing translucent ribbons follow one shared channel. The seed remains identical on devices sharing the same synchronized database and never changes with time of day. Back, middle, and foreground ribbons move at different speeds to create depth; later progress increases weave, glow, parallax, and detail while capped occupancy preserves readable gaps. Every completed half-Block sends a restrained light pulse through the channel. After the 25-percent motion increase, idle stays in a calm `0.075...0.35` phase-speed range at 30 FPS and carries a subtle moving inner current so it does not appear frozen, while active Flow uses `1.375...3.50` at 60 FPS. Frame cadence is unchanged. `短め` uses energetic waves, `標準` balanced waves, and `じっくり` broad slow bends. Dark mode uses luminous additive composition; light mode uses controlled ink-style blending. The current Flow appears live after its first creditable minute. Reduce Motion, an inactive iOS scene, or a non-key macOS window freezes the last frame and stops further GPU updates. Selecting a completed timeline segment opens the existing Flow history inspector.

The dashboard timeline always uses `Elastic` and has no `24時間` control. When empty, it covers the current full hour and the following hour. Once activity exists, it expands from the first Flow's full hour through the full hour after the last Flow, never below two hours; this keeps short sessions visually meaningful. Hovering a dashboard timeline segment shows an immediate compact card with Task, clock interval, and focused duration. Clicking resolves one selected segment ID and opens one popover anchored to that exact timeline position, with Task, Area, interval, focused duration, and Flow size. A red trash button deletes only that completed segment after confirmation and subtracts its progress; deleting the only segment deletes the Flow. Completed segments can continue to the canonical Flow history inspector; the active segment is read-only and marked `実行中`.

The dashboard timeline uses a neutral dark rail for time without Flow. Every series containing a persisted rest receives one continuous light-gray underlay from its first Block through its final rest. The underlay and FlowSession Blocks have the same height. Blocks are rounded Area-colored capsules above that underlay, so exposed gray intervals read as rests without becoming thinner, while unrelated series remain separated by the dark rail. FlowSegments caused by switching Tasks divide the color inside a Block edge-to-edge while sharing one outer capsule; they never appear as separately rounded Blocks or increment `集中回数`. A context segment shorter than 60 focused seconds transfers wholesale to the newly selected Task/Area; returning to the immediately preceding context during that window merges the adjacent segments. If the next Flow begins within 1.5 times the planned rest from rest start, both sessions retain separate history records but share one series ID and therefore one continuous underlay. Continuation windows are `短め` 4:30, `標準` 7:30, `じっくり` 15:00, and `長休憩` 30:00. After every 4 accumulated Blocks in the series, the next manually started rest becomes a 20-minute `長休憩`. Missing the window simply starts a new series.

Hovering a rest shows its type, interval, and duration above the timeline. Clicking a completed rest opens a duration editor anchored to that rest. Start time is fixed. If the new end overlaps the next Flow, that Flow and all later Flow/rest records in the same series move forward by the overlap. Free space absorbs an extension without shifting, shortening does not pull history backward, and unrelated series never move.

Below the Flow stage are today's `タスク` and `習慣` columns. `できたら` is omitted when empty. Rows use the same square Check and circular Block/Minute progress controls as the Tasks screen. Check can be completed manually; Block and Minute rings are read-only because recorded Flow owns their progress. Rows can be opened for editing. The fixed-height compact `統計` carousel provides Task/Area focused-time distribution, a seven-day Flow trend with previous-day comparisons, and today's completion status.

The Dashboard Task header `+` opens the shared messenger-style composer in a separate popover. The Flow Task picker's `タスク` tab also ends with an add row that opens the same popover; a Task created there is immediately selected for Flow. Area, measurement, and priority remain editable, while the date is fixed to `今日`. The composer has an explicit close button that discards the unfinished action. Habit has no manual add action.

## Onboarding And Voluntary Support

Version 1.0.2 uses the same eight-step order on macOS, iPhone, and iPad:

1. `ようこそ`;
2. `分野`;
3. `タスク`;
4. `流れ`;
5. `集中のプレビュー`;
6. `履歴`;
7. `統計`;
8. `使い方の流れ`.

The real application workspace remains visible beneath a dimmed onboarding
surface, and the requested feature screen opens behind each guidance step.
Guidance stays centered and uses platform-native editor, composer, sheet, and
popover presentation instead of geometry-dependent spotlights or scrim cutouts.
Back and Skip remain available throughout. Skip and Finish close any onboarding
presentation, return to Flow, and mark the first-run journey complete.

After the workspace is available, onboarding selects one of two experiences:

On signed CloudKit builds, the first empty snapshot stays in a short resolving
state until the first successful import event or a four-second grace period.
The app then checks the workspace again before offering creation. It also checks
again when an onboarding Area or Task is saved. If user content arrives while an
editor is open, the draft remains available; after the editor closes, the rest
of the journey continues as a read-only tour.

- an empty first installation enters guided mode. The Area step may open the
  real Area editor prefilled with a localized Work example, and the Task step
  may open the real composer prefilled with a localized report example linked
  to that Area. Nothing is inserted merely by opening either surface. Only a
  user-confirmed save creates the real Area or Task, using the normal validation,
  SwiftData, and CloudKit path;
- a first launch that already contains user Areas, Tasks, or Flow history enters
  read-only tour mode. It explains the same product loop without offering
  example creation or changing existing data.

The Flow step selects the just-created Task only as presentation context. The
following preview rapidly time-compresses a canonical Short focus interval into
its regular break while rendering the actual production Flow stream. Its timer,
phase, and progress are entirely transient: it creates no session, segment,
break, Task progress or completion, History, Statistics, notification, Live
Activity, or CloudKit write. Leaving the step or skipping resets the preview.
The final step summarizes `分野 → タスク → 流れ → 履歴・統計 → 次の一歩`.

`設定 > ヘルプ > 使い方を見る` first dismisses Settings, then starts the
journey again from Welcome in read-only replay mode. Replay never creates an
Area or Task, even when the workspace is empty. `--onboarding-preview` and
`--uitesting` keep guided QA and any confirmed examples inside an in-memory
store; preview completion is not persisted. watchOS does not present a second
onboarding journey because it remains a companion surface.

The app never schedules promotional support notifications. After a completed
Flow, the StoreKit review sheet may be requested only when the installation is
at least seven days old and the user has either five distinct completed-Flow
days or ten completed Flows. A request is recorded once per app version even
when the system chooses not to show the sheet.

`設定 > ThruFlowを応援` links to the App Store review page when a production App
Store ID is configured, links to GitHub, and offers Coffee and Ramen as
consumable StoreKit tips. A successful purchase shows thanks and finishes the
verified transaction; cancellation is silent, pending approval is explained,
and no purchase creates an entitlement or unlocks a feature. Tasks, the Flow
focus timer, History, and Statistics remain free and ad-free with no required
payment. This core-product promise does not define the terms or prices of future
optional integrations or services.

`設定 > フィードバック > フィードバックを送る` opens the public GitHub
issue-template chooser on macOS, iPhone, and iPad. The section warns that GitHub
reports are public and that private Task names and notes should be removed.
TestFlight testers are also reminded that a screenshot or the TestFlight app
can send feedback with device context. The app does not imitate TestFlight's
submission UI or depend on an undocumented TestFlight URL scheme.

## iPhone and iPad

The first iPhone surface is a Flow-first system `TabView`, with an independent
`NavigationStack` inside each destination. `流れ` opens by default. The Flow tab
and macOS sidebar use the same three-wave template mark as the macOS menu bar,
so primary Flow navigation has one icon across platforms. The tab bar
remains visible and marks the active
destination across five items: `流れ`, `タスク`, `履歴`, `分野`, and `統計`.
On iOS 26 it uses the native Liquid Glass selection indicator, minimizes while
content scrolls down, and returns on upward scrolling; iOS 17–25 retain the
system tab-bar behavior.
The system tab bar remains visible in `タスク`, matching the other primary
destinations. A separate circular `+` command in the lower trailing corner
opens the messenger composer and focuses its input. The composer includes an
explicit `×` command that dismisses the keyboard and returns to the task list
without creating a Task.
`設定` is reached from the trailing More menu.

At regular iPad widths the five primary destinations move from the bottom tab
bar into a persistent leading sidebar, matching the macOS information
architecture and leaving the wide detail area to the selected feature. The
sidebar also exposes `設定`. Compact Split View and Stage Manager widths return
to the tab shell automatically, without resetting the active destination or
feature state. iPad supports portrait and landscape orientations.

The regular-width Flow dashboard uses the detail area as two balanced columns:
the live Flow scene and timeline sit beside the player, while Tasks and today’s
Statistics share the next row. When the detail column becomes too narrow for
comfortable controls, the dashboard returns to the single-column presentation.

The first Flow viewport presents the softened animated stream and Elastic
timeline before the timer card. It keeps the Task selector, the shared
`集中モード` selector (`短め | 標準 | じっくり`), timer controls, stream, and timeline
together. The selector's Help button opens a native dimmed bottom sheet with
mode icons, work/rest durations, and usage guidance; macOS keeps the same content
in a popover. Changing the mode on either platform animates the shared Metal
parameters through the same transition without resetting the stream phase.
The timer exposes subtract five minutes, Play/Pause, add five minutes, destroy,
stop, and break while preserving the established player size. iPhone and macOS
share the same Metal stream renderer, including palette, speed, growth, glow,
completion impulse, and a theme-aware light or dark background. Below the
player, today's Tasks/Habits and compact Statistics are separate equal-width
cards in the vertical dashboard. The iPhone owns this presentation while reusing shared models,
persistence, timer state, dashboard projections, progress logic, and
localization.

Opening the `+` command in `タスク` slides a material-backed messenger composer
in above the persistent system tab bar. Shared quick-input tokens (`[ ]`, `[1b]`,
`[25m]`, `@`, `!`, `/`, and `#`) update the composer controls while typing, and
contextual autocomplete is shown above the field. The date control supports
Today, Tomorrow, No Date, and an arbitrary date through the native graphical
picker. Unspecified controls remain visibly labeled `種類`, `分野`, `優先度`,
and `日付`, while submission applies the shared Check, system Area `その他`, medium
priority, and Today defaults. The screen provides filtered day/week/month
ranges, automatic Habit instances, overdue and no-date inboxes, completion,
progress, and native Task editing. Its compact header uses an icon-only system
filter, centered `日 | 週 | 月`, a separate trailing `今日` action, and one
vertical More button. More carries the combined nonzero inbox badge and opens
`やり残し N` and `日付なし N`; the same vertical More symbol is used throughout
the iPhone app. Japanese day cells use bare numbers. The upper day strip is a
native horizontally scrolling, view-aligned list of date cards. Week uses the
same system behavior for cards containing the month and seven-day range. These
strips continuously expose adjacent periods without installing a gesture on
the full screen. Tapping a card selects it immediately. During a swipe the
visible cards move without changing the selected period; selection is committed
once the finger is released and the system snap reaches its idle phase. The
Task list below keeps independent vertical scrolling. Native search filters the
complete Task database by Task title, Area name/emoji, or hashtag and
groups results by scheduled date plus `日付なし`. macOS exposes matching
database-wide Task search in the toolbar. Days without visible Tasks for the
current filter are omitted when search is inactive. A horizontal swipe over the
Task content card
animates the current page out in the swipe direction and the adjacent day or
week in from the opposite edge after release; the direction check prevents
vertical list scrolling from triggering period navigation. The Flow
player context is a
visually bounded, Area-tinted system button so its picker affordance stays
clear. Editing an automatically generated Habit occurrence keeps its title,
memo, and hashtags editable, while Area, measurement, planned amount,
priority, scheduled date, and deadline remain read-only values inherited from
the Habit Area. `履歴` provides touch-native `日 | 週 | 月` calendar ranges:
day uses a chronological list of saved Flow/rest records and meaningful
internal gaps, week uses seven horizontally scrollable day columns, and month
uses Apple Calendar-style numeric days with Area-colored activity dots.
Its period navigation matches `タスク`: `日`
shows seven date cards, `週` shows previous/current/next week cards, and `月`
shows the month calendar above the selected History mode. These controls mark
only recorded Flow activity. Day and week use the same native horizontally
scrolling period strips across the `集中記録`, `タスク`, and `分野` modes, while the
timeline or aggregate content below keeps its own scrolling behavior. Their tap
and settled-swipe selection semantics match `タスク`. Native History search
filters the complete database by record title, Area, emoji, hashtag,
intent, or memo on both iPhone and macOS, independently of the selected calendar
period. Day content and week summaries can also animate between adjacent periods
with a horizontal swipe. Calendar-week content retains
its own horizontal timeline gesture instead. Flow
and rest remain separate calendar records and
tapping one opens its details. `分野` edits its emoji through a dedicated
searchable picker instead of a text-field leading icon. The standalone iPhone
`分野` uses the same types, goals, schedules, weekday rules, color palette,
archive behavior, item ordering, and group ordering as macOS in a native list
and editor. The standalone iPhone `統計` provides the same report contents and
filters as macOS in a touch-native vertical card workspace. Full drag-based
calendar/history editing remains deferred.

The iPhone app supports starting and controlling Flow, selecting today's Task or
Habit, completing Check Tasks, creating and editing Tasks and Areas, and
changing the basic shared settings. Private CloudKit synchronization carries the
same SwiftData records between devices signed into one Apple ID. Japanese is the
default language for a fresh install.

## Apple Watch Companion

Watch opens on a native four-page vertical pager in this order: `タイマー`,
fullscreen `流れ`, today's `タスク`, and today's `統計`. Every page occupies
the display; the system vertical page gesture or Digital Crown moves between
them. Task and mode pickers continue to use system `NavigationLink`
destinations.

The initial timer page keeps Task/Area context selection and the `集中モード`
selector above the player. The focus/rest ring sits on the left; `-5`,
Play/Pause, `+5`, destroy, stop, and break controls sit on the right, with the
primary Play/Pause action visually larger than secondary actions. Everything
remains on one non-scrolling screen. Memo confirmation uses a Watch sheet.

The fullscreen Flow page contains the stream and compact, material-backed
overlays for `今日の流れ`, Blocks, and `集中回数`. Tapping anywhere on the stream toggles an
immersive state that hides every overlay and leaves only the animation. It
intentionally omits the dashboard timeline and stops rendering while off-screen.

Tasks expose the same Check, Block-ring, and Minute-progress semantics as the
other platforms. A system `+` button opens a native form made only from pickers
and steppers: Area, Task type and target, priority, and date. It creates an
untitled Task whose visible placeholder comes from its Area, so Watch never
opens a keyboard. Statistics presents completion, focused time, Blocks, and
`集中回数`.

Opening or foregrounding Watch reconciles the canonical persisted active
session. CloudKit transports the same Task, Direction, mode, phase, and absolute
timer anchors; Watch never starts an independent timer state machine.

## System Notifications

macOS and iOS request alert, sound, and badge permission from the shared Flow
notification service. A completed focus interval is named by its `集中モード`
(`短め`, `標準`, or `じっくり`) instead of its Block value; Japanese completion
copy starts with `お疲れ様です。`. Break completion prompts the user to return to
`流れ`.

Focus and break each schedule an additional forgotten-timer reminder after 60
minutes of active phase time. Paused time shifts that deadline and does not
count toward the hour. Pausing, stopping, destroying, or changing phase cancels
obsolete pending reminders. Every delivered Flow notification sets badge `1`;
opening or foregrounding either app clears it.

## Live Activity

Starting an iPhone Flow creates one system Live Activity. It remains visible on
the Lock Screen and supported Dynamic Island devices until the Flow or its
connected break ends. Focus presentation includes Task title and emoji,
optional Area, remaining time, and timer progress. Break presentation
replaces that identity with `☕️ 休憩` and hides the Area. The clock is the
only content in the trailing column; mode and phase are not repeated below it.

Compact Island uses the Task emoji on the leading side and remaining time on
the trailing side; during a break it uses the coffee emoji instead. Minimal
Island uses a circular progress indicator. Expanded Island shows Task and
Area context, progress, and three
transport actions in the same order as the in-app player: subtract five minutes,
pause/resume, and add five minutes. Seek is disabled during a break. Lock Screen
content shows the same session identity, timer, and progress without
action buttons. Opening any activity routes to the `流れ` tab. ActivityKit
advances date-backed timer text and progress while the app is suspended; state
transitions still originate from `ActiveFlowStore`. The running surface uses
only WidgetKit-safe system timer text. After the canonical content state enters
overtime, it uses the same notation as the macOS menu bar:
`00:00 → +00:01`. A paused activity freezes the signed value captured in its
content state. If iOS suspends the application before the zero boundary, the
system countdown may remain visually at `00:00` until the next launch,
foreground transition, or other ActivityKit content update. The canonical Flow
continues from absolute timestamps. Version 1.x accepts this limitation;
guaranteed suspended-state overtime updates require the optional APNs transport
planned for 2.0.

## Home Screen Widgets

The iPhone Home Screen and macOS desktop expose the same three read-only WidgetKit configurations:

- `集中タイマー` in Small and Medium shows the active Task, optional Area,
  mode, phase, remaining `MM:SS`, and progress. Its empty state shows
  `集中中ではありません`. Tapping opens `流れ`.
- `今日のタスク` in Small, Medium, and Large shows the canonical Today list in
  priority order, completion count, and the same Check, Block-ring, or
  minute-fill progress semantics as the application. Tapping opens Tasks.
- `集中カレンダー` / Focus Calendar / Календарь фокуса uses a GitHub-style contribution grid: Small shows the latest 30
  days in `5 × 6`, Medium 60 days in `12 × 5`, and Large 90 days in `9 × 10`.
  Cells expand to the full widget content area without empty alignment cells,
  retain Area-mixed color, and use four relative intensity levels.
  Tapping opens Statistics.

Home Screen widgets intentionally have no transport or mutation controls. Live
Activity owns quick Flow controls, while regular widgets remain reliable
glanceable projections. Date-backed system views keep the timer moving while
the app is suspended; Tasks and the `集中カレンダー` refresh from immutable application-built
snapshots.

## Statistics

On macOS, the toolbar contains a direct icon-only `CSVを書き出す` Share action,
an Area filter, and the shared expanding Search control. The Share action
opens a dedicated popover for content (`すべて | 集中記録 | タスク`),
two inclusive `開始 / 終了日` date fields, Area, and text filter. The persistent
calendar centers the visible `週 | 月 | 年` segmented control and places an
icon-only `期間を指定` action at the trailing edge. This button opens a compact
system popover with inclusive start and end dates. Applying it deselects the presets and makes
the exact custom range the source for every card, calendar indicator,
comparison, and exported row; selecting a preset or a calendar period exits the
custom range. Filter and Search continue to affect the complete projection.

The main column is a vertical set of cards:

- combined totals for focused time, Blocks, `集中回数`, completed Tasks, and active
  Flow days;
- a Trend line chart with an independent `集中 | タスク` switch; its points are
  days for Week, seven-day totals for Month, and months for Year, with the
  previous equivalent period available as a separate comparison series and
  direct linear segments between points;
- focused-time distribution with `タスク別 | 分野別`, showing the largest
  slices and grouping the remainder as `その他`; clicking a sector keeps it
  bright, dims the others, and isolates that category in the center and legend;
- a `集中カレンダー` / Focus Calendar with its own `集中 | タスク` switch for the selected week,
  month, or year.

Trend and the focus calendar switch independently without a projection reload.
`集中` shows focused time; `タスク` shows completed Task counts. Week uses a full-width `集中カレンダー` card
with seven stretched cells, Month may share an adaptive row with Pie, and Year
uses a full-width 53-week grid. A custom range of seven days or fewer stretches
only its actual days across the full row. The preset Month stretches its seven
columns across the full focus-calendar card; every custom range longer than seven days uses small cells.
Medium custom ranges keep adding calendar cells through the
inclusive end date; longer ranges switch to compact week columns. Every real
Week, Month, or custom-range cell opens a non-interactive system hover bubble
above the card layer with date, focused time, `集中回数`, and completed Task
count. The Year focus calendar is display-only because its dense cells are not reliable
pointer targets. Month, Year, and custom ranges fit within the
available card width without horizontal scrolling. Search matches Task title, Area name or
emoji, hashtags, and available Flow text. A Flow that changed context is
searched and credited per persisted segment; matching one segment never
includes its siblings.

A persistent calendar column on the right mirrors Tasks and History. Its header
contains the centered preset control, trailing custom-range action,
selected-period title, previous, Today, and next navigation. Previous/next move
a custom range by its complete day count, while Today preserves that count and
ends the range today. Week uses direct week selection in the mini-calendar, Month uses
the year/month picker, and Year uses a compact year picker whose first entry is
the current year and which omits future years. Switching Week/Month/Year uses a
short opacity-and-scale layout transition. Clicking a focus-calendar day switches to the
single canonical `履歴` destination for that date; Statistics does not embed
History. The current period is clipped to today: future calendar dates are
disabled, Trend and the focus calendar omit future buckets, custom/export date fields cannot
pass today, and Next remains unavailable until a complete non-future period
exists.

The workspace paints its card shell immediately. A system progress indicator
appears inside placeholders while a new projection is calculated. Up to four
recent period/filter projections are kept as bounded presentation cache, and
visible background refresh is throttled so calendar navigation never waits for
SwiftData or CSV serialization.

CSV export is local and runs only when its popover is open. Combined export uses
stable machine-readable columns for date, Task, Direction, hashtags, focused
seconds/minutes, Blocks, Flow count, and completed Tasks; Flow-only and Task-only
exports omit the unrelated metric columns and empty rows.
The toolbar Area filter reuses the same
`circle.grid.2x2` symbol as the main navigation.

The iPhone Statistics view reuses the same bounded Week/Month/Year or exact
custom-range projection, comparisons, distributions, search, Area filter,
and CSV rows. The cards are stacked vertically. Period presets stay centered
above previous/Today/next navigation; tapping the period title opens a graphical
date sheet, and the calendar-clock action opens the two-field custom range
sheet. Share opens a native export sheet with content, inclusive start/end,
Area, and text filters. Pie selection has the same dim-and-isolate
behavior as macOS, while the Year `集中カレンダー` uses one compact full-width canvas to avoid a
horizontal scroller. Tapping a Week, Month, or custom-range focus-calendar cell opens a touch-sized daily detail sheet
with focused duration, `集中回数`, and completed Tasks; its action opens
`履歴`. The Year focus calendar has no tap target. Search is an icon-only trailing toolbar
action that expands only on demand. Screen-specific context actions use the
leading side: Tasks and Areas place their `その他` menu there, History
places its `集中記録 / タスク / 分野` mode there, and Statistics groups Share with its
Area filter there. Creation actions remain trailing beside Search. Every iOS
navigation destination uses a centered inline title. The `その他` Area may
appear because it represents real captured work.

## History Calendar

`履歴` is available directly below `タスク`, owns the canonical History presentation, and initially opens today. It preserves the date selected from Statistics. The user can move backward or forward by the selected range, choose a date, or use the mini-calendar on wide macOS windows. On macOS the filter sits immediately left of Search and changes with the active tab: `集中記録` visibility, `タスク / 習慣 / できたら`, or `いつでも / 習慣 / できたら`. In `集中記録 > 日`, `この日の記録` appears below the mini-calendar and reuses the canonical day totals.

The History mini-calendar marks only days that contain recorded Flow history, using the corresponding Area colors. Scheduled, pending, and future Task or Habit dates do not create History dots. On macOS and iOS, the History `タスク` and `分野` filters apply to both aggregate rows and the `日 | 週 | 月` calendar indicators. A Flow that switched context is filtered per persisted segment, so each indicator follows that segment's Task/Area type. Task calendars keep their separate indicators and apply the active `すべて | タスク | 習慣` filter.

History search follows the same segment boundary. A query that matches one
segment's Task or Area returns that segment only; it must not surface a
sibling segment merely because both belong to the same FlowSession. Opening,
editing, or deleting that result targets the exact displayed segment while
preserving the other Task/Area intervals in the session.

The primary `カレンダー` mode provides:

- `日`: a chronological vertical timeline of every actual Flow and rest record for the selected app day, with stable-size cards, chain rails only across continuous persisted records of the same series, spacious internal `記録なし` gaps, and a separate system sheet for the canonical editor;
- `週`: seven synchronized day columns in one vertically scrollable hour grid; each connected Flow series is one composite block that opens a detailed vertical series timeline with push navigation to each record editor;
- `月`: a single vertically scrolling surface with the seven-column month overview
  followed immediately by the selected day's records. Scrolling down naturally
  moves the calendar offscreen; scrolling back to the top restores it. The
  records use the complete vertical timeline and the same record editors as `日`;
  no intermediate summary or separate day sheet is used.

On macOS, History follows the same two-level hierarchy as Tasks. The system title
toolbar centers the compact `集中記録 | タスク | 分野` selector, keeps the Flow/rest
filter on the leading side, and places an icon-only expanding search action on
the trailing side.
The persistent calendar/inspector column owns a two-row header: centered
`日 | 週 | 月` first, then the active date or period on the left and
`‹ 今日 ›` navigation on the right. There is no duplicate full-width calendar
control panel above the workspace, and the embedded month/year picker does not
repeat its own arrows. The shared period state updates both the calendar workspace
and its inspector. On wide macOS layouts, range changes animate only the primary
calendar workspace; the persistent calendar/inspector column does not transition.
Its width follows the localized period title and `今日` action rather than a
fixed value. The visible `表示` label and duplicate in-content filters are removed.
`タスク` and `分野` use a wide two-column layout with
aggregates on the left and a mini-calendar plus range summary on the right. At
compact widths, the calendar and summary stack above the aggregate list.

On iPhone, the leading History dropdown switches between the same `集中記録`,
`タスク`, and `分野` modes without duplicating date navigation. The system Search
toolbar item is an icon-only magnifying glass and expands only when selected.
Task and Area aggregates use the active `日 | 週 | 月` interval. Task History
only lists items with recorded focused time; scheduled or completed Tasks with
`0分` are omitted on both platforms.

In `日`, the right pane keeps the only wide-layout mini-calendar and no longer duplicates selected Flow or rest properties below it. Flow/rest visibility uses the shared icon-only control row filter; there is no separate filter rail or timeline-header filter. The main area immediately shows the whole selected app day's saved records in chronological order rather than requiring a series selection first. Selecting a Flow or rest opens its canonical editor in a separate system sheet, leaving the Day timeline structurally unchanged. Changing the day clears the selected record. A record's card remains comfortably clickable even when its actual duration is very short. The vertical rail connects only adjacent persisted records with the same series ID and continuous timestamps; an unrecorded interval starts a new chain even if later data retains the old series ID. Internal gaps of at least one hour are shown between neighboring records as a centered time range with `記録なし` and extra vertical spacing; leading and trailing empty hours are omitted.

Week keeps date headers fixed while hours scroll. Its right mini-calendar highlights the complete selected week, and choosing any date selects that week. Opening a day/week grid scrolls near the current time when today is visible, otherwise near the first Flow. A red line marks the current time. On macOS, Month keeps a minimum full-grid width and a right `1月...12月` year picker; a crowded day uses `詳細` to open its complete timeline. On iPhone, Month instead keeps the calendar and selected day's full timeline in one vertical scroll surface, so no second sheet or summary list interrupts navigation. Medium/narrow layouts preserve stable calendar widths through horizontal scrolling.

Flow and FlowSegment records remain separate persisted records colored by Area. FlowBreak records remain separate light-gray records. In `週`, `seriesID` is used only to draw a composite series block; clicking it reveals each persisted Flow and rest record in a vertical detail timeline. Selecting a detail pushes its canonical editor inside that sheet, and the leading Back control returns to the series timeline rather than replacing the sheet. The Flow editor uses the same `タスク・習慣・分野` picker and Task composer as the player, while the rest editor uses a smaller content-fitted presentation. The sheet animates its window size while moving between the series timeline, Flow editor, and compact rest editor. The Flow dashboard independently uses `seriesID` for its continuous rail. Todo completions and pending Tasks never become independent History Calendar blocks.

Lane assignment uses exact stored start/end intervals. Contiguous Flow and rest records stay in one vertical lane, and only actual time overlap creates side-by-side lanes. Entries below 15 minutes use compact title-only rendering; short rests become thin gray bars and expose exact time through hover and accessibility.

Selecting an entry reuses the Flow history inspector or `FlowBreakEditor` on
both macOS and iOS. Area-only Flow is also selectable: its result, Area,
and exact time can be edited without creating a Task. The inspector can
optionally link an existing Task or open explicit `タスクを追加` with the
Flow's Area and date preselected; finishing or editing Flow never creates
a Task automatically. Completing `タスクを追加` from the Flow inspector
immediately attaches the created Task to the edited Flow or task-switch segment,
reconciles measured progress, and refreshes an already open `一連の記録`
timeline without closing and reopening it. Other inspector draft changes still
use the explicit Save action. A completed Flow can be dragged to another exact day/time
in day and week, or to another date in month; the complete session and its
task-switch segments move together without changing duration or measured
progress. Active Flow and rest records are not draggable. Double-clicking empty
time inserts a selected `新しい集中記録` draft block directly into the calendar.
The clicked time is rounded to five minutes and the default duration is 25
minutes. In wide day view, `集中記録を追加` occupies the right inspector; Task,
Area, `短め / 標準 / じっくり`, linked start/end, and minutes update the visible
draft block immediately. Compact day and week use a sheet while retaining the
draft block in the grid. Saving creates a completed independent Flow series and
applies normal Area/Todo progress without completing the Task; manual rest
creation is intentionally unavailable.

On macOS and iOS, `+` sits in the top-right History toolbar beside Search and opens the shared record form using the platform presentation convention: a trailing inspector on macOS and a sheet on iOS. On macOS, pressing `+` again closes the inspector. `キャンセル` and `記録` remain inside the record form instead of being promoted into the window toolbar. Clicking or tapping an empty time in the weekly calendar opens the same form with that day and time preselected.

The form follows the active History mode. `集中記録` opens a Flow-specific form with `タスクなし` selected by default; its picker may optionally link an existing Task, Habit, or Area, but saving always creates Flow and never completes a linked Check Task. `タスク` limits the picker to Task and Habit, offers new Task creation, and applies the selected unit's completion/progress semantics. `分野` limits the picker to Area and creates Area-only Flow. Habit lists every eligible Habit Area for the selected day; when no Todo occurrence exists, saving materializes the historical occurrence from its internal `Direction` template. A Task/Habit progress preview is shown only when the operation changes that progress.

Check requires a date and accepts an optional exact time; it writes historical completion without inventing Flow. Block, Minute, and Area-only records require explicit start and end times, create a completed independent Flow, and rebuild measured progress from persisted history. Zero-Flow scheduled Tasks remain absent from the actual History summary. The row action with a fixed Task remains available as the faster manual-Flow path. Expanded `履歴 > 分野` ends with `タスクを追加`, which creates a Task with fixed Area but no Flow. The calendar does not provide direct resize and does not persist a second calendar entity.

## Settings

`設定` opens through the native macOS Settings scene. `テーマ` offers system,
light, and dark appearance. `言語` lists the String Catalog localizations plus
the system language and clearly marks that changing it requires relaunching the
app. `週の開始日` offers system, Sunday, Monday, and Saturday; it updates Task,
History, and Statistics week layouts immediately. `時刻表示` offers system,
12-hour, and 24-hour clocks and updates locale-aware time labels immediately.
`新しい日の開始` selects an hour from `00:00` through `23:00`; the default is
`00:00`. Before the selected boundary, Today, generated Habits, Flow daily
summaries, History/Statistics grouping, watchOS, and widgets continue to use the
previous logical day. Changing it takes effect immediately and does not rewrite
stored Task dates or Flow timestamps.

The bottom of the macOS sidebar contains a system `設定` gear that opens this
same Settings scene. The `データ` section on macOS, iPhone, and iPad offers
`集中履歴をすべて削除`. It is disabled while a Flow is active. A destructive
confirmation explains that all FlowSession, FlowSegment, and FlowBreak records
will be removed from every device through private CloudKit and cannot be
restored. The operation runs in a model actor so Settings remains responsive.
Tasks, Areas, Task notes, and manually checked state remain; all
Flow-derived Task and Area progress is reset.

The shared `フィードバック` section appears before destructive data controls. It
opens the GitHub issue-template chooser and presents the same public-data and
TestFlight guidance on macOS, iPhone, and iPad.
