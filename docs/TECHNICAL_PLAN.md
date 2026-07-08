# Technical Plan

## Repository Baseline

Current repository state:

- Xcode project: `ThruFlow.xcodeproj`.
- App target: `ThruFlow`.
- Unit test target: `ThruFlowTests`.
- UI test target: `ThruFlowUITests`.
- Existing model: `Direction`.
- Existing UI: `ContentView` routes to the Direction list.
- SwiftData container schema currently includes `Direction`.
- Unit tests cover initial Direction validation and archive/update behavior.
- UI tests are template launch placeholders.
- `Info.plist` contains `UIBackgroundModes` with `remote-notification`.
- Entitlements include APNs development keys and CloudKit service entitlement, but `com.apple.developer.icloud-container-identifiers` is empty.
- Project uses file-system synchronized groups.
- Deployment targets: iOS 26.5, macOS 26.5, visionOS 26.5.
- Supported platforms in project settings: iPhone/iPad, macOS, visionOS.
- Xcode development region is `ja`; Japanese is the default user-facing language.

`xcodebuild -list` succeeds in reading the project and scheme, but the current sandbox cannot access CoreSimulator services or some DerivedData log paths. Build verification should prefer an explicit DerivedData path under the workspace or `/tmp`.

## Target Architecture

Use a simple modular folder structure:

- `Domain/Models`: SwiftData models and stable enums.
- `Domain/Logic`: pure calculation types for progress, goals, day completion, adaptive transitions, and timer restoration.
- `Data`: lightweight data-access helpers only when repeated query/mutation logic appears.
- `Features/Today`: Today screen and related views.
- `Features/Directions`: Direction list, form, editing, archive actions.
- `Features/Todos`: Todo list and form views.
- `Features/Flow`: Flow start, timer, finish/result screens.
- `Features/History`: Flow history and basic statistics.
- `Shared/UI`: small reusable SwiftUI components.

Do not introduce a large app-wide view model or Redux-like architecture.

## SwiftData Strategy

Start local-only:

- `ModelContainer` should initially use local storage.
- CloudKit must not be required for app launch.
- Persistent entities use UUID `id`, `createdAt`, `updatedAt`, and archive/delete timestamps where appropriate.
- Enums use String raw values.
- Relationships should be explicit and stable.

Template replacement status:

1. Direction model and tests are added.
2. Schema includes Direction.
3. `ContentView` routes to Direction UI.
4. `Item` has been removed.

Todo slice status:

1. Todo model and tests are added.
2. Schema includes Todo.
3. Today routes manual and scheduled Todo items.
4. Todo creation and editing start from Today.

Flow slice status:

1. Canonical Block calculation is implemented as pure domain logic.
2. Schema includes FlowSession.
3. FlowTimerEngine handles start, pause, resume, early finish, break transition, timestamp restoration, and Adaptive 12 -> 25 -> 50 transitions.
4. FlowMiniPlayerView is available from the app shell bottom safe area.
5. Flow configuration selects Direction, optional Todo, Intent, and mode.
6. Result capture is available after finishing.
7. Local notification scheduling is abstracted behind FlowNotificationService.
8. Live Activity is abstracted behind LiveActivityService; Widget Extension target creation is deferred to a separate target/capability/signing-safe slice.

## Calculation Logic

The following should be pure and testable without SwiftUI:

- progress calculation;
- daily goal completion;
- weekly goal completion;
- deterministic Today requirement inclusion;
- Adaptive Flow transitions;
- timer restoration from timestamps;
- DailyCompletion event emission rules.

## CloudKit Preparation

CloudKit is a future sync path, not an MVP runtime dependency.

Current entitlements show CloudKit service support but no container. Before enabling sync, the project needs:

- a real iCloud container identifier;
- model review for CloudKit-compatible constraints;
- conflict behavior decisions for active timers;
- testing across devices.

Active distributed Flow timer sync is explicitly out of MVP 0.1.

## Testing Strategy

Use Swift Testing for unit tests:

- Direction validation;
- progress calculation;
- daily goal rules;
- weekly goal rules;
- Adaptive Flow state transitions;
- timer restoration;
- single DailyCompletion event creation.

Use UI tests sparingly for launch and high-value flows:

- app launches;
- Direction can be created;
- Today shows required items.

The app uses an in-memory SwiftData container when launched by XCTest or with `--uitesting`. This keeps tests isolated from the user's local persistent store while the schema evolves.

## Verification

Preferred commands:

```sh
xcodebuild -list -project ThruFlow.xcodeproj
xcodebuild test -project ThruFlow.xcodeproj -scheme ThruFlow -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData
```

Simulator availability may require running outside the sandbox or from Xcode when CoreSimulator is unavailable to the command-line environment.
