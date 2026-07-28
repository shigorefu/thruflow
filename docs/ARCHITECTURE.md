# Architecture

## Goal

ThruFlow keeps one product model and one persistence model while allowing each
Apple platform to provide its own application shell and feature presentation.
macOS remains the complete editing and analysis surface. The iPhone app is a
separate, Flow-first MVP presentation that reuses the same domain, application
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
      Features/     Native iPhone Flow, Tasks, History, Directions, Statistics, and Settings
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
- `Platforms/iOS` owns the Flow-first iPhone navigation shell and compact Flow,
  Tasks, History, Directions, Statistics, and Settings presentations.
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
  launch, foreground entry, and a low-frequency active-scene cadence so
  CloudKit imports are adopted without view-specific logic.
- `AppSettings` owns typed local preferences and derives the effective
  `Calendar`, `Locale`, and `AppDayBoundary`. Platform composition roots inject
  those values into their scene environments; settings never enter SwiftData.
  `AppDayBoundary` is the shared, DST-aware authority for deciding which
  logical day contains an instant. Domain builders accept it explicitly so
  Tasks, Habits, Flow, History, Statistics, watchOS, and widgets cannot develop
  platform-specific midnight rules.

- `Platforms/iOS/App/ThruFlowiOSApp.swift` declares the iPhone scene and injects
  the same `ActiveFlowStore`, `AppSettings`, calendar, locale, and model schema.
  It also registers the Live Activity control dependency used by system actions.
- `Platforms/watchOS/App/ThruFlowWatchApp.swift` declares the Watch scene and
  injects the same model schema, settings-derived calendar/locale, and
  `ActiveFlowStore`. It reconciles persisted active Flow state on appearance
  and foreground entry instead of creating a Watch-only timer.

## Feature Boundaries

- Views transform user interaction into calls to application/domain operations.
- Product calculations, validation, scheduling, reconciliation, statistics,
  and timer transitions belong in `Shared/Domain/Logic`.
- Database-wide Task and History search matching, date grouping, and aggregate
  scope belong in `Shared/Domain/Logic`; platform views only select a mode and
  render the resulting sections or snapshots.
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
  motion. At zero progress the shader preserves the archived six-ribbon
  neutral S-stream. `identityReveal` blends it into the seven-ribbon daily
  topology over the first canonical Block; there is no renderer swap or phase
  reset. The shader accumulates colored ribbon cores and wider halos
  independently, preserving visible diffusion without washing the ribbon
  centers toward white.
  `FlowRenderCadence` owns the explicit 30 FPS idle / 60 FPS active contract.
  Platform wrappers only decide when rendering pauses: macOS requires the key
  window, while iOS requires an active scene. Pausing freezes the shared
  `FlowAnimationClock` phase instead of rebuilding the picture.
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

## iPhone MVP Boundary

The first iPhone release includes the Flow dashboard, Tasks/Habits across
day/week/month ranges, Direction management and ordering, basic day/week/month
History browsing, a compact contribution Statistics screen, basic settings,
and CloudKit synchronization. Its persistent five-item navigation contains
`Flow`, `タスク`, `履歴`, `方向`, and `統計`. The shell uses the system `TabView`
so iOS owns selection, accessibility, and Liquid Glass while the tab bar remains
full-size during scrolling; Tasks temporarily hides the tab bar and animates in
the quick-capture composer.
Advanced Statistics and full calendar/history editing remain macOS-only until
the next iPhone stage. Shared calculations are reused, but desktop views are
never compiled into the iOS target.

An active iPhone Flow publishes one system Live Activity. The Lock Screen and
Dynamic Island show Task, Direction, mode, phase, remaining time, and progress.
Date-backed timer ranges let the system advance timer text and progress while
the app is suspended. Compact Dynamic Island shows only the Task emoji and
remaining `MM:SS`; minimal presentation shows circular progress. Expanded
Dynamic Island adds `-5 minutes`, pause/resume, and `+5 minutes` controls.
Those App Intents call the same `ActiveFlowStore` operations as the in-app
player. The Lock Screen presentation is read-only, and tapping any activity
deep-links to the Flow tab.

Home Screen widgets are read-only projections delivered through App Group
`group.com.shigorefu.thruflow`:

- `Flowタイマー` supports Small and Medium and projects the current
  `FlowLiveActivityContent`. Date-backed timer and progress views advance
  without a second timer engine or per-second application wakeups.
- `今日のタスク` supports Small, Medium, and Large. The iOS application builds
  its immutable snapshot with the canonical Today filter and dashboard sorter.
- `Flow Dots` supports Medium for the current month and Large for the canonical
  180-day Flow heatmap.

`IOSProductWidgetSnapshotSyncView` observes SwiftData in the application
process, builds Task and Dots snapshots through shared domain logic, stores
them in the App Group, and reloads only the affected widget kinds. The Widget
Extension decodes snapshots; it never opens SwiftData, CloudKit, or a second
business-rule engine. Widget taps deep-link to Flow, Tasks, or Statistics. The
App Group capability must be provisioned for both the iOS app and the Widget
Extension.

Dynamic Island regions must remain self-sizing. Do not use unbounded layout such
as `.frame(maxWidth: .infinity)` or geometry-derived offsets inside an expanded
region. The iOS 26.5 renderer can pass an unbounded proposal there; propagating
it into the archived SwiftUI tree caused `WidgetRenderer_Activities` to trap on
an invalid `NaN` view origin. Add presentation changes one surface at a time and
verify compact, minimal, expanded, and Lock Screen rendering independently.

## Migration Strategy

1. Move files without changing declarations or behavior.
2. Build the macOS target after each source-boundary change.
3. Extract direct AppKit calls behind macOS adapters.
4. Run the complete macOS test suite before merging.
5. Build and smoke-test both application targets after shared changes.

## Non-Goals

This cross-platform stage does not add new business rules or alter macOS
behavior. It does not include advanced iPhone Statistics or full
History/calendar editing. The watchOS companion is a thin presentation client
over the same shared models, calculations, active-Flow store, and CloudKit
container.

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
