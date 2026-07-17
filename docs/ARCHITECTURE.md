# Architecture

## Goal

ThruFlow keeps one product model and one persistence model while allowing each
Apple platform to provide its own application shell and feature presentation.
The current shipping platform is macOS. iOS will be added as a separate UI
layer without copying domain rules or changing stored data.

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
```

An iOS implementation should be introduced under `Platforms/iOS` and reuse
`Shared`. It must not import files from `Platforms/macOS`.

The existing `ThruFlow` app and test targets are intentionally macOS-only.
The iOS application will be a separate target with its own app entry point and
source membership. This prevents Xcode from compiling desktop views and the
Metal desktop presentation into the iPhone application by accident.

## Dependency Rules

Dependencies point inward:

```text
Platforms/macOS  ──>  Shared/Application  ──>  Shared/Domain
       │                       │
       └──────────────────────> Shared/UI
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

A future iOS target must provide its own `App`, navigation shell, scene
lifecycle integration, and platform adapters under `Platforms/iOS/App`.

## Feature Boundaries

- Views transform user interaction into calls to application/domain operations.
- Product calculations, validation, scheduling, reconciliation, statistics,
  and timer transitions belong in `Shared/Domain/Logic`.
- Persistence orchestration shared by platforms belongs in
  `Shared/Application`; direct platform presentation does not.
- Reusable UI belongs in `Shared/UI` only when behavior and layout are genuinely
  the same on macOS and iOS. Sharing a large desktop screen to avoid writing an
  iPhone presentation is not a valid abstraction.
- Metal rendering and desktop-specific dashboard layout remain macOS-owned
  until another platform has an explicit implementation and performance budget.

## Persistence

The existing SwiftData models and schema remain the single source of truth.
This refactor does not rename entities, fields, enum raw values, or storage.
Local SwiftData remains independent of CloudKit.

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

## Adding iOS

1. Add a separate iOS app target and `Platforms/iOS` source tree.
2. Include `Shared` sources and exclude `Platforms/macOS` sources explicitly.
3. Create an iOS composition root using the same model container schema and
   shared application state.
4. Implement a narrow vertical slice (`タスク`, then Flow) with native iPhone
   navigation instead of porting desktop layouts.
5. Keep synchronization optional: both platform targets must remain functional
   with local SwiftData only.
6. Run macOS regression tests after every shared-layer extraction.

## Migration Strategy

1. Move files without changing declarations or behavior.
2. Build the macOS target after each source-boundary change.
3. Extract direct AppKit calls behind macOS adapters.
4. Run the complete macOS test suite before merging.
5. Add a separate iOS target and app shell only after the shared boundary builds
   cleanly and the macOS behavior has been verified unchanged.

## Non-Goals

This refactor does not add an iOS screen, synchronization, new product
features, new business rules, or visual changes.
