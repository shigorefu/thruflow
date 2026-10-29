# Development and QA

Architecture and current behavior are specified in [Architecture](ARCHITECTURE.md),
[Domain model](DOMAIN_MODEL.md) and [Data model](DATA_MODEL.md). This guide owns
local QA setup, not a second implementation roadmap.

## Verification

Follow [Contributing](../CONTRIBUTING.md) for unit-test commands,
[Release](RELEASE.md) for Release builds and device checks, and
[AGENTS.md](../AGENTS.md) for agent review requirements. Cover changed validation,
state transitions, save rollback and cross-client command wiring. Persistence
changes require the full unit suite and the live Production schema gate.

Connector tests use injected transport and credentials. Real OAuth, Keychain,
EventKit permission, CloudKit exchange, notifications, widgets and Watch require
separate signed-device checks. A successful unsigned build does not verify them.

## Demo database

Run `ThruFlow Demo` or `ThruFlow iOS Demo` for disposable in-memory sample data.
The Debug-only `--demo-data` argument disables CloudKit and never seeds normal
stores. Do not rely on fixed fixture counts; the fixture builders are the source
of truth. For localized App Store assets, use the dedicated screenshot schemes
and instructions in [Release](RELEASE.md#localized-app-store-screenshots).

Onboarding preview schemes use an isolated in-memory container. User-confirmed
example creation cannot reach the production store. Verify both guided empty
workspace and read-only existing-workspace experiences.

## Build diagnostics


`TodoProgressCalculator` initialization and numeric progress/status calculations
are nonisolated so synchronous reconciliation can use this stateless calculator.
The Watch target skips App Intents metadata extraction in Debug and Release
(`LM_SKIP_METADATA_EXTRACTION`) because it defines no App Intents. Extraction
remains enabled for the macOS/iOS app and widget/Live Activity targets. Enable
Watch extraction when introducing Watch App Intents.

The macOS suggestion panel keeps its AppKit anchor class outside the generic
SwiftUI representable. Content is already erased to AnyView; a generic nested
NSView subclass triggered a Swift 6.3 Release deinitializer optimization crash.
This structure retains normal Release optimization and the existing panel lifecycle.
