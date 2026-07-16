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
- `Platforms/macOS` owns navigation, windows, menu-bar scenes, keyboard/focus
  integration, drag-and-drop presentation, and the current desktop layouts.
- Platform-specific behavior is reached through small adapters in the owning
  platform folder. Shared code does not use conditional AppKit/UIKit imports.

## Persistence

The existing SwiftData models and schema remain the single source of truth.
This refactor does not rename entities, fields, enum raw values, or storage.
Local SwiftData remains independent of CloudKit.

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
