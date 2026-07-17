# AGENTS.md

This repository uses `CODEX.md` as the agent operating manual. Agents must read
it first, then follow its links to the product, architecture, data, UX, and
implementation sources relevant to the task.

## Working Rules

- Study the current Xcode project, Swift files, tests, SwiftData setup, CloudKit entitlements, git status, and documentation before changing code.
- Do not start with broad implementation. Document the product model and architecture first.
- Use Japanese as the default user-facing language.
- Keep code identifiers, enum raw values, and internal architecture docs in English unless the artifact is user-facing.
- Implement the app in small, testable vertical slices.
- Prefer Swift, SwiftUI, SwiftData, Swift Testing, and Apple system frameworks.
- Do not add third-party dependencies unless a future task explicitly justifies one.
- Keep local SwiftData operation independent of CloudKit.
- Do not implement AI, AWS, accounts, subscriptions, widgets, Live Activities, Apple Watch, or a full timeline editor in MVP 0.1.
- Canonical productivity unit: `1 Block = 25 focused minutes`. Breaks are excluded. 12 focused minutes are presented as `0.5 Block`.

## Architecture Expectations

- Keep domain models, data access, calculation logic, services, views, and reusable UI components separated.
- Do not put business logic directly in SwiftUI views.
- Do not create one giant `ContentView` or one giant app view model.
- Make timer logic, progress calculation, daily completion, weekly goals, adaptive Flow transitions, and timer restoration testable outside UI.
- Use stable UUID identifiers and stable enum raw values.
- Use soft archive/delete fields where history should remain intact.

## Current Project Notes

- Xcode uses file-system synchronized groups, so new files under target folders should be picked up by the project.
- The original `Item` template has been replaced by the Direction vertical slice.
- The app target has CloudKit-related entitlements, but the iCloud container identifier list is empty.
- Unit tests use Swift Testing; UI tests use XCTest.
