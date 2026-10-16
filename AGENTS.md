# AGENTS.md

Repository-wide instructions for AI coding agents working on ThruFlow.
Keep operating rules here; product specifications and technical details live in
the linked `docs/` files. Add a nested `AGENTS.md` only when a directory needs
distinct rules, and read applicable nested instructions before editing there.

## Start here

1. Read the latest user request and run `git status --short --branch`. Preserve
   unrelated edits, including Xcode-generated String Catalog changes.
2. Locate the affected implementation with `rg`. Inspect its code, tests, and
   relevant documentation before editing; do not begin with a broad rewrite.
3. For behavior changes, read [Product](docs/PRODUCT.md) and the relevant
   accepted entries in [Decisions](docs/DECISIONS.md), then use the task map below.
   Documentation-only work needs the affected documents and their references.
4. For code changes, inspect Xcode target membership and platform dependencies.
   For persistence or sync work, also inspect SwiftData setup, models, CloudKit
   entitlements, and existing persistence tests.
5. Respect the user's selected branch. Otherwise, use a separate `codex/`
   branch for large or risky changes.

## Working agreements

- Make small, verifiable changes. Preserve unrelated work and keep the project
  buildable; do not include unsolicited refactors, features, or visual polish.
- Do not invent product rules. Resolve routine implementation details from the
  repository; ask when an unresolved product decision materially affects behavior.
- Communicate briefly in the user's language. Japanese is the default **app UI**
  language; identifiers, stable enum raw values, and technical docs use English.
- Apply shared behavior across macOS, iOS/iPadOS, and watchOS unless the user
  limits scope. Each platform retains its own presentation.
- Never commit credentials, signing material, private user data, database
  exports, or local Xcode state. Use isolated fixtures for tests.
- Do not reset user stores or CloudKit records to fix a bug or schema mismatch.
- Merge, publish, or release only when requested or part of the agreed workflow.
- Do not claim tests, builds, device behavior, or synchronization were verified
  unless the relevant check actually ran. Report skipped or blocked checks.

## Sources of truth and task map

For product decisions, follow the latest explicit user requirement, then current
accepted decisions, then the owning specification. Code and tests describe the
implementation and may contain the bug being fixed. Superseded decisions are
historical. Update the owning document and decision record when behavior changes.

| Task | Read |
| --- | --- |
| Product behavior and release scope | [Product](docs/PRODUCT.md), [Decisions](docs/DECISIONS.md), [Roadmap](docs/ROADMAP.md) |
| Layers, ownership, and target boundaries | [Architecture](docs/ARCHITECTURE.md) |
| Timer, Task, Habit, history, and progress rules | [Domain model](docs/DOMAIN_MODEL.md), [Technical plan](docs/TECHNICAL_PLAN.md) |
| SwiftData, migrations, or cross-device sync | [Data model](docs/DATA_MODEL.md), [CloudKit](docs/CLOUDKIT.md) |
| Screens, navigation, and interaction | [UX flows](docs/UX_FLOWS.md), [Vocabulary](docs/VOCABULARY.md) |
| App copy or String Catalog | [Localization](docs/LOCALISATION.md) |
| Provider integrations, credentials, or OAuth | [Connectors](docs/CONNECTORS.md) |
| Signing, archives, TestFlight, or App Store | [Release](docs/RELEASE.md), [CloudKit](docs/CLOUDKIT.md) |
| Contributions, dependencies, and licenses | [Contributing](CONTRIBUTING.md), [Licensing](LICENSING.md) |

[Original MVP](docs/MVP.md) describes version 1.0 scope, not the current roadmap.
Read the documents relevant to the task rather than loading all documentation.

## Implementation boundaries

- Prefer Swift, SwiftUI, SwiftData, Swift Testing, and Apple system frameworks.
  Third-party runtime dependencies require explicit approval.
- `ThruFlow/Shared/Domain` owns models and business rules;
  `Shared/Application` coordinates use cases and persistence;
  `Shared/Connectors` owns provider, credential, and OAuth adapters.
- Keep timer, progress, history, and persistence behavior outside SwiftUI views
  and independently testable. Follow the dependency rules in Architecture.
- `ThruFlow/Platforms/{macOS,iOS,watchOS}` owns platform presentation;
  `Shared/UI` contains small genuinely shared components.
- Check consumers in `ThruFlowLiveActivity` and Watch when changing shared APIs.
  Widgets use snapshots; do not give them another timer or SwiftData store.
- Follow Apple Human Interface Guidelines and system Liquid Glass conventions.
  Prefer native controls and navigation. Explain platform conflicts; use custom
  components only when system components cannot satisfy the requirement.
- Local SwiftData operation must remain independent of CloudKit.
- Preserve stable UUIDs, persisted field names, enum raw values, and history.
  Changes to these contracts require an explicit migration plan. Use archive or
  soft deletion when physical deletion would invalidate history.
- `1 Block = 25 focused minutes`; breaks are excluded and 12 focused minutes
  are presented as `0.5 Block`.
- Update all supported locales together: Japanese, English, Russian, Simplified
  Chinese (`zh-Hans`), and Traditional Chinese (`zh-Hant`). Review Xcode changes
  to `ThruFlow/Localisation/Localizable.xcstrings` against the source; remove
  task-related empty/stale keys, retain meaningful translations, and avoid
  unrelated catalog reformatting.

## Verification

Match checks to the change:

- Documentation only: check links, commands against the project/CI, and diff.
- UI: build and visually check affected platforms and size classes.
- Domain logic: add or update meaningful regression tests and run relevant tests.
- Persistence or shared models: run the full unit suite.
- Build affected Release targets. Signed device checks are needed for changes
  to CloudKit, widgets, Live Activities, StoreKit, notifications, or Watch
  integration; unsigned builds do not prove those integrations work.

Run commands from the repository root. These match the existing Xcode schemes
and [.github/workflows/ci.yml](.github/workflows/ci.yml).

### macOS unit tests

```sh
THRUFLOW_DISABLE_CLOUDKIT=1 xcodebuild test \
  -project ThruFlow.xcodeproj \
  -scheme ThruFlow \
  -destination 'platform=macOS' \
  -only-testing:ThruFlowTests \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -derivedDataPath DerivedData/Tests \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO
```

For a focused run, replace the test selector with
`-only-testing:ThruFlowTests/<SuiteName>`.
Run macOS unit and UI tests sequentially with the parallel-testing flags above.
Unit tests use Swift Testing; UI tests use XCTest.

### Release builds

```sh
xcodebuild build \
  -project ThruFlow.xcodeproj \
  -scheme ThruFlow \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath DerivedData/macOS-Release \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO

xcodebuild build \
  -project ThruFlow.xcodeproj \
  -scheme 'ThruFlow iOS' \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData/iOS-Release \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO
```

The iOS build includes the embedded Watch app. The standalone Watch scheme is
`ThruFlow Watch`. See Release for signed archives and device verification.
Install missing Apple toolchain components when required for the task.

### Test and QA hygiene

- Use isolated test data. The `ThruFlow Demo` and `ThruFlow iOS Demo` schemes
  provide disposable in-memory sample data; see Technical plan.
- Keep only one temporary QA app running. Stop runners and temporary apps
  started for the task, and verify none remain; preserve the user's processes.
- If tests consume unusual CPU or memory, stop the task's runners, report it,
  and narrow the check. Diagnose memory using RSS, not reserved VSZ.
- Fix warning/error causes rather than suppressing diagnostics. Do not weaken
  a failing assertion without an approved behavior change.

## CloudKit Production gate

Always inspect the **live Production schema** when preparing a release,
diagnosing cross-device sync, or changing persisted models. Follow
[CloudKit](docs/CLOUDKIT.md); inspect the actual container/environment, record
types, field names/types, and required indexes. Local tests, Development, and
a successful App Store Connect upload do not establish Production readiness.

For persisted schema changes, compare both live environments, materialize
missing additive fields in Development, review the deployment diff, deploy to
Production, and reload it to confirm before distributing affected builds.
Preserve existing stores and records. If live access is unavailable, mark this
gate unverified and explain the limitation.

Record the date, environment, inspected/deployed changes, and evidence in
`docs/CLOUDKIT.md`. Verify actual Mac/iPhone exchange or record the user's
confirmation; schema deployment alone does not prove synchronization recovered.

## Finish

- Confirm the result meets the latest request and update affected documentation.
- Inspect the final diff and run `git diff --check`.
- Keep unrelated edits out of commits.
- Report what changed, checks actually performed, and remaining limitations.
- Keep this file concise and current. Put detailed procedures in their owning
  docs; do not create a second competing agent manual.
