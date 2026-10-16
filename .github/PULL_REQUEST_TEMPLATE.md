## Summary

Describe the user-visible outcome and why it belongs in ThruFlow.

## Changes

-

## Verification

- [ ] Relevant unit tests pass sequentially.
- [ ] Both client Release targets build when shared behavior is affected.
- [ ] UI changes were checked on every affected platform and size class.
- [ ] Japanese, English, Russian, Simplified Chinese, and Traditional Chinese strings were reviewed when user-facing text changed.
- [ ] `git diff --check` passes.
- [ ] Documentation and migrations are updated when behavior or stored data changed.

## Cross-platform review

For app changes, use `python3 scripts/platform_review.py --base <task-start-commit>`.
For documentation-only changes, write "Not applicable".

- User action and expected result:
- macOS entry point and evidence:
- iOS/iPadOS counterpart and evidence:
- Shared operation; Watch/widget consumers where applicable:
- Intentional platform differences / why an unchanged counterpart is correct:
- Independent counterpart reviewer findings (or disclose a direct review):
- Checks actually run; unverified scenarios:

## Screenshots or recordings

Add sanitized before/after evidence for UI changes. Remove private productivity data.

## Risk and rollback

Describe persistence, CloudKit, timer, history, signing, and migration risk, or write “None”.

## Contribution license

- [ ] I have the right to submit this contribution and license it under
      `BSD-3-Clause` as described in `CONTRIBUTING.md`.
- [ ] I documented all third-party material and licenses, or this change adds
      none.
