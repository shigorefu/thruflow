# Architecture

## Goal

ThruFlow keeps one product model and one persistence model while allowing each
Apple platform to provide its own application shell and feature presentation.
macOS remains the complete desktop editing and analysis surface. The iPhone app
uses a separate, Flow-first presentation that reuses the same domain, application
state, and persistence schema without copying the desktop UI.

## Source Layout

```text
ThruFlow/
  Shared/
    Domain/
      Models/       SwiftData entities and stable enums
      Logic/        Pure calculations and product rules
      Services/     Platform-neutral protocols and shared implementations
    Application/    Shared observable state and use-case orchestration
    LiveActivity/   Shared ActivityKit attributes, content state, and intents
    Widget/         Cross-process WidgetKit snapshots and App Group storage
    UI/             Small reusable SwiftUI components
  Localisation/     Shared Apple String Catalog used by every platform target
  Platforms/
    macOS/
      App/          macOS scene composition and application delegate
      Features/     Current macOS feature screens
      Support/      AppKit adapters used by the macOS presentation layer
    iOS/
      App/          iPhone composition root, navigation, entitlements, and Info.plist
      Features/     Native iPhone Flow, Tasks, History, Areas, Statistics, and Settings
      Support/      ActivityKit and other iOS framework adapters
    watchOS/
      App/          Watch composition root and CloudKit entitlements
      Features/     Native Watch Flow dashboard, player, Tasks, and Statistics
ThruFlowLiveActivity/  Widget extension for Live Activity and Home Screen widgets
```

`ThruFlow`, `ThruFlow iOS`, and `ThruFlow Watch App` are separate application
targets. Explicit source exclusions keep AppKit, UIKit, ActivityKit, and
platform-owned presentation code out of incompatible targets. Shared tests
remain in the macOS test target because they verify the platform-neutral core.

## Dependency Rules

Dependencies point inward:

```text
Platforms/macOS  ─┐
Platforms/iOS    ─┼──> Shared/Application ──> Shared/Domain
Platforms/watchOS ─┘              │
                  └──────────────> Shared/UI
```

- `Shared/Domain/Models` owns persisted entities and stable raw values.
- `Shared/Domain/Logic` owns product calculations and cannot import SwiftUI,
  AppKit, or UIKit.
- `Shared/Domain/Services` exposes capabilities used by shared application
  state. Implementations may use Apple frameworks available on every supported
  platform, such as UserNotifications.
- `Shared/Application` coordinates domain operations and persistence. It may
  import Foundation, Combine, and SwiftData, but not AppKit or UIKit.
- `Shared/LiveActivity` owns the iOS ActivityKit attributes, immutable content
  state, formatting, and App Intents shared by the application and extension.
- `Shared/UI` contains only components whose behavior and layout are intended
  to remain common across platforms.
- `Localisation/Localizable.xcstrings` owns user-facing copy for every platform;
  Japanese is the source and fallback language.
- `Platforms/macOS` owns navigation, windows, menu-bar scenes, keyboard/focus
  integration, drag-and-drop presentation, and the current desktop layouts.
- `Platforms/iOS` owns the adaptive iPhone/iPad presentation. Compact widths use
  the Flow-first tab shell; regular widths use a Mac-like split view with a
  persistent sidebar and the same native Flow, Tasks, History, Areas,
  Statistics, and Settings destinations.
- `Platforms/watchOS` owns the four-page vertical Watch dashboard, compact
  player, Tasks, Statistics, and fullscreen Flow stream presentations.
- iOS date navigation owns a bounded virtual window around the selected day or
  week. It recenters only after scrolling settles, so infinite-feeling paging
  does not retain thousands of date-card views.
- `ThruFlowLiveActivity` owns Lock Screen, Dynamic Island, and Home Screen
  widget rendering. It does not open SwiftData or create another timer state
  machine.
- Platform-specific behavior is reached through small adapters in the owning
  platform folder. Shared code does not use conditional AppKit/UIKit imports.

## Application Composition

Each platform owns its composition root:

- `Platforms/macOS/App/ThruFlowApp.swift` declares the macOS scenes.
- `MacOSRootView` owns desktop navigation and feature presentation.
- `MacOSAppDelegate`, menu-bar presentation, window behavior, focus handling,
  and AppKit integration remain inside `Platforms/macOS`.
- `AppModelContainerFactory` creates the shared SwiftData container without
  importing a platform UI framework.
- `ActiveFlowStore` is shared application state. Platform views observe and
  control it but do not create a second timer state machine. It publishes a
  platform-neutral `FlowLiveActivityContent` projection through
  `LiveActivityService`; the iOS adapter translates that projection into
  ActivityKit state.
- `ActiveFlowSyncCoordinator` resolves the canonical active `FlowSession` from
  SwiftData and reconstructs its `FlowTimerState`. It contains no timer
  calculations. Both composition roots invoke the same reconciliation path on
  launch, foreground entry, a low-frequency active-scene cadence, and completed
  CloudKit imports received while the process can run. Foreground polling stops
  with the scene, while import observation remains installed so a remote stop
  can cancel obsolete local notifications without reopening the app.
- `AppSettings` owns typed local preferences and derives the effective
  `Calendar`, `Locale`, and `AppDayBoundary`. Platform composition roots inject
  those values into their scene environments; settings never enter SwiftData.
  `AppDayBoundary` is the shared, DST-aware authority for deciding which
  logical day contains an instant. Domain builders accept it explicitly so
  Tasks, Habits, Flow, History, Statistics, watchOS, and widgets cannot develop
  platform-specific midnight rules.
- `OnboardingStore` owns the local first-run completion flag, launch kind,
  guided/read-only experience, deterministic ten-step screen projection,
  pending editor presentation, IDs of user-confirmed onboarding records, and
  transient Flow-preview state. It never inserts an Area or Task itself; the
  platform's normal editor/composer reports a saved stable ID only after the
  user confirms creation. The preview drives the shared production Flow-player
  presentation components from a local scripted projection: Task-card press and
  selection, Play press, accelerated Short focus from `12:00` to `00:00`, break
  press, and the demonstrated `03:00` regular-break state. It does not invoke
  `ActiveFlowStore`, present or submit the production note panel, or reach
  persistence. The real player continues focus while that note is open and
  begins its break only after note confirmation.
- `OnboardingWorkspaceInspector` derives whether real user Areas, Tasks, or Flow
  history already exist. Platform roots use that value once the workspace is
  available: an empty first run can be guided, while an existing workspace and
  every Settings replay are read-only. The roots keep the real workspace mounted,
  follow the requested onboarding screen, and own native editor/sheet/popover
  presentation. Signed CloudKit runs keep the first empty snapshot unresolved
  until a successful initial import event or a bounded four-second grace period,
  then inspect the workspace again. The same fresh inspection runs before an
  onboarding Area or Task save is accepted; late imported content changes the
  remaining journey to read-only without discarding an open draft. Settings is
  dismissed before replay begins. `--onboarding-preview` forces the journey while
  `--uitesting` keeps confirmed preview records inside an in-memory application
  container.
- `ReviewPromptPolicy` is a deterministic value policy. `ReviewRequestGate`
  queries completed Flow history only at application entry or after the shared
  `flowDidComplete` event, then delegates presentation to StoreKit's system
  `requestReview` action. The last requested application version stays in local
  preferences and is not synced.
- `SupportPurchaseStore` remains a dormant StoreKit 2 boundary for possible
  future optional consumable tips. The first App Store release does not inject
  or present it. If re-enabled, it accepts only verified transactions, finishes
  them, and exposes no entitlement because support purchases unlock no
  functionality.
- `AppDataResetActor` performs the user-requested application-data reset away
  from the main UI. `AppDataResetService` rejects an active Flow and deletes
  every Direction, Todo, FlowSession, FlowSegment, and FlowBreak in one save.
  Platform Settings own confirmation and presentation, then clear the local
  timer selection and restart first-run onboarding. AppSettings preferences are
  intentionally outside the reset service.

- `Platforms/iOS/App/ThruFlowiOSApp.swift` declares the universal iPhone/iPad scene and injects
  the same `ActiveFlowStore`, `AppSettings`, calendar, locale, and model schema.
  It also registers the Live Activity control dependency used by system actions.
- `Platforms/watchOS/App/ThruFlowWatchApp.swift` declares the Watch scene and
  injects the same model schema, settings-derived calendar/locale, and
  `ActiveFlowStore`. It reconciles persisted active Flow state on appearance
  and foreground entry instead of creating a Watch-only timer.
  The Watch does not compile onboarding, review-presentation, or support-store
  UI; those surfaces are owned by the companion iPhone/iPad/macOS application.

## Feature Boundaries

- Views transform user interaction into calls to application/domain operations.
- Product calculations, validation, scheduling, reconciliation, statistics,
  and timer transitions belong in `Shared/Domain/Logic`.
- Database-wide Task and History search matching, date grouping, and aggregate
  scope belong in `Shared/Domain/Logic`; platform views only select a mode and
  render the resulting sections or snapshots.
- History chronology and series projection are shared domain projections.
  `HistoryCalendarSeriesProjector` builds connected Flow/rest series,
  `HistoryTimelineChainPolicy` decides whether adjacent records share a rail,
  and `HistoryVerticalTimelineEntry` interleaves persisted records with
  presentation-only internal gaps. macOS and iOS must consume these projections
  instead of independently inferring series, gaps, or ordering in SwiftUI.
- Flow and rest editors operate on the same persisted entities on both
  platforms. Rest duration changes go through `FlowBreakEditor`; platform views
  may present that editor as a macOS window or iOS sheet but may not implement a
  second mutation path.
- High-frequency presentation state such as scroll position must not directly
  start full-store reconciliation or persistence writes. iOS date strips index
  visible markers once, debounce Habit materialization, and reserve duplicate
  and Flow-history reconciliation for entry or structural data changes.
- Persistence orchestration shared by platforms belongs in
  `Shared/Application`; direct platform presentation does not.
- Reusable UI belongs in `Shared/UI` only when behavior and layout are genuinely
  the same across owning platforms. Sharing a large desktop screen to avoid a
  platform-native presentation is not a valid abstraction.
- `FlowStreamSurface` and `FlowStreamShader.metal` form one shared Metal render
  path for macOS and iOS. `DailyFlowAppearance` derives a deterministic daily
  seed from the local calendar date and the oldest synced Direction UUID, so
  the same user's devices render the same daily topology without adding a new
  persisted setting. The topology is independent of time of day.
- `FlowVisualState` maps actual daily focus into depth, glow, detail, and
  motion. At zero progress the shader preserves the baseline six-ribbon
  neutral S-stream. `identityReveal` blends it into the seven-ribbon daily
  topology over the first canonical Block; there is no renderer swap or phase
  reset. The shader accumulates colored ribbon cores and wider halos
  independently, preserving visible diffusion without washing the ribbon
  centers toward white.
  `FlowRenderCadence` owns the explicit 30 FPS idle / 60 FPS active contract.
  Platform wrappers only decide when rendering pauses: macOS requires the key
  window, while iOS requires an active scene. Pausing freezes the shared
  `FlowAnimationClock` phase instead of rebuilding the picture. The render
  surface is equatable and advances from monotonic uptime, so unrelated
  one-second timer updates neither rebuild it nor interrupt its phase. The
  shared store keeps its display clock non-publishing; timer panels and the
  macOS menu bar label own narrowly scoped periodic timelines instead.
- `ActiveFlowStore` publishes a transient sequenced `FlowBreakInteraction` for
  each valid rest request and each confirmed rest start. It is application/UI
  state only: it never enters SwiftData, CloudKit, runtime synchronization, or
  history. `FlowStreamSurface` combines that cue with the derived regular/long
  break style. macOS and iOS use the shared Metal pass; watchOS mirrors the same
  spread and glow parameters in its shared Canvas renderer.
- The renderer has separate dark additive and light ink-style composition
  paths. Palette weights come from actual focused seconds per Direction.
- Desktop-specific dashboard layout remains macOS-owned.
  Each other platform receives its own explicit implementation and performance budget.

## Persistence

The existing SwiftData models and schema remain the single source of truth.
Normal signed app runs use the private CloudKit database in
`iCloud.com.shigorefu.thruflow`. Tests use an in-memory local configuration, and
the iOS Simulator uses a persistent local configuration because its builds do
not contain the iCloud container entitlement. The
`THRUFLOW_DISABLE_CLOUDKIT=1` or `--local-store` provides an explicit local-only
escape hatch. CloudKit availability must never be a precondition for domain
logic or tests.

All derived progress must be reproducible from persisted history. Mutations to
Flow history go through the shared reconciliation logic rather than applying
view-local relative deltas.

SwiftData fetches and saves that affect user data propagate errors to an
application boundary; they must not use `try?` or substitute an empty result.
`PersistenceIssueCenter` owns structured logging, rollback for failed saves,
and one platform-neutral recovery alert. Background maintenance may log an
error without interrupting the user. Lossy widget caches, optional JSON
preferences, and cancellation-only sleeps may still discard errors because
their failure does not claim that user data was saved or loaded successfully.

Every shipped executable declares its required-reason API use in a bundled
`PrivacyInfo.xcprivacy`. The main app and Watch bundle declare app-local
UserDefaults (`CA92.1`) and App Group defaults (`1C8F.1`); the widget/Live
Activity extension declares only its App Group snapshot access. No target
declares tracking or developer-accessible collected data. Private CloudKit
records remain owned by the user and are not visible in the developer portal;
the App Store privacy answers and public privacy policy must still explain the
private iCloud synchronization accurately.

Active timer synchronization follows the same local-first rule. Every timer
transition is written to the active `FlowSession` with absolute anchors and a
new runtime revision. CloudKit is transport, not the timer authority.
Concurrent active sessions are resolved in shared application code; platform
views never choose a winner. The iOS Live Activity remains a projection started
or updated after iOS adopts the persisted runtime.

## Test Boundaries

- Domain rules are tested without SwiftUI, AppKit, or UIKit.
- Shared application tests may use in-memory SwiftData containers.
- Platform UI tests cover navigation and critical interaction wiring rather
  than duplicating domain assertions.
- A shared-layer change must build the macOS target and pass its relevant unit
  tests before it is used by a second platform.

## iPhone and iPad presentation

The first iPhone release includes the Flow dashboard, Tasks/Habits across
day/week/month ranges, Area management and ordering, day/week/month
History with the same chronology and editing semantics as macOS, the complete
period-report Statistics feature in a native iPhone presentation, basic
settings, and CloudKit synchronization.
Its persistent five-item navigation contains
`Flow`, `タスク`, `履歴`, `分野`, and `統計`. The shell uses the system `TabView`
so iOS owns selection, accessibility, and Liquid Glass. On iOS 26 the tab bar
minimizes while content scrolls down and returns on upward scrolling; older
systems keep their native tab-bar behavior. The Task quick-capture composer is
presented above that system navigation.
Drag-based calendar rescheduling remains macOS-only. Statistics calculations
are shared, but desktop views are never compiled into the iOS target. iOS uses
native cards, sheets, search, ShareLink, and navigation
for record details while macOS uses its window/sheet hierarchy; this
presentation difference must not change which records, gaps, series, progress,
or filters the user sees.

An active iPhone Flow publishes one system Live Activity. The Lock Screen and
Dynamic Island show Task, Area, remaining time, and progress. During a
break, the task identity is replaced by `☕️ 休憩` and the Area is hidden.
Date-backed timer ranges let the system advance timer text and progress while
the app is suspended. Compact Dynamic Island shows only the Task emoji and
remaining `MM:SS`; minimal presentation shows circular progress. Expanded
Dynamic Island adds `-5 minutes`, pause/resume, and `+5 minutes` controls.
Those App Intents call the same `ActiveFlowStore` operations as the in-app
player. The Lock Screen presentation is read-only, and tapping any activity
deep-links to the Flow tab.

On iPad and other regular-width iOS presentations, the same five destinations
move into a persistent system sidebar and the selected feature uses the wide
detail column. The composition mirrors macOS navigation without compiling
AppKit-owned views into iOS. Compact Split View and Stage Manager widths fall
back to the iPhone tab shell automatically; data, feature state, deep links,
and navigation selection remain shared across both presentations. iPad supports
portrait and landscape orientations, while iPhone remains portrait-only.

Home Screen and macOS desktop widgets are read-only projections delivered through App Group
`group.com.shigorefu.thruflow`:

- `Flowタイマー` supports Small and Medium and projects the current
  `FlowLiveActivityContent`. Date-backed timer and progress views advance
  without a second timer engine or per-second application wakeups.
- `今日のタスク` supports Small, Medium, and Large. The host application builds
  its immutable snapshot with the canonical Today filter and dashboard sorter.
- `Flow Dots` renders one GitHub-style contribution grid from the canonical
  180-day snapshot: Small uses `5 × 6` for 30 days, Medium `12 × 5` for 60
  days, and Large `9 × 10` for 90 days. Every family fills its content area
  without calendar-alignment placeholders.

`ProductWidgetSnapshotSyncView` observes SwiftData in each iOS/macOS application
process, builds Task and Dots snapshots through shared domain logic, stores
them in the App Group, and reloads only the affected widget kinds. The Widget
Extension decodes snapshots; it never opens SwiftData, CloudKit, or a second
business-rule engine. Widget taps deep-link to Flow, Tasks, or Statistics. The
App Group capability must be provisioned for the iOS app, macOS app, and the
shared Widget Extension. ActivityKit rendering remains conditionally compiled
for iOS; macOS embeds only the three regular WidgetKit configurations.

Dynamic Island regions must remain self-sizing. Do not use unbounded layout such
as `.frame(maxWidth: .infinity)` or geometry-derived offsets inside an expanded
region. The iOS 26.5 renderer can pass an unbounded proposal there; propagating
it into the archived SwiftUI tree caused `WidgetRenderer_Activities` to trap on
an invalid `NaN` view origin. Add presentation changes one surface at a time and
verify compact, minimal, expanded, and Lock Screen rendering independently.
The running clock must also remain a system-supported archived view:
`Text(timerInterval:countsDown:showsHours:)` and date-backed `ProgressView` are
allowed. Do not place a custom
`FormatStyle`/`DiscreteFormatStyle` in a Live Activity view tree. It can compile
and pass unit tests while WidgetRenderer fails to restore the tree and redacts
all text and symbols as gray placeholders at runtime. Running time uses a
countdown interval before zero and a count-up interval after zero so every
surface stays numeric `MM:SS` instead of changing to localized unit text. While
the application process is active, `ActiveFlowStore` publishes one additional
content update when the sign changes; that update switches intervals and adds
the explicit overtime `+` without sending per-second ActivityKit updates.
If iOS suspends the application before the boundary, the system countdown can
continue to render `00:00`, but SwiftUI cannot switch to the overtime branch
until new ActivityKit content arrives. A guaranteed `00:00 -> +00:01`
transition while the app is suspended requires an ActivityKit push update
through APNs; `staleDate`, widget timelines, background tasks, and local
notifications are not reliable substitutes. Version 1.x explicitly accepts
this presentation limitation and does not require an APNs provider. Remote
ActivityKit transport and external Connectors are deferred to 2.0; the future
transport must remain optional and must not replace SwiftData/CloudKit as the
source of truth.
Do not apply `fixedSize()` to the dynamic interval text: ActivityKit supplies a
bounded region for each presentation, and forcing the archived text's intrinsic
width can collapse it instead of rendering the clock.

## Migration Strategy

1. Move files without changing declarations or behavior.
2. Build the macOS target after each source-boundary change.
3. Extract direct AppKit calls behind macOS adapters.
4. Run the complete macOS test suite before merging.
5. Build and smoke-test both application targets after shared changes.

## Navigation And Rendering Lifecycle

The macOS split-view shell mounts only the selected feature. This keeps hidden
calendar grids, charts, toolbars, sheets, and Metal surfaces out of the render
tree. Root navigation views must not own an all-history `@Query` for Flow
sessions, segments, breaks, or Statistics input. Materializing those persistent
model graphs is main-actor work and can block the first frame even when the
visible calculation itself is deferred.

Flow and Statistics use a two-stage feature mount. Navigation selection and
the destination title commit first; the heavy feature tree is constructed on a
later run-loop turn. This prevents eager SwiftData query initialization and
cached chart construction from delaying the selection response. On iOS the
same boundary unmounts the heavy contents of retained, hidden `TabView` roots
while preserving their projections in root-owned cache state.

The Flow dashboard owns bounded rolling queries for the recent 16-day session,
break, and scheduled-task window needed by its daily presentation and weekly
habit planning. Habit materialization receives that bounded task set and does
not repeat the all-history duplicate reconciliation during navigation. It keeps
the derived dashboard projection in root-owned cache state, so returning to
Flow paints the previous projection immediately and refreshes it after the
navigation transaction.

Statistics uses `StatisticsProjectionActor`, a dedicated SwiftData
`@ModelActor`. It fetches only the selected range, converts persistent models to
Sendable value records inside the actor, and returns a ready heatmap projection
to the UI. No `PersistentModel` crosses that actor boundary. Statistics paints
its cached or empty shell first and starts the actor request after a short
navigation grace period. This keeps navigation responsive without changing
persisted data semantics or duplicating calculation rules.

The macOS and iOS card workspaces request the selected Week/Month/Year or exact custom
date range together with its immediately preceding equal-length comparison
interval. The actor maps Flow segments
and completed Todos to detailed value records; `StatisticsPeriodBuilder` owns
search, filtering, summaries, trends, distributions, Dots, and export rows.
`StatisticsCSVExporter` serializes those rows outside SwiftUI. Each platform UI
only owns toolbar state, navigation, a bounded four-snapshot presentation
cache, loading placeholders, independent Trend/Dots display modes, responsive
card layout, non-interactive Year Dots, date bounds through today, chart
presentation, and the system export/share surface. Switching
Flow/Task presentation reuses the same snapshot. Month trend input is reduced
to seven-day buckets in the pure builder and is rendered as two distinct chart
series. Export options create an independent period/filter projection only while
the Share popover is open; its period is always an exact inclusive start/end
range. Pie selection remains local presentation state. CSV serialization and temporary-file creation run
away from the main actor. iOS renders the same report as one touch-native
vertical scroll, uses sheets for period/export/day details, and draws Year Dots
in one compact Canvas. The widget heatmap projection remains a separate consumer
of its bounded 180-day source and family-specific output ranges.

The launch-wide Flow progress repair follows the same rule. The composition
root waits until the first presentation has settled, then
`FlowProgressReconciliationActor` performs the full-store reconciliation in its
own SwiftData model context and saves only when values changed. It is not part
of feature view creation or a navigation transaction.

Query results used as change feeds are sorted by `updatedAt` descending. Their
refresh identifiers read the first timestamp instead of scanning the complete
history on every SwiftUI body evaluation. User-visible ordering is applied by
the relevant shared sorter or feature projection, independently of query
ordering.

Tasks calendar rendering follows the same projection rule without introducing
a second source of truth. `TaskCalendarSnapshot` creates one immutable,
render-scoped index from the current SwiftData `@Query` result: active Tasks by
day and UUID, plus the overdue/undated backlog. Day, week, month, and the macOS
mini-calendar reuse that index instead of independently scanning every Task for
every visible cell. The snapshot is discarded with the render and never owns
persistence or cross-navigation state.

Habit occurrence materialization is not part of a date-selection transaction.
Tasks surfaces perform one full reconciliation after their initial frame, then
debounce lightweight materialization while the selected range is changing.
Rapid navigation cancels superseded work, and the lightweight path saves only
when an occurrence actually needs to be created or moved.

The Flow dashboard creates its one-second `TimelineView` only while selected,
and its Metal stream renders only while both selected and in the key window.
The iOS shell retains tab roots through the system `TabView`; it passes the same
visibility signal to Flow and Statistics so hidden tabs suspend periodic
refresh, projection building, habit materialization, and Metal rendering. Scene
inactivity continues to stop rendering on every platform.

While Statistics remains visible, it refreshes its bounded actor projection on
a thirty-second cadence. This preserves live updates from local edits and
CloudKit imports without putting persistent-model queries or heatmap work back
on the navigation transaction.

## Non-Goals

The shared cross-platform layer does not replace platform-native presentation
or introduce watch-only business rules. The watchOS companion is a thin
presentation client over the same shared models, calculations, active-Flow
store, and CloudKit container.

## watchOS Presentation

`Platforms/watchOS` owns the Watch app entry point and its native
`NavigationStack` presentation. The root is a system
`VerticalPageTabViewStyle` pager with four full-screen pages:

- `タイマー` is the initial complete Flow player;
- `Flow` is a fullscreen stream without a timeline;
- `タスク` presents today's Tasks and Habits;
- `統計` presents today's completion and focus summary.

The pages are ordered vertically and use the system page indicator and Digital
Crown behavior. The timer page has no nested vertical scroll, so the page swipe
is not intercepted by its controls. Its compact layout keeps context and mode
selection above a two-column player: the timer ring on the left and transport
controls on the right. Off-screen Flow rendering is disabled.

The Watch target reuses `ActiveFlowStore`, SwiftData models, domain builders,
Task progress controls, and `FlowVisualState`. macOS and iOS render the stream
with the shared Metal shader. watchOS uses a `Canvas` renderer because SwiftUI
`ShaderLibrary` and `colorEffect` are unavailable there; both renderers consume
the same palette, daily seed, growth, speed, and mode parameters. The Watch
Tasks page creates new records through a platform form composed of system
pickers and steppers; it inserts the same shared `Todo` model without adding a
second task-creation service or watch-only business rules.
