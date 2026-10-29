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

- Maintain technical documentation in English. The public root README has English
  and Japanese editions; translation catalogs and stable source keys retain their
  original language. Use `docs/README.md` to find each specification owner.

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

Historical 1.0 scope remains available in Git history.
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

## Cross-platform agent orchestration

For changes to app code, UI interactions, shared APIs, persistence, or localization,
the lead agent must check the corresponding behavior on both macOS and iOS/iPadOS.
This is standing authorization to delegate the bounded reviews below; an explicit
user restriction on delegation or scope takes precedence. Documentation-only
changes do not require platform agents.

### Required agreement for logic changes

For changes to business rules, validation, state transitions, persistence, or
UI-to-command behavior, use an **orchestrator**, a **macOS agent**, and an
**iOS/iPadOS agent**. This three-role agreement is mandatory even when the
implementation changes only Shared or one client. Include a Watch/widget review
when those consumers are affected.

- **Before implementation:** the orchestrator proposes the common behavior,
  shared owner/API, affected callers, native exceptions, and acceptance scenarios.
  Both client agents inspect their implementation, exchange findings with each
  other and the orchestrator, and explicitly agree on that contract before edits.
- **During implementation:** assign disjoint file ownership and one owner for
  Shared changes. A changed contract or newly discovered cross-client effect
  must be communicated and agreed again; no agent silently changes shared rules.
- **After implementation:** both client agents review the final diff, each other's
  findings, and the evidence for the agreed scenarios. They explicitly report
  agreed / changes required / unverified, with reasons and file references.
  The orchestrator resolves disagreements and requests re-review after fixes.
- **Completion:** the orchestrator records the agreed behavior, each client's
  verdict, intentional differences, and checks actually run. Unresolved objections
  block a claim that the logic change is complete; missing runtime evidence must
  remain visible. Silence, a passing build, or a single agent's approval does not
  constitute agreement. Routine technical disagreements are resolved by agents
  using product rules and evidence; ask the user only for a genuinely missing
  product decision or a blocker requiring their input.

The lighter counterpart-review process below remains sufficient for changes
that do not alter logic. If delegation is unavailable, the fallback below is a
single-agent review only and must not be described as multi-agent agreement.

### Localization agent

Whenever user-facing copy or localization resources change, the orchestrator
must delegate a separate **localization agent** in addition to the required
client reviewers. This is standing authorization for that bounded review.

- Review every affected string in all five supported locales: Japanese, English,
  Russian, Simplified Chinese, and Traditional Chinese. Judge naturalness
  (自然な表現), grammar, tone, brevity and terminology in the actual UI context,
  not just literal translation or whether a key exists.
- The localization agent may fix awkward, incorrect or missing translations
  directly within its assigned files. Assign one writer for catalogs/glossary;
  client agents coordinate copy changes through that owner to avoid conflicts.
- Follow [Localization](docs/LOCALISATION.md) and `Localisation/TERMS.csv`.
  Preserve meaning, stable source keys, placeholders, plural rules, shortcuts
  and accessibility intent. For shared keys with different UI meanings, agree
  on context-specific wording/keys with the orchestrator before changing them.
- Check Mac, iPhone/iPad, Watch and widget contexts where applicable. Report
  languages and strings reviewed, corrections, terminology questions and any
  unverified layouts. Do not claim native-speaker or visual verification from
  source review alone.
- Before completion, report **agreed / changes required / unverified** and
  resolve wording objections with the orchestrator. Missing agent access must
  be disclosed; it is not an independent localization review.
- Feature work reviews affected copy across all locales. A full existing-catalog
  audit is a separate scope and must not be claimed from a diff-only review.

### Review workflow

1. Run `python3 scripts/platform_review.py --base HEAD` for uncommitted work,
   or use the task's actual starting commit to include committed changes. The
   report maps changed paths to counterpart entry points and suggested tests.
   Follow actual callers too: the map is a starting point, not a dependency graph.
2. The lead owns the implementation and defines the user action, expected result,
   and intentional native differences. Prefer one shared operation over copied
   validation, draft transformations, or persistence commands. Keep native
   navigation, keyboard, window, and gesture behavior in platform code.
3. Assign an independent **counterpart reviewer** a read-only task with the final
   diff, affected feature, scenarios, and both client entry points. For a Mac-only
   edit they inspect iOS; for an iOS-only edit they inspect Mac; for a shared edit
   they inspect both callers. Review Watch/widgets when they consume the change.
   Larger changes may use separate client reviewers with disjoint ownership.
4. The reviewer reports counterpart coverage, shared command wiring, intentional
   differences, findings with file/line evidence, and checks run or unavailable.
   An unchanged counterpart can be correct; do not demand a cosmetic second diff.
   Re-review after changes that affect a finding or the reviewed behavior.
5. The lead integrates findings and owns build/test execution. Reviewers must not
   start competing builds or macOS test runners unless explicitly assigned an
   isolated check. Do not mark parity verified from a successful build alone.
6. If agent tools are unavailable, perform the same counterpart review directly
   and disclose that it was not independent. Report unresolved findings and
   unverified device/UI scenarios instead of claiming completion of those checks.

The feature map is `scripts/platform_review_map.json`; update it when moving or
adding feature boundaries. CI publishes its report and builds both clients;
AGENTS governs the AI review inside coding tasks. The report does not launch AI
agents, prove UI parity, or require a paid external AI service.

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
