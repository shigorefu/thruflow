# ThruFlow

ThruFlow / スルフロ is an Apple-first personal focus app for turning attention, tasks, required life areas, Flow sessions, and the day's timeline into visible progress.

The product is not a Pomodoro clone, a standalone habit tracker, or a generic todo list. Its central idea is that a user does not need to stay in uninterrupted flow all day. A successful day can be built from several focused returns to work, as long as the required Must goals for that day are completed.

Core principle:

> Work does not have to be perfect. Returning to it and converting time into progress is what matters.

## Platforms

Initial development is iPhone-first with an architecture that should remain compatible with iPad and macOS.

Default UI language is Japanese. Internal code identifiers and architecture documentation stay in English unless a user-facing artifact requires Japanese.

Current Xcode project targets:

- `ThruFlow`
- `ThruFlowTests`
- `ThruFlowUITests`

Current supported platforms in the project file are `iphoneos`, `iphonesimulator`, `macosx`, `xros`, and `xrsimulator`; MVP planning remains focused on iPhone, iPad, and macOS.

## Technology

- Swift
- SwiftUI
- SwiftData
- Swift Testing
- Apple system frameworks
- Offline-first local storage

Third-party dependencies are intentionally avoided for the initial MVP. CloudKit may be prepared architecturally, but the MVP must run locally without requiring CloudKit.

## Current State

This repository started from the Xcode SwiftUI + SwiftData template. The template `Item` model has now been replaced by the first Direction vertical slice:

- `Direction` is the current SwiftData model.
- `ContentView` opens the Direction list.
- Unit tests cover initial Direction validation and archive/update behavior.
- UI tests are still template launch placeholders.
- CloudKit entitlements are present, but no iCloud container identifier is configured.

Next implementation work should continue with Direction polish only if needed, then move to Todo after the Direction slice remains buildable and tested.

## Documentation

- [Product](docs/PRODUCT.md)
- [Domain Model](docs/DOMAIN_MODEL.md)
- [UX Flows](docs/UX_FLOWS.md)
- [Technical Plan](docs/TECHNICAL_PLAN.md)
- [MVP](docs/MVP.md)
- [Roadmap](docs/ROADMAP.md)
- [Decisions](docs/DECISIONS.md)
