# Version 1.0 scope

Version 1.0 goal:

```text
Direction -> Task -> Flow -> actual focused time -> progress -> statistics
```

## Included

- Direction management for `通常`, `習慣`, and `ナイス`.
- System Direction `その他`, hidden only from Direction management so it cannot be edited.
- Daily `タスク` list.
- Calendar kanban ranges: `日`, `週`, and `月`.
- Task/Habit filters and validated drag-and-drop between dates.
- Today overdue section and counted undated-Task inspector.
- Automatic habit tasks.
- Sequential weekly-count Habit generation and safe rescheduling.
- Quick task capture.
- Task measurements: `チェック`, `集中ブロック`, `分`.
- Flow player with Sprint, Focus, and Deep modes.
- First/default `Flow` dashboard with expanded player, animated daily stream, totals, and Elastic Flow timeline.
- Task switching inside an active Flow through persisted Flow segments.
- Persisted Flow series, editable rests, continuation windows, and a 20-minute `長休憩` after every 4 Blocks in a series.
- Manual break start with memo before break begins.
- Shared square memo panel in the dashboard and macOS menu bar player.
- Per-Flow memo storage in `FlowSession.result`, mirrored to `Todo.notes` when linked.
- Canonical `履歴` with Flow calendar and Task/Direction aggregates for `日`, `週`, and `月`.
- Manual historical Flow creation and correction without automatically completing a linked Task.
- Dashboard statistics carousel for time distribution, a 7-day Flow trend, and completion status.
- Flow and Tasks contribution-style statistics.
- Configurable combined, Flow-only, and Task-only Statistics CSV export.
- Private CloudKit synchronization between the user's signed-in Apple devices.
- Flow-first iPhone and iPad app with the animated stream above the complete player,
  separate full-width Tasks and Statistics dashboard cards, and a persistent
  five-item material navigation surface: `Flow`, `タスク`, `履歴`, `方向`, and
  `統計`. The Tasks screen replaces that surface with quick capture; the native
  tab bar minimizes while content scrolls down and returns when scrolling up.
  Basic `設定` remains in the trailing More menu.
- iPhone Flow dashboard parity for the actionable surfaces: the Task card can
  switch between `タスク / 習慣 / ナイス`, provides inline quick capture next
  to the Tasks deep link (bottom composer on iPhone, anchored popover on iPad),
  and Statistics uses the same three-page
  time-distribution, seven-day trend, and completion carousel as macOS.
- Shared `Sprint | Focus | Deep` segmented selection and mode Help on macOS and
  iPhone.
- iPhone live quick-input suggestions, arbitrary and no-date Tasks, overdue and
  no-date inboxes, day/week/month Task ranges, automatic Habits, native Task
  editing, ordered Direction groups, and a dedicated Direction emoji picker.
- Animated completion feedback for Check, Block, and Minute Tasks.
- iPhone Live Activity and Dynamic Island player for an active Flow, including
  system-updating time/progress, Task and Direction context, expanded
  seek/pause controls, and deep-link return to the Flow screen.
- iPhone Home Screen and macOS desktop `Flowタイマー` widgets in Small and Medium sizes, with
  system-updating time/progress, active Task and Direction context, an empty
  state, and deep-link return to Flow.
- iPhone Home Screen and macOS desktop `今日のタスク` widgets in Small, Medium, and Large sizes,
  with Today ordering and Task measurement progress.
- iPhone Home Screen and macOS desktop `Flow Dots` widgets in Small, Medium, and Large sizes:
  GitHub-style `5 × 6`, `12 × 5`, and `9 × 10` grids show the latest 30, 60,
  or 90 days using canonical Flow statistics colors.
- watchOS Flow companion with a native four-page vertical dashboard for
  `タイマー`, fullscreen `Flow`, today's `タスク`, and compact `統計`.
- Shared active-Flow restoration through the CloudKit-backed SwiftData store:
  opening the Watch adopts the same Task, Direction, mode, phase, and elapsed
  time as macOS or iPhone.
- Shared seven-card first-run introduction over the real macOS, iPhone, and
  iPad workspace: one centered card above a uniformly dimmed feature screen,
  no target spotlight or automatic scrolling, a final product-loop summary, a
  clean in-memory preview path, and a Settings replay action. watchOS remains a
  companion and does not repeat onboarding.
- Optional support in Settings: App Store review, GitHub, and consumable Coffee
  (JPY 100) / Ramen (JPY 500) StoreKit tips that unlock no features.
- Cross-platform Settings feedback entry that opens the public GitHub issue
  templates, warns about private Task content, and explains TestFlight's native
  screenshot feedback path.
- A non-promotional StoreKit review request after seven days and meaningful
  completed-Flow use, at most once per app version.
- Native Settings on macOS, iPhone, and iPad can irreversibly delete all Flow
  and break history after confirmation while preserving Tasks, Directions,
  Task memos, and manually checked state; the macOS sidebar exposes Settings
  through a bottom gear.

## Not Included

- AI.
- Author-operated APNs backend; reliable suspended-state Live Activity updates
  are planned for 2.0.
- External Connectors such as Toggl, Strava, and Jira; they are planned for 2.0.
- Non-Flow continuous timeline.
- Food/sleep/game classification.
- Complex rewards.
- Accounts/subscriptions.

## Known Product Gaps

- If iOS suspends the application before a Flow crosses zero, Live Activity can
  remain visually at `00:00` until the next application launch or foreground
  update. Canonical Flow time still advances from persisted absolute dates.
