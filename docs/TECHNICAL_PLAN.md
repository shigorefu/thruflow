# Technical Plan

## Architecture

The canonical source layout and dependency rules are documented in
`docs/ARCHITECTURE.md`. Keep separation between:

- domain models: Direction, Todo, FlowSession, FlowSegment, FlowBreak;
- domain logic: validation, filtering, planning, progress, timer, statistics;
- services: notifications and platform bridges;
- SwiftUI features.

SwiftUI views should call domain logic instead of owning product rules directly.

The macOS application shell and complete feature screens live under
`Platforms/macOS`. The separate `ThruFlow iOS` target owns a narrow iPhone UI
under `Platforms/iOS` and never imports the macOS folder. Both targets depend on
the models, logic, application state, services, and small controls in `Shared`.

Normal app composition uses the private CloudKit database in
`iCloud.com.shigorefu.thruflow`. Tests explicitly use an in-memory local store.
The iOS deployment target is 17.0 even when building with Xcode 26 and the iOS
26 SDK; iOS 26-only APIs require availability guards and an explicit product need.

## Current Data Rules

- `DefaultDirections` resolves system `その他`.
- `TodayTodoFilter` includes only scheduled tasks for the selected day.
- `TaskCalendarBuilder` creates deterministic visible date ranges and month grids.
- `TaskRescheduleService` validates kanban and month-grid drag-and-drop.
- `TaskBacklogBuilder` derives overdue and undated active normal Tasks for the Today section and Tasks inspector without adding persistence state.
- `RequiredTodoPlanner` decides whether a scheduled Habit Task is eligible.
- `HabitTodoMaterializer` is the only macOS/iOS persistence entry point for automatic Habit generation. Its full path fetches fresh SwiftData state, normalizes dates, runs `HabitTodoReconciler`, and invokes the planner. Date navigation may use its lightweight path with the current Todo snapshot; that path is debounced, skips Flow-history reconciliation, and persists only when a Habit occurrence must actually be created or moved.
- `HabitTodoReconciler` repairs duplicate active Habit occurrences for the same Direction/day, preserves related Flow history and progress, and soft-deletes redundant rows.
- `FlowProgressCalculator` defines focused-time conversion for isolated calculations.
- `FlowProgressReconciler` rebuilds measured Todo progress/completion and Direction focus totals from credited Flow history after every history mutation and once at app launch.
- `Todo.notes` stores memo.
- `FlowSession` stores timing/history.
- `FlowSegment` stores Task/Direction intervals and cumulative focused-second boundaries within a FlowSession.
- `FlowBreak` stores explicit rest and UUID links between adjacent sessions in a Flow series; `FlowSeriesPolicy` owns continuation windows and Long Break thresholds.
- `Todo.completedAt` stores the exact completion time for new completions.
- `DayHistoryBuilder` creates daily Task/Direction aggregates and legacy day projections.
- `HistoryCalendarBuilder` creates day/week/month calendar projections from actual Flow and break records; Todo completion never creates a calendar item. `FlowHistoryEditor` moves a completed FlowSession and all of its segments by one shared time offset for calendar drag-and-drop.
- `FlowDashboardBuilder` groups connected records by `seriesID` into continuous dashboard series spans without mutating calendar history.
- `HistoryDayTimelineWindowBuilder` derives the testable Elastic/full-day hour range independently from SwiftUI, including records that cross midnight.
- `HistoryOverlapLayout` assigns deterministic side-by-side lanes using actual and minimum visual duration so short records cannot overlap in rendering.
- `FlowHistoryEditor` creates independent completed manual Flow records and delegates affected progress rebuilding to `FlowProgressReconciler` when history changes.
- `FlowDashboardBuilder` derives today's totals, Direction palette, and timeline segments from `FlowSession`, with a live overlay for the active creditable Flow.
- `DashboardStatisticsBuilder` derives seven-day bars, previous-day deltas, and the most-grown Direction outside SwiftUI.
- `FlowVisualState` converts 0...6 daily Blocks into clamped speed, volume, detail, depth, glow, and mode-specific wave character without placing those rules in SwiftUI. Ribbon count remains fixed at seven.
- `DailyFlowAppearance` derives a stable cross-device topology from the local date and oldest synced Direction UUID. It has no time-of-day input. `FlowStreamShader.metal` renders that topology as one GPU effect and weights Direction colors by actual focused seconds. The SwiftUI host supplies only accumulated phase and visual-state uniforms, targets 30 FPS while idle and 60 FPS while active, and pauses when its window is not key, the scene is inactive, or Reduce Motion is enabled. `FlowAnimationClock` preserves phase when speed changes or rendering pauses, so starting Flow and returning to the window never replace the current stream frame. Dark and light themes use separate compositing paths.
- The pre-daily-identity renderer is retained as source-only reference under `docs/archive/legacy-flow-stream` and is not included in any app target.
- The dashboard reuses `FlowMiniPlayerView` behavior through its dedicated dashboard layout instead of creating a second timer controller. `ActiveFlowStore.phaseProgress` provides the circular timer progress.
- The dashboard and Tasks surfaces project Todo groups and use the shared `HabitTodoMaterializer` to ensure Habit instances exist without creating duplicates across views or platforms.
- `TodoProgressControl` is the shared Check/Block/Minute control used by Tasks and the dashboard.
- `TaskCompletionFeedbackPlayer` deduplicates completion feedback by Task or
  Flow identifier. On iOS it emits the system success haptic for an actual
  incomplete-to-complete Task transition and for a successfully finalized Flow;
  on other platforms haptics are a no-op. It optionally plays
  `task-complete.caf` for Task completion, and absence of that resource is
  supported. The shared progress control owns the completion drawing/pulse and
  respects Reduce Motion.
- `LiveActivityService` is the platform-neutral output port owned by
  `ActiveFlowStore`. `IOSFlowLiveActivityService` is the ActivityKit adapter;
  the Widget Extension receives only shared `FlowActivityAttributes` and never
  accesses SwiftData. Date-backed timer ranges provide system-driven Lock Screen
  and Dynamic Island updates while the app is suspended. Shared Live Activity
  intents delegate expanded-Island `-5 minutes`, pause/resume, and `+5 minutes`
  actions to the existing `ActiveFlowStore` operations; the extension contains
  no timer mutations.
- `IOSFlowLiveActivityService` also converts the same immutable content into a
  `FlowTimerWidgetSnapshot`, stores it in App Group
  `group.com.shigorefu.thruflow`, and reloads only `FlowTimerWidget`. The Widget
  Extension reads that Codable snapshot and uses system date-backed timer and
  progress views. The Home Screen widget never opens SwiftData, schedules a
  per-second timeline, or owns transport behavior.
- `IOSProductWidgetSnapshotSyncView` observes Todo, Direction, and FlowSession
  changes in the iOS application. `ProductWidgetSnapshotBuilder` produces the
  canonical Today Tasks and 180-day Flow Dots projections, then stores Codable
  snapshots in the same App Group and reloads `TasksWidget` and
  `FlowDotsWidget`. The Widget Extension only renders those snapshots and
  schedules a next-day refresh.
- iOS day/week paging uses a bounded, recentering `IOSScrollablePeriodStrip`
  window instead of constructing years of SwiftUI cells. Day and week activity
  dots are indexed once per data snapshot rather than filtering complete Todo
  or Flow collections for every visible cell. Scrolling must not synchronously
  fetch complete Flow history, reconcile duplicates, save SwiftData, or trigger
  CloudKit export work. Month views advance one calendar month per horizontal
  swipe without retaining a separate long-running month strip.

## Test Expectations

Cover:

- Direction validation and legacy raw value normalization.
- Todo validation and daily Task filtering.
- Calendar range, filtering, and rescheduling tests.
- Habit task generation.
- Block conversion and progress.
- Flow timer transitions, five-minute remaining-time adjustments, one-minute
  lower bound, mode changes without elapsed-time reset, and actual-time rest
  thresholds.
- Statistics range construction and filters.
- Day-history grouping, legacy untimed completions, deterministic Flow progress reconciliation after create/edit/delete, and duration-preserving Flow moves.
- Manual Flow creation, linked Task progress without implicit completion, and fixed-Direction Task creation.
- Flow series continuation, Long Break thresholds, rest correction, and same-series downstream shifting.
- Flow dashboard totals, palette ordering, day filtering, live minimum-credit behavior, and timeline normalization.
- Dashboard statistics distribution, seven-day trend comparisons, and completion projection.
- Live Activity content projection for focus, break, and paused phases, plus
  deterministic shared formatting.
- Home Screen timer-widget snapshot mapping, App Group persistence round-trip,
  and clear behavior.
- Today Tasks widget filtering, priority ordering, measurement progress, and
  Tasks/Dots snapshot persistence.
- Flow Dots reuse of the canonical 180-day statistics projection and mixed
  Direction color.

## Migration Caution

Avoid removing SwiftData fields such as `FlowSession.result` without a deliberate migration step. It can remain as legacy-compatible storage while new memo writes go to Todo.
