# Release process

This document is the operational checklist for ThruFlow releases. Product scope remains in [`ROADMAP.md`](ROADMAP.md), and CloudKit details remain in [`CLOUDKIT.md`](CLOUDKIT.md).

## Release candidate 1.4.0 build 14

Updated on 2026-10-29 from the merged 1.4.0 development scope. All Debug and
Release configurations for macOS, iOS, Watch, the widget/Live Activity extension
and test bundles use marketing version `1.4.0`, build `14`. This is preparation,
not a published release. See [draft release notes](releases/1.4.0.md).

Build 14 corrects localized month picker labels and includes isolated screenshot
schemes. Xcode 27.1 (27A9275) is the local development toolchain; CI retains its
separately pinned Xcode version. The month-label change does not alter persisted
models. Production CloudKit and signed-device checks were not repeated for this
local correction; the upload gates below still apply.

Before upload:

- Confirm build 14 has not already been uploaded in App Store Connect; local
  metadata advances the previous candidate build 13 but does not inspect
  the account's upload history.
- Verify signed Mac/iPhone exchange of Projects, Task assignments and Task times/
  reminder preferences, including delivery and cancellation of local notifications.
  Live Production schema additions were deployed and read back on 2026-10-16
  (Projects) and 2026-10-18 (Task timing); see [CloudKit evidence](CLOUDKIT.md#task-times-and-reminders--2026-10-18).
- Produce and validate signed distribution archives, then verify the exact
  processed TestFlight builds on Mac, iPhone/iPad and Watch.
- Keep 1.3.1 marked as the latest stable release until publication is confirmed.

Local Projects/Area-restoration validation on 2026-10-16: 499 tests passed,
including pre-Project disk-store migration and rollback. Release macOS and
iOS/Watch builds succeeded without warnings. macOS UI was exercised using an
isolated in-memory demo: create Project/Task, complete/reopen Project, archive and
restore Area. The iOS 27 simulator build also succeeded without warnings and
launched with in-memory demo data, but interactive iPhone/iPad visual QA remains
unverified because this Xcode installation has no Simulator.app UI. The temporary
simulator was shut down and removed. These checks do not validate signed-device
sync or a distributed build.

Task-time/reminder validation on 2026-10-18: **521 tests in 50 suites passed**;
Release macOS and iOS builds succeeded without compiler warnings, including the
embedded Watch app. Tests cover strict `HH:mm` parsing, separate duration input,
save/readback/rollback, migration defaults, Habit/connector timing reconciliation,
DST, notification eligibility, capacity, retries and serialized updates. Expected
injected persistence-failure logs and incidental system `com.apple.linkd` messages
did not fail the test run.

An isolated in-memory macOS QA app verified pasted quick input
`QA reminder 14:30 [30m]`, separate clock/duration chips, native time controls,
reminders off by default, save/reset, editor readback, and clearing the date/time.
The temporary app was stopped; no task-owned test runners remained. Physical
typing, iPhone/iPad/Watch visual layouts, OS permission prompts, signed notification
delivery and cross-device synchronization were not verified by this check.

The macOS and iOS/Watch reviewers explicitly agreed on the final shared contract
and each other's findings. A separate localization reviewer agreed on six new
keys and two reused labels across all five locales; this was a source review,
not native-speaker or device-layout verification. These checks do not replace the
signed-device gates above. Version/build remains 1.4.0 (13); nothing was uploaded
or published as part of this feature implementation.

## Released version 1.3.1 build 12

The maintainer confirmed on 2026-09-21 that 1.3.1 has shipped. macOS and iOS/Watch
use version `1.3.1`, build `12`; both platform archives were uploaded to Apple on
2026-09-20. The GitHub release source is
`a6f1b33a32da2caf3dba8f042265331744fa6e25`.
See [English release notes](releases/1.3.1.md).

The live Production schema was inspected and repaired on 2026-09-20, and the
maintainer confirmed restored Mac/iPhone synchronization. This publication
update records the released status; it does not claim a new device or schema test.

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
| [1.3.1](https://github.com/shigorefu/thruflow/releases/tag/v1.3.1) | 2026-09-21 | Released; latest stable |
| [1.3.0](https://github.com/shigorefu/thruflow/releases/tag/v1.3.0) | 2026-09-15 | Released |
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
than the last uploaded build; build `12` has already shipped and must not be
reused for a new upload.

## CloudKit schema gate for every model change

Before uploading a build that adds persisted properties, compare its SwiftData
fields with the live Development and Production record types. Materialize and
deploy additive fields, reload Production to verify names/types, then confirm a
real two-device exchange. Local builds/tests and an upload marked successful do
not satisfy this gate. For 1.3.1, `CD_Todo.CD_habitOccurrence` (`INT64`) was deployed
on 2026-09-20; see [the incident record](CLOUDKIT.md#production-schema-repair--2026-09-20).

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

## Localized App Store screenshots

Use the screenshot schemes in **Debug** to capture the current native UI with
localized sample data. These are separate from the smaller `ThruFlow Demo` QA
fixtures; they seed approximately 180 days of history, Tasks, Areas and Projects.
Fixtures are fictional and neutral: reports, correspondence, language practice,
reading and everyday activities. Historical durations are tied to the activity
identity, not randomly chosen timer modes (for example, email takes 10 minutes).
Project relationships follow the activity: correspondence and planning do not
belong to the report project. No production database is copied.
The sample reference time is 18:30 on the launch date, so captures from different
calendar dates are not byte-for-byte identical.

| Language | macOS scheme | iPhone/iPad scheme | Language argument |
| --- | --- | --- | --- |
| Japanese | `ThruFlow Screenshots JA` | `ThruFlow iOS Screenshots JA` | `ja` |
| English | `ThruFlow Screenshots EN` | `ThruFlow iOS Screenshots EN` | `en` |
| Russian | `ThruFlow Screenshots RU` | `ThruFlow iOS Screenshots RU` | `ru` |
| Simplified Chinese | `ThruFlow Screenshots ZH-HANS` | `ThruFlow iOS Screenshots ZH-HANS` | `zh-Hans` |
| Traditional Chinese | `ThruFlow Screenshots ZH-HANT` | `ThruFlow iOS Screenshots ZH-HANT` | `zh-Hant` |

1. Choose the scheme and a Mac or iOS Simulator destination in Xcode.
2. In **Edit Scheme > Run > Arguments**, keep `--screenshot-mode` and the scheme's
   `--screenshot-language=<language>` enabled. The matching `-AppleLanguages` and
   `-AppleLocale` arguments localize system controls too.
3. Enable exactly one `--screenshot-screen=<route>` argument. All six are supplied
   by each scheme; `flow` is enabled by default.
4. Run, wait for the real screen to finish laying out, and capture it at the
   intended App Store device/window size. Build/run does not itself capture or
   upload an image. Check text wrapping, selected dates and chart loading in each
   language before using the image.
5. Save images under the visible local `screenshots/1.4.0/` directory, organized
   by platform and language. `/screenshots/` is ignored by Git; do not commit
   generated captures or private user screenshots. Stop temporary QA apps after
   capture.

| Route | Native screen |
| --- | --- |
| `flow` | Flow dashboard |
| `tasks` | Tasks |
| `history` | History |
| `directions` | Areas, including Project children |
| `statistics` | Statistics, initially Month |
| `statistics-dots` | Statistics, initially Month and scrolled to Dots |

Watch has no dedicated screenshot schemes. A Debug Watch launch with the same
arguments supports its native Flow, Tasks and Statistics pages; History and
Areas routes fall back to Flow because Watch has no corresponding screens.

Isolation is enforced by `ScreenshotMode`, not by a different production bundle
or a copied user database. `--screenshot-mode` is disabled in Release. In Debug,
SwiftData uses an **in-memory** container with CloudKit disabled, and seeded data
is discarded when the process exits. This path never opens the user's persistent
store or accesses Development/Production CloudKit. Preferences use a separate,
uniquely named **persistent UserDefaults suite** per process; they are not
memory-only, but never write screenshot settings into the normal app preference
domain. Failure to create that suite stops the screenshot launch instead of
falling back to standard preferences.

Screenshot launches use isolated connector state and recording identity, skip
credential access and connector synchronization, and disable notification
permission/scheduling, Live Activities, widget snapshot publication and review
prompts. They do not verify signing, notifications, widgets or cross-device sync.
The live Production schema and signed-device gates below still apply to releases.

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

## Automated TestFlight delivery

The [TestFlight pipeline](TESTFLIGHT.md) defines protected tag/manual delivery,
Fastlane signing and required environment settings. Ordinary pushes only run CI.
Initial setup and live Production verification are required before its first upload.

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
