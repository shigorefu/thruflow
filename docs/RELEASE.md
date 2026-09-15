# Release process

This document is the operational checklist for ThruFlow releases. Product scope remains in [`ROADMAP.md`](ROADMAP.md), and CloudKit details remain in [`CLOUDKIT.md`](CLOUDKIT.md).

## Released version 1.3.0 build 11

The maintainer confirmed that 1.3.0 has shipped. macOS and iOS/Watch archives
use version `1.3.0`, build `11`, from commit
`36bf54c2b21091c7b031fbfd2f408d627be0b53e`.
See [release notes](releases/1.3.0.md). Fixes developed on `1.3.1` are not
included in this release. This documentation update does not claim to rerun
physical-device, OAuth, or CloudKit Production checks.

## Published releases

| Version | GitHub publication (JST) | Status |
| --- | --- | --- |
| [1.3.0](https://github.com/shigorefu/thruflow/releases/tag/v1.3.0) | 2026-09-15 | Released; latest stable |
| [1.2.0](https://github.com/shigorefu/thruflow/releases/tag/v1.2.0) | 2026-09-08 | Released |
| [1.1.0](https://github.com/shigorefu/thruflow/releases/tag/v1.1.0) | 2026-09-03 | Released |
| [1.0.0](https://github.com/shigorefu/thruflow/releases/tag/v1.0.0) | 2026-08-26 | Released |

## Released version 1.2.0 build 10

The maintainer confirmed that 1.2.0 has shipped. The local macOS and iOS
release archives both report marketing version `1.2.0` and build `10`.
The release source is based on `000f972e11b29fa98cdc5fbedc44941ac632ba5a`,
before the connector development commits. Release preparation updates the
documentation and removes one unused empty localization entry; runtime Swift
source and shipping metadata remain unchanged. See [release notes](releases/1.2.0.md).

Shipping app, widget/Live Activity extension, and Watch targets use matching
marketing version `1.2.0` and build `10`. Test bundle build numbers are not
shipping metadata. Upcoming connector work is not part of this release.

The following sections remain the procedure for future releases. Their presence
is not a claim that this documentation update reran physical-device or upload
checks. Every later App Store Connect upload must use a build number greater
than the last uploaded build; build `11` has already shipped and must not be
reused for a new upload.

## Automated checks

Run unit tests sequentially to avoid excessive simulator and test-runner memory use:

```sh
THRUFLOW_DISABLE_CLOUDKIT=1 xcodebuild test \
  -project ThruFlow.xcodeproj \
  -scheme ThruFlow \
  -destination 'platform=macOS' \
  -only-testing:ThruFlowTests \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -derivedDataPath DerivedData/ReleaseTests \
  CODE_SIGNING_ALLOWED=NO
```

Also build the iOS and Watch Release schemes without signing. CI performs the same categories of checks on pull requests and pushes to `main`.

## App Store Connect prerequisites

- Create the ThruFlow app record with bundle ID `com.shigorefu.thruflow`.
- Confirm `THRUFLOW_APP_STORE_ID = 6798609191` so the review action opens the
  ThruFlow product page.
- Add localized metadata, screenshots, review notes, support URL, and privacy-policy URL.
- In `TestFlight > Test Information`, set a monitored public feedback email;
  do not use the GitHub noreply commit address.
- Keep tester feedback enabled for every TestFlight group unless a documented
  privacy or support reason requires email-only feedback.
- Complete App Privacy answers from the behavior described in [`../PRIVACY.md`](../PRIVACY.md) and the checked-in privacy manifests.
- After the first external contribution, include
  [`../CONTRIBUTORS.md`](../CONTRIBUTORS.md) and the applicable files from
  [`../LICENSES/`](../LICENSES/) in the official binary's acknowledgements.

Recommended public URLs after the files are merged to `main`:

- support: `https://thruflow.shigorefu.com/support`;
- privacy: `https://thruflow.shigorefu.com/privacy`.

## CloudKit and device gate

1. Inspect the Development schema for `iCloud.com.shigorefu.thruflow`.
2. Deploy the verified schema and indexes to Production.
3. Install a clean Release build that uses the Production environment.
4. Test signed macOS, physical iPhone/iPad, and paired Apple Watch builds.
5. Verify offline-to-online changes, simultaneous edits, deletion, history recalculation, active Flow adoption, widgets, Live Activity, and notifications.
6. Verify migration using a copy of the current user database before changing or deleting any real store.

## Archive and upload

1. Select the `ThruFlow iOS` scheme and a generic iOS device destination.
2. Confirm App Store distribution signing for the app, extension, and embedded
   Watch app.
3. Archive with the stable Xcode version recorded for the release.
4. Repeat with the `ThruFlow` scheme and a generic macOS destination. Confirm
   App Store distribution signing for the app and embedded extension.
5. In Organizer, validate both archives before distribution.
6. Upload both archives to App Store Connect and wait for processing
   diagnostics.
7. Install the exact processed builds from TestFlight and complete the smoke
   test on every supported device family.
8. Submit one sanitized screenshot feedback item from iPhone/iPad and one from
   macOS, then confirm both appear under `TestFlight > Feedback` with the
   expected build and device context.

Never publish by rebuilding after the smoke test. Promote the exact tested build.

## After TestFlight validation

- Update the release gate in [`ROADMAP.md`](ROADMAP.md).
- Tag the tested release source as `v<marketing-version>` only after the build
  is accepted and smoke-tested. Existing published tags must not be moved.
- Publish release notes that clearly identify known limitations and migration behavior.

## SDK 27 compatibility checks (1.3.1)

- Keep the existing deployment targets; SDK 27 does not require raising them.
- Live Activity attributes and their content state are nonisolated value types,
  so ActivityKit can transfer them to its concurrent update/end APIs.
- Explicit checkmark labels in selection menus use `titleAndIcon` to preserve
  the selected-state indicator under the new menu image defaults.
- In-memory unit-test stores explicitly disable CloudKit. With automatic
  CloudKit selection on macOS 27, repeated saves failed with
  `No eligible connection available`; the application factory already selects
  `.none` for isolated runs.
- Xcode 27 requires its matching Metal Toolchain component to compile the Flow
  shader. Install it with `xcodebuild -downloadComponent MetalToolchain` if absent.

References: [iOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)
and [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes).
Build and unit-test checks do not replace signed physical-device checks for
Live Activity, widgets, OAuth, and CloudKit Production.
