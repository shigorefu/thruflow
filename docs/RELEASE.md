# Release process

This document is the operational checklist for ThruFlow releases. Product scope remains in [`ROADMAP.md`](ROADMAP.md), and CloudKit details remain in [`CLOUDKIT.md`](CLOUDKIT.md).

## Version 1.0.0 build 6

All shipping targets must resolve to:

- marketing version: `1.0.0`;
- build number: `6`;
- Release configuration;
- matching app, widget/Live Activity extension, and Watch versions.

Every later App Store Connect upload must use a build number greater than the last uploaded build, even when the marketing version remains `1.0.0`.

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
- Set `THRUFLOW_APP_STORE_ID` to the numeric App Store ID so the review action can open the correct product page.
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
- Tag the exact commit as `v1.0.0` only after the build is accepted and smoke-tested.
- Publish release notes that clearly identify known limitations and migration behavior.
