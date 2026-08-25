# Codex Repository Guide

This file explains how an agent should work in the ThruFlow repository. It is
an operating guide, not a duplicate product specification. Read it first, then
open the documents relevant to the task.

## Working behavior

- Inspect the request, `git status`, affected code, tests, and documentation
  before changing anything.
- Do not invent product rules. If code and documentation cannot establish the
  answer reliably, stop and ask the user.
- Follow Apple Human Interface Guidelines and the system Liquid Glass style.
  When a product request conflicts with platform conventions, explain the
  conflict and propose a platform-appropriate option.
- Treat the user's latest message as the current direction.
- Do not overwrite or revert user changes. Treat unfamiliar changes as
  user-owned and work around them.
- Do not hide unrelated refactors, features, or visual polish inside a task.
- Make small, verifiable changes and keep the project buildable after each
  substantial step.
- User-facing text defaults to Japanese. Code identifiers, enum raw values,
  and internal technical documentation remain in English.
- Xcode may update `Localizable.xcstrings` during builds or string extraction.
  Review those changes against the Swift source, remove empty or unused stale
  keys, use translator-readable keys, and preserve meaningful `ja`, `en`, and
  `ru` translations.
- Communicate briefly and concretely. During long work, report what is being
  checked, what was found, and what is changing.
- Apple components required for a task may be downloaded when unavailable.
- Unless the user limits scope to one platform, apply shared behavior to every
  supported platform where appropriate.

## Before starting a task

1. Run `git status --short --branch` and preserve existing work.
2. Locate the implementation with `rg`; do not begin with a broad rewrite.
3. Read `docs/PRODUCT.md`, `docs/DECISIONS.md`, and the relevant documents from
   the map below.
4. When persistence or platform integration is involved, inspect the existing
   tests, SwiftData models, target membership, and platform dependencies.
5. Use a separate `codex/` branch for large or risky changes unless the user
   specifies another workflow.

## Sources of truth

Resolve conflicts in this order:

1. the user's latest explicit requirement;
2. current accepted decisions in `docs/DECISIONS.md`;
3. the focused document that owns the affected product or technical area;
4. existing code and tests as a description of the current implementation.

Decision-log entries marked superseded are historical context, not current
requirements. When behavior changes, update the owning document and decision
record with the code; never leave old and new behavior both described as
current.

## Documentation map

- `docs/PRODUCT.md`: product overview and primary screens.
- `docs/UX_FLOWS.md`: user journeys and UI behavior.
- `docs/VOCABULARY.md`: Japanese product terms and meanings.
- `docs/DOMAIN_MODEL.md`: domain entities and calculations.
- `docs/DATA_MODEL.md`: SwiftData schema and data ownership.
- `docs/ARCHITECTURE.md`: layers, dependencies, and platform boundaries.
- `docs/LOCALISATION.md`: String Catalog rules and language workflow.
- `docs/CLOUDKIT.md`: container, signing, local mode, and schema deployment.
- `docs/TECHNICAL_PLAN.md`: services, technical rules, and expected tests.
- `docs/DECISIONS.md`: accepted product and architecture decisions.
- `docs/MVP.md`: version 1.0 scope.
- `docs/RELEASE.md`: release gates and archive process.
- `docs/ROADMAP.md`: planned work after 1.0.

## Implementation rules

- Follow the boundaries in `docs/ARCHITECTURE.md`.
- Keep business logic out of SwiftUI views. Calculations and state transitions
  must be independently testable.
- Do not change SwiftData fields, enum raw values, or history semantics without
  an explicit migration plan.
- Use stable UUIDs. Prefer archive or soft-delete fields when physical deletion
  would invalidate historical projections.
- Local SwiftData must work independently of CloudKit.
- Prefer Swift, SwiftUI, SwiftData, Swift Testing, and Apple system frameworks.
  Add third-party dependencies only after explicit approval.
- Prefer system navigation, toolbars, sheets, popovers, menus, pickers,
  controls, and animations. Build a custom component only when Apple APIs
  cannot satisfy an explicit requirement, and explain that boundary first.
- `1 Block = 25` focused minutes. Breaks are excluded. `12` minutes are shown
  as `0.5 Block`.
- Share domain and application state across platforms, not entire screens.
  macOS, iOS/iPadOS, and watchOS own their navigation and presentation layers.
  When a system API differs, preserve shared visual state and implement a
  platform-specific renderer.

## Verification

- Match verification to risk: focused UI changes require a build and visual
  check; domain changes require targeted unit tests; persistence or shared
  model changes require the full suite.
- The macOS scheme is `ThruFlow`. Unit tests use Swift Testing; UI tests use
  XCTest.
- Run local macOS unit and UI tests sequentially with
  `-parallel-testing-enabled NO` and `-maximum-parallel-testing-workers 1`.
- Keep only one temporary app copy running during visual QA, then terminate it
  and confirm no `xcodebuild`, `xctest`, test-runner, or temporary QA process
  remains.
- If tests consume unusual memory or CPU, stop the runners and QA app, report
  it, and continue with a narrower sequential check. Diagnose memory using RSS,
  not reserved virtual address space (VSZ).
- Run `git diff --check` and inspect the final diff.
- Never claim that a build or test passed unless it actually ran. If the
  environment blocks verification, state the exact reason.
- Do not make a failing test pass by weakening its assertion without an
  approved behavior change.

## Completing a task

1. Verify the latest user requirement, not an older interpretation.
2. Update documentation when product, architecture, data, or UX changed.
3. Summarize the changes and checks concisely.
4. Merge only when the user requests it or it is part of the agreed workflow.
   Keep large refactors and large features on separate branches.
