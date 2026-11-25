# Release process

This document is the operational checklist for ThruFlow releases. Product scope remains in [`ROADMAP.md`](ROADMAP.md), and CloudKit details remain in [`CLOUDKIT.md`](CLOUDKIT.md).

## 1.5.0 (16) delivered to App Store Connect — 2026-11-25

Both platforms were uploaded and finished Apple processing from tested source
`435d5ae1df4662c31afb35fc9cbbabc60bc214ef`. All 14 target configurations use
`1.5.0` / `16`. App, project and extension source is unchanged from reviewed
`8603de2749d6af717d1fe7bccd77784768e8ebb9`; subsequent changes prepared delivery
tooling and recorded verification. This is a TestFlight/App Store Connect
candidate, not a published App Store release. No App Review submission or
production release tag was created.

[PR #40](https://github.com/shigorefu/thruflow/pull/40) merged the app candidate;
[PR #41](https://github.com/shigorefu/thruflow/pull/41) and
[PR #42](https://github.com/shigorefu/thruflow/pull/42) prepared signing and hosted
tooling. The maintainer authorized merge and both uploads on 2026-11-25.

### Delivery evidence

[TestFlight run 45452911016](https://github.com/shigorefu/thruflow/actions/runs/45452911016)
completed successfully, including signed export validation and temporary Keychain
cleanup for both platforms. Times below are **JST, 2026-11-25**.

| Platform | Upload accepted | Processing completed | App Store Connect |
| --- | --- | --- | --- |
| iOS, including Watch | 03:27:41 | 03:30:17 | [1.5.0 (16)](https://appstoreconnect.apple.com/teams/577567e5-2bb3-4b5b-bd40-37252e6f118a/apps/6798609191/testflight/ios/00d813c5-7872-40c5-b633-7b686f46a030) |
| macOS | 03:41:08 | 03:43:14 | [1.5.0 (16)](https://appstoreconnect.apple.com/teams/577567e5-2bb3-4b5b-bd40-37252e6f118a/apps/6798609191/testflight/macos/cb696acf-ed0f-4708-86ca-77dccb88c619) |

Both live TestFlight pages were read back with version `1.5.0`, build `16` and
status `提出準備完了` (Ready to Submit). No tester groups were added, external
beta review requested, or public release performed. These uploaded binaries keep
the source SHA above even after documentation-only follow-up commits.

- [Final main CI 45452350929](https://github.com/shigorefu/thruflow/actions/runs/45452350929)
  passed automation checks, macOS unit tests and both Release builds, including
  embedded Watch. [PR #42 CI](https://github.com/shigorefu/thruflow/actions/runs/45445669292)
  also passed on the standard Intel runner with Xcode 26.6.
- TestFlight source verification passed **615 tests in 61 suites**, including
  the release screenshot fixture, with CloudKit disabled and isolated data. The
  hosted test run completed in 1155.338 seconds with `TEST SUCCEEDED`.
- Delivery tooling passed **26 Ruby tests / 161 assertions** and **18 Python
  tests**, plus syntax, YAML and diff checks. The actual Ubuntu bootstrap tests
  also passed before its Apple API step.
- [Bootstrap 45452440651](https://github.com/shigorefu/thruflow/actions/runs/45452440651)
  created the two NSE App Store profiles using the existing distribution
  certificate and App Group. Both profiles were validated and match-v2 encrypted;
  the exact two-file ciphertext artifact was checked and committed to the private
  signing repository (`129f0a5`). Its CI deploy key remains read-only. No existing
  certificate was revoked, exported or replaced.
- Export validation checked signatures, expected bundle IDs, version/build,
  signing team, development entitlements, NSE App Group and required CloudKit
  Production entitlements before upload. Installer signature validation passed
  for macOS. [Live CloudKit verification](CLOUDKIT.md#release-150-16-delivery-verification--2026-11-25)
  covered both environments and all six model types without mutations.

The Sol orchestrator and independent macOS/iOS reviewers agreed on the common
profile/tooling contract, final source and runtime delivery evidence. Intentional
profile platform/identifier differences are retained; app presentation and
persisted models were unchanged. Physical APNs/NSE delivery, real device CloudKit
exchange and exact-build native UI behavior remain unverified.

### Resolved hosted delivery issues

| Evidence | Cause | Correction |
| --- | --- | --- |
| [Runner acquisition failure](https://github.com/shigorefu/thruflow/actions/runs/45433278706) | macOS arm64 capacity; no build started for 15 minutes | Standard `macos-26-intel`, same Xcode 26.6, destinations and gates |
| [Offline bootstrap failure](https://github.com/shigorefu/thruflow/actions/runs/45441721647) | Host Minitest activated `mutex_m 0.2.0` before locked `0.3.0` | Pinned test-only Minitest; Bundler first and bundled helper suites |
| [Unavailable Metal compiler](https://github.com/shigorefu/thruflow/actions/runs/45441591964) | Downloadable component could not remount (`kDAReturnBusy`) | Shared compiler probe, conditional Apple component installation and mandatory recheck |

The failed bootstrap stopped before secrets-bearing Apple calls; it changed no
profiles. No tests, shader behavior, signing checks or environment protections
were removed to resolve these issues. See [TestFlight delivery](TESTFLIGHT.md)
for the maintained procedure.

### Local validation

- The final complete macOS suite passed **615 tests in 61 suites**, including
  the five-language screenshot fixture, on the reviewed source. Tests used
  isolated storage with CloudKit disabled; the suite completed in 8.461 seconds
  and the test command exited 0 with `TEST SUCCEEDED`. Evidence:
  `DerivedData/Release150QA/release-final-tests.log`.
- The latest iOS screenshot/demo and unsigned iOS Release builds passed; iOS
  Release includes embedded Watch. Evidence: `flow-framing-ios-demo.log` and
  `flow-framing-ios-release.log` in the same QA directory. Mac Debug and unsigned
  macOS Release passed at `4f08d4d`; Mac presentation source is unchanged by the
  later iOS-only screenshot-framing addition. The earlier `duration-fit-*.log`
  builds also passed. The notification service privacy manifest was inspected
  in both platform build products.
- Preparation checks passed: 28 backend tests, 13 Ruby delivery-helper tests
  with 35 assertions, 14 Python automation tests, platform-review mapping and
  whitespace checks. Live CloudKit Production was inspected without changes;
  see the [dated schema record](CLOUDKIT.md#release-150-16-preparation--2026-11-24).
- [App-source CI for `8603de2`, run 45414260579, attempt 2](https://github.com/shigorefu/thruflow/actions/runs/45414260579)
  passed both classification and Apple build/test jobs. The initial attempt did
  not acquire a hosted Apple runner after repeated attempts, as recorded by
  GitHub's capacity annotation; the rerun resolved this infrastructure failure.
  [Earlier CI for `4f08d4d`](https://github.com/shigorefu/thruflow/actions/runs/45410358538)
  also passed.

### Local screenshot set and platform review

All **200 native JPEG candidates** are captured under the Git-ignored
`screenshots/1.5.0/`: eight routes × five layouts × five languages. Identified
loading-state, text-fit and framing images were replaced. This completes the
local candidate set. The selected draft uploads are recorded below; maintainer
review and approval remain pending.
The local `index.html` gallery, `manifest.json` inventory and 25 final review
sheets (`review/<language>-<layout>.jpg`) are present. The manifest records all
200 originals, 40 per layout, their dimensions and SHA-256 hashes, together with
the reviewed app-source identifier. The complete local set remains available;
155 selected images were uploaded to the App Store drafts as recorded below.

Independent overview review agreed on all 25 canonical sheets / 200 thumbnails:
10 iPad/iPhone sheets (80 thumbnails) and 15 Mac/Duo Closed/Duo Open sheets
(120 thumbnails). This complements the native image checks below; it is not a
full native-size text or native-speaker audit.

| Layout | Native JPEG dimensions | Images |
| --- | --- | --- |
| Mac | 2560 × 1600 | 40 |
| iPhone | 1206 × 2622 | 40 |
| iPad | 2752 × 2064 | 40 |
| iPhone Duo Closed | 1398 × 2034 | 40 |
| iPhone Duo Open | 2853 × 2007 | 40 |

Independent visual checks confirmed the final Mac Statistics images 05–08 in
all five languages: data loaded, complete rings, two-line English/Russian center
captions and full Chinese durations. Reviewed Chinese Duo Open Statistics
captures retain their native 2853 × 2007 frame. Closed Duo Flow 01 in all five
languages shows the complete timer and controls using the isolated Debug framing
flag. All 40 iPhone captures were viewed; the History/Areas clocks were confirmed
in the actual image files, with no app status-bar change. All 40 iPad captures
passed after replacing the three loading-state images; no specific underlying
cause for those transient captures was established.

Long Task properties, titles and legends retain native ellipsis where space is
limited. Large iPad Statistics images 05–08 may coincide when the full report
fits without scrolling.

Both client reviewers agreed on longest-relative, left-anchored distribution
bars, centered wider seven-day bars and bounded larger achievement rings.
Daily donut shares, completion calculations and recorded data are unchanged.
Counterpart reviews also agreed on bounded caption/value fitting and the
Debug-only iOS screenshot scroll, with normal and Release launches unaffected.
Native Mac and iPad checks covered all three compact Flow Statistics pages.
The server-OFF setting was exercised in the Mac demo. iPhone timer start/pause was exercised, with the countdown
observed at 24:52 after starting from 25 minutes. Compact iPhone Flow Statistics
pages two and three were not gesture-verified because automated scrolling was
unavailable; the screenshots do not establish those interactions.

### App Store Connect drafts — 2026-11-25

Created the iOS and macOS `1.5.0` versions and selected processed build `16` on
both. The [iOS draft](https://appstoreconnect.apple.com/apps/6798609191/distribution/ios/version/inflight)
and [macOS draft](https://appstoreconnect.apple.com/apps/6798609191/distribution/macos/version/inflight)
remain `提出準備中` (Prepare for Submission). No App Review item was added or
submitted, and no public release was performed.

Saved the [five-language release notes and description addendum](releases/1.5.0.md)
in Japanese, US English, Russian, Simplified Chinese and Traditional Chinese on
both platforms. Existing descriptions were retained and extended with the
notification server default, per-device local-only option and exclusion of Task
names/notes from server requests. Existing names, keywords, pricing, review
contacts and public privacy answers were not changed. Independent localization
review agreed on the source copy in all five languages; this is not a full
native-speaker or live layout audit.

Uploaded the following images from `screenshots/1.5.0/{locale}/`, in the order
shown, for each of the five locales:

| App Store set | Selection | Per locale | Total |
| --- | --- | --- | --- |
| Mac | `Mac/01–08` | 8 | 40 |
| iPhone, medium Dynamic Island display | `iPhone/01–08` | 8 | 40 |
| iPad, 13-inch display | `iPad/01–05` | 5 | 25 |
| iPhone Duo | Combined selection below | 10 | 50 |
| **Total** | | **31** | **155** |

The Duo sequence is Closed Flow, Open Flow, Closed Tasks, Open Tasks, Closed
History, Open History, Open Areas, Open Statistics, Open Statistics Trend and
Open Statistics Breakdown. The iPad Statistics captures `05–08` are byte-identical,
so only `05` was selected. Duo Open `06` and `08` are also byte-identical; the
selection uses `06`. Independent asset review verified all 200 source hashes
and dimensions against the manifest and checked representative contact sheets.

All 20 device/locale sets were read back with the expected counts and filename
order. Both saved drafts were reloaded, and all ten localized text pages were
read back with matching release notes and description additions. Old screenshot
associations were replaced only in the new drafts; original assets remain in
Apple's asset library. A local, Git-ignored selection/evidence inventory is
`screenshots/1.5.0/appstore-draft.json`. These checks establish saved metadata
and assets, not App Review approval or physical-device notification/sync behavior.

### Remaining public release gates

- Obtain maintainer review and approval of the saved App Store drafts above.
  The 200-image local candidate set remains available alongside the 155 uploaded
  selections. Do not add to App Review or submit until explicitly authorized.
- Update App Store privacy answers and the public policy page before public
  distribution. Source policy/manifests do not establish published disclosures.
- Complete exact-build signed-device checks in [Notifications](NOTIFICATIONS.md)
  and [CloudKit](CLOUDKIT.md), or retain their explicit unverified status in the
  release decision. Physical APNs/NSE delivery and real Mac/iPhone exchange remain
  unverified; signed exports and Apple processing are verified above. Server-only
  opt-out leaves iCloud and connectors unchanged; see
  [the notification contract](NOTIFICATIONS.md#per-device-server-preference).

## Released 1.4.1 build 15

The maintainer confirmed App Store publication on 2026-11-12. The [TestFlight
workflow](https://github.com/shigorefu/thruflow/actions/runs/42777913607) delivered
this build from commit `96b7ba6`. See the [Changelog](../CHANGELOG.md#141---2026-11-12)
and the [CloudKit Production record](CLOUDKIT.md#release-141-build-15-preparation--2026-11-10).

## Released 1.4.0 build 14

Updated on 2026-10-30 from the merged 1.4.0 development scope. All Debug and
Release configurations for macOS, iOS, Watch, the widget/Live Activity extension
and test bundles use marketing version `1.4.0`, build `14`. App Store publication was confirmed by the maintainer on 2026-10-30.
See [release notes](releases/1.4.0.md).

Build 14 corrects localized month picker labels and includes isolated screenshot
schemes. Xcode 27.1 (27A9275) is the local development toolchain; CI retains its
separately pinned Xcode version. The month-label change does not alter persisted
models. Live Production CloudKit was inspected again on 2026-10-29; see
[CloudKit evidence](CLOUDKIT.md#release-140-build-14-preparation--2026-10-29).
Signed-device checks were not repeated; the upload gates below still apply.

### App Store Connect draft — 2026-10-29

[PR #28](https://github.com/shigorefu/thruflow/pull/28) was merged into main
at `838a44dc6ae75e3a0073d7527ec6cddb2c5d9450`. The
[main CI run](https://github.com/shigorefu/thruflow/actions/runs/40814805364)
passed macOS tests and both Release builds, including embedded Watch.

Created iOS and macOS 1.4.0 drafts, with release notes in Japanese, English,
Russian, Simplified Chinese and Traditional Chinese. Added Chinese descriptions,
keywords, app name and subtitle. Replaced screenshots for all five locales:
6 iPhone, 6 iPad, 6 Mac and 10 Duo images per locale (140 total). Duo uses
5 closed and 5 open screenshots to fit its ten-image limit. Source assets remain
in the gitignored `screenshots/1.4.0/` directory. Prior screenshot associations
were removed from the drafts; original assets remain in the asset library.

The maintainer subsequently authorized upload and App Review submission. Both
iOS and macOS 1.4.0 (14) were uploaded through GitHub Actions, processed as
`VALID`, selected and submitted. App Store Connect showed Waiting for Review
for both platforms (iOS at 14:24 JST; macOS at 14:42 JST on 2026-10-29).
The existing automatic release after approval setting was preserved. The maintainer confirmed App Store publication on 2026-10-30. See
[TestFlight delivery evidence](TESTFLIGHT.md#account-setup-progress--2026-10-29).

Remaining verification:

- Verify signed Mac/iPhone exchange of Projects, Task assignments and Task times/
  reminder preferences, including delivery and cancellation of local notifications.
  Live Production schema additions were deployed and read back on 2026-10-16
  (Projects) and 2026-10-18 (Task timing); see [CloudKit evidence](CLOUDKIT.md#task-times-and-reminders--2026-10-18).
- Signed archives and exported bundle checks passed in the delivery workflow.
  Runtime testing of the exact processed TestFlight builds on Mac, iPhone/iPad
  and Watch remains unverified.


Historical release notes are in [Changelog](../CHANGELOG.md) and `releases/`.
Earlier preparation logs remain available in Git history.

## CloudKit schema gate for every model change

Before uploading a build that adds persisted properties, compare its SwiftData
fields with the live Development and Production record types. Materialize and
deploy additive fields, reload Production to verify names/types, then confirm a
real two-device exchange. Local builds/tests and an upload marked successful do
not satisfy this gate. For 1.3.1, `CD_Todo.CD_habitOccurrence` (`INT64`) was deployed
on 2026-09-20; see [the incident record](CLOUDKIT.md#production-schema-repair--2026-09-20).

## Automated checks

Run the complete unit suite sequentially to avoid excessive simulator and
test-runner memory use. This includes the five-language screenshot fixture test.
Regular CI skips that one test. The TestFlight verification job runs it as part
of the complete suite before upload.

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
3. Enable exactly one `--screenshot-screen=<route>` argument; `flow` is enabled
   by default. Each checked-in scheme supplies six presets. For
   `statistics-trend` or `statistics-breakdown`, add the matching argument
   manually and disable every other screen argument. `ScreenshotScreen` supports
   all eight routes below; the two extra routes are not prelisted in the schemes.
4. Run and wait for the actual screen and fixture data to finish loading before
   capturing at the intended App Store device/window size. Verify the language,
   selected date, non-placeholder metrics and intended chart/scroll position.
   Statistics anchor routes wait for report data before scrolling; a fixed delay
   or a nonblank frame alone does not establish readiness. Check duration/unit
   wrapping and donut center text in every language. Build/run does not itself
   capture or upload an image.
5. Save `screenshots/<version>/<language>/<layout>/<NN>-<route>.jpg`. The five
   layouts are `Mac`, `iPhone`, `iPad`, `iPhoneDuo-Closed` and `iPhoneDuo-Open`.
   Eight routes × five languages × five layouts make 200 candidate files;
   their presence is separate from visual review and maintainer approval.
   `/screenshots/` is ignored by Git; do not commit generated captures or private
   user screenshots. Stop temporary QA apps after capture.

| File | Route | Native start | Scheme preset |
| --- | --- | --- | --- |
| `01-flow.jpg` | `flow` | Flow dashboard | Yes; default |
| `02-tasks.jpg` | `tasks` | Tasks | Yes |
| `03-history.jpg` | `history` | History | Yes |
| `04-directions.jpg` | `directions` | Areas, including Project children | Yes |
| `05-statistics.jpg` | `statistics` | Statistics, initially Month | Yes |
| `06-statistics-trend.jpg` | `statistics-trend` | Month report scrolled to Focus Quality | Add manually |
| `07-statistics-breakdown.jpg` | `statistics-breakdown` | Month report scrolled to Distribution | Add manually |
| `08-statistics-dots.jpg` | `statistics-dots` | Month report scrolled to Dots | Yes |

### Native iPhone Duo capture

For the Duo simulator used for 1.5.0 preparation, capture the native display
matching its actual posture:

| Posture | `simctl io <UDID> screenshot` option | Output layout |
| --- | --- | --- |
| Closed | `--display=1` | `iPhoneDuo-Closed` |
| Open | `--display=3` | `iPhoneDuo-Open` |

Select Closed or Open using the simulator's native posture control before
launch/capture. A display option selects a buffer; it does not change posture.
After a posture change or relaunch, confirm that the visible compact/expanded
layout, active display and fixture data agree, then wait for the intended route
to settle. Reject blank, stale, transitional or wrong-posture frames rather
than renaming them into the other layout. Preserve native aspect ratios.
The display numbering is specific to the tested simulator; reconfirm it when
changing the simulated device or toolchain.

For a timer-focused mobile Flow capture, optionally add
`--screenshot-flow-section=timer` together with `--screenshot-mode` and
`--screenshot-screen=flow`. After the visible fixture snapshot and Task groups
load, the iOS Debug presentation scrolls the existing player to the top without
animation. It does not resize or reorder cards, start a timer or change data.
The flag is inert in normal launches and Release, and has no Mac/Watch effect.
Use this framing for Closed Duo `01-flow.jpg` when a timer-focused view is
needed. All five 1.5.0 language captures were replaced and independently checked
with the complete timer and controls visible; other routes retain their normal
framing.

Local review composites belong under `screenshots/<version>/review/` and are not
App Store candidates or part of the 200-file count. Rebuild any gallery/manifest
after replacing captures so dimensions, hashes and missing-file status describe
the current originals. Review composites never replace individual image review.

### Isolation and Watch

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
