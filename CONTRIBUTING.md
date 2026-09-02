# Contributing to ThruFlow

Thank you for helping improve ThruFlow. Before starting a large change, open a
feature request or discussion so product behavior, platform scope, data
migration, and release risk can be agreed first.

By participating, you agree to follow the
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Contribution license

By intentionally submitting a contribution to this repository, you license
that contribution under the
**[BSD 3-Clause License](https://spdx.org/licenses/BSD-3-Clause.html)**
(`BSD-3-Clause`). You retain copyright in your work and represent that you have
the right to submit it under those terms.

The complete terms are in
[`LICENSES/BSD-3-Clause.txt`](LICENSES/BSD-3-Clause.txt). Before an external
contribution is merged, its copyright year and contributor name must be added
to [`CONTRIBUTORS.md`](CONTRIBUTORS.md); official release materials preserve
both notices.

The maintainer may incorporate the contribution into the public
`AGPL-3.0-or-later` source distribution and into separately licensed official
TestFlight or App Store binaries, as explained in
[`LICENSING.md`](LICENSING.md). Do not submit code, media, translations, or
other material whose license is incompatible with this arrangement.

## Before opening a pull request

- Keep the Area → Task → Flow → progress loop coherent.
- Use Japanese as the default user-facing language and update Japanese,
  English, and Russian localizations together.
- Keep business rules outside SwiftUI views and add focused tests for domain or
  persistence behavior.
- Preserve stable identifiers, enum raw values, and existing user history.
- Do not add third-party dependencies without prior agreement.
- Add every third-party copyright and license to `CONTRIBUTORS.md` or a
  dedicated notice file, and confirm that official Apple distribution is
  permitted.
- Never commit signing certificates, provisioning profiles, tokens, private
  user data, exports, or local Xcode state.
- Follow [`CODEX.md`](CODEX.md) and the architecture documents linked from it.

## Verification

Run relevant tests sequentially:

```sh
THRUFLOW_DISABLE_CLOUDKIT=1 xcodebuild test \
  -project ThruFlow.xcodeproj \
  -scheme ThruFlow \
  -destination 'platform=macOS' \
  -only-testing:ThruFlowTests \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -derivedDataPath DerivedData/Tests \
  CODE_SIGNING_ALLOWED=NO
```

Build every affected Release target and run `git diff --check`. UI changes must
be checked on every affected platform and size class. CloudKit, widgets, Live
Activities, StoreKit, notifications, and Watch integration require signed
device verification when touched.

## Pull request contents

Explain the user-visible outcome, implementation scope, verification performed,
known risk, and rollback approach. Include sanitized screenshots or recordings
for UI changes. Keep unrelated refactors in separate pull requests.
