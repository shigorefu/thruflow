# AGENTS.md

This repository uses [`CODEX.md`](CODEX.md) as its complete agent operating manual. Read it first, then follow its links to the product, architecture, data, UX, and implementation sources relevant to the task.

## Working rules

- Inspect the current Xcode project, affected Swift files, tests, SwiftData setup, CloudKit entitlements, documentation, and `git status` before changing code.
- Preserve unrelated work and make small, testable vertical changes.
- Use Japanese as the default and highest-priority user-facing language. Write natural Japanese for the product context instead of translating English structure literally.
- Every user-facing change must include complete, idiomatic Japanese, English, and Russian copy in the same change. Natural Japanese has priority, but the other maintained locales must not be left as placeholders or mechanical translations.
- Keep code identifiers and stable enum raw values in English.
- Prefer Swift, SwiftUI, SwiftData, Swift Testing, and Apple system frameworks. Do not add third-party runtime dependencies without explicit approval.
- Keep local SwiftData operation independent of CloudKit.
- Keep business logic outside SwiftUI views and test timer, progress, history, and persistence behavior independently.
- Run macOS tests sequentially with `-parallel-testing-enabled NO` and `-maximum-parallel-testing-workers 1`.
- Follow [`docs/ROADMAP.md`](docs/ROADMAP.md) for release scope and [`docs/CLOUDKIT.md`](docs/CLOUDKIT.md) for signing and Production deployment.

Canonical productivity unit: `1 Block = 25 focused minutes`. Breaks are excluded; 12 focused minutes are presented as `0.5 Block`.
