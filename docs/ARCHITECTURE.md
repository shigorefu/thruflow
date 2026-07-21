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
```

`ThruFlow` and `ThruFlow iOS` are separate application targets. Explicit source
exclusions keep AppKit, menu-bar, and Metal dashboard code out of iOS and keep
UIKit/iPhone presentation out of macOS. Shared tests remain in the macOS test
target because they verify the platform-neutral core.

## Dependency Rules

Dependencies point inward:

```text
Platforms/macOS ─┐
                 ├──> Shared/Application ──> Shared/Domain
Platforms/iOS  ──┘              │
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
- `Shared/UI` contains only components whose behavior and layout are intended
  to remain common across platforms.
- `Localisation/Localizable.xcstrings` owns user-facing copy for every platform;
  Japanese is the source and fallback language.
- `Platforms/macOS` owns navigation, windows, menu-bar scenes, keyboard/focus
  integration, drag-and-drop presentation, and the current desktop layouts.
- `Platforms/iOS` owns the Flow-first iPhone navigation shell and compact Flow,
  Tasks, History, Directions, Statistics, and Settings presentations.
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
  control it but do not create a second timer state machine.
- `AppSettings` owns typed local preferences and derives the effective
  `Calendar` and `Locale`. Platform composition roots inject those values into
  their scene environments; settings never enter SwiftData.

- `Platforms/iOS/App/ThruFlowiOSApp.swift` declares the iPhone scene and injects
  the same `ActiveFlowStore`, `AppSettings`, calendar, locale, and model schema.

## Feature Boundaries

- Views transform user interaction into calls to application/domain operations.
- Product calculations, validation, scheduling, reconciliation, statistics,
  and timer transitions belong in `Shared/Domain/Logic`.
- Persistence orchestration shared by platforms belongs in
  `Shared/Application`; direct platform presentation does not.
- Reusable UI belongs in `Shared/UI` only when behavior and layout are genuinely
  the same on macOS and iOS. Sharing a large desktop screen to avoid writing an
  iPhone presentation is not a valid abstraction.
- `FlowStreamSurface` and `FlowStreamShader.metal` form one shared Metal render
  path for macOS and iOS; platform wrappers only decide when rendering pauses.
- Desktop-specific dashboard layout remains macOS-owned.
  until another platform has an explicit implementation and performance budget.

## Persistence

The existing SwiftData models and schema remain the single source of truth.
Normal signed app runs use the private CloudKit database in
`iCloud.com.shigorefu.thruflow`. Tests use an in-memory local configuration, and
`THRUFLOW_DISABLE_CLOUDKIT=1` or `--local-store` provides an explicit local-only
escape hatch. CloudKit availability must never be a precondition for domain
logic or tests.

All derived progress must be reproducible from persisted history. Mutations to
Flow history go through the shared reconciliation logic rather than applying
view-local relative deltas.

## Test Boundaries

- Domain rules are tested without SwiftUI, AppKit, or UIKit.
- Shared application tests may use in-memory SwiftData containers.
- Platform UI tests cover navigation and critical interaction wiring rather
  than duplicating domain assertions.
- A shared-layer change must build the macOS target and pass its relevant unit
  tests before it is used by a second platform.

## iPhone MVP Boundary

The first iPhone release includes the Flow dashboard, today's Tasks/Habits,
Direction management, basic day/week/month History browsing, a compact
contribution Statistics screen, basic settings, and CloudKit synchronization.
Advanced Statistics and full calendar/history editing remain macOS-only until
the next iPhone stage. Shared calculations are reused, but desktop views are
never compiled into the iOS target.

## Migration Strategy

1. Move files without changing declarations or behavior.
2. Build the macOS target after each source-boundary change.
3. Extract direct AppKit calls behind macOS adapters.
4. Run the complete macOS test suite before merging.
5. Build and smoke-test both application targets after shared changes.

## Non-Goals

This cross-platform stage does not add new business rules or alter macOS
behavior. It does not include advanced iPhone Statistics, full History/calendar
editing, widgets, Live Activities, or Apple Watch.
