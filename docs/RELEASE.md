# Release process

This document is the operational checklist for ThruFlow releases. Product scope remains in [`ROADMAP.md`](ROADMAP.md), and CloudKit details remain in [`CLOUDKIT.md`](CLOUDKIT.md).

## Preparing 1.5.0 build 16 — 2026-11-24

Version `1.5.0`, build `16` is prepared on branch `1.5.0` across all 14 target
configurations. Reviewed app source is `8603de2749d6af717d1fe7bccd77784768e8ebb9`.
Native images were captured on 2026-11-24; final local validation and inventory
were recorded on 2026-11-25. CI results below refer to this app source, not a
subsequent documentation-only commit.
On 2026-11-25 the maintainer authorized merging the candidate and uploading both
platform builds to App Store Connect/TestFlight. [PR #40](https://github.com/shigorefu/thruflow/pull/40)
was squash-merged as `cd71d58bbc44a860753001e87c1d4319ba0fa85e`.
This is not authorization for App Review submission, public App Store publication,
or a production release tag. Delivery and processing results are recorded
separately from preparation checks below. The [five-language release copy](releases/1.5.0.md)
and screenshot set remain available for App Store preparation.

### Merge validation — 2026-11-25

[Main CI run 45428901958](https://github.com/shigorefu/thruflow/actions/runs/45428901958)
passed at merged source `cd71d58bbc44a860753001e87c1d4319ba0fa85e`: automation
checks, macOS unit tests, macOS Release and iOS Release with the embedded Watch
app. Live Production and Development schema verification was repeated for this
delivery; see [CloudKit](CLOUDKIT.md#release-150-16-delivery-verification--2026-11-25).
The two notification-service App Store profiles require the bounded bootstrap
in [TestFlight delivery](TESTFLIGHT.md#adding-notification-service-distribution-profiles)
before read-only signing can upload this candidate.

The Sol orchestrator and independent macOS/iOS reviewers agreed on the bounded
two-profile bootstrap contract and final implementation. The existing upload
job stays read-only, with no platform presentation or persisted-model changes.
The bootstrap regression suite passed **13 tests / 126 assertions** under Ruby
3.3, including real CMS decoding, binary certificate checks, match v2 round trips
and absence of raw API payload logs. Existing delivery-helper tests (13/35) and
Python automation tests (14) also passed. Actual profile generation, signed
export, Apple processing and physical notification delivery require their own
execution evidence.

### Hosted runner capacity — 2026-11-25

[PR #41 CI, run 45433278706](https://github.com/shigorefu/thruflow/actions/runs/45433278706)
initially cancelled the Apple job after 15 minutes without starting a build.
GitHub reported that no hosted runner was acquired after multiple attempts and
identified macOS arm64 capacity constraints. A job retry also remained queued.
The three Apple job host labels in CI/TestFlight were changed to the standard
`macos-26-intel` image with the same installed Xcode 26.6. Both client reviewers
agreed that generic device destinations and default universal macOS Release
architectures remain unchanged. No required tests, signing checks, environment
protections or delivery gates were removed. The new host still needs actual CI
and signed-export execution evidence.

### Bootstrap test dependency correction — 2026-11-25

[Profile bootstrap run 45441721647](https://github.com/shigorefu/thruflow/actions/runs/45441721647)
failed its offline tests before the secret-bearing Apple API step. Hosted Ruby
3.3.13 loaded the default `mutex_m 0.2.0` through Minitest before Bundler could
activate the locked `mutex_m 0.3.0`. The Apple profile creation and artifact
steps were skipped; no profiles or certificates were changed by that attempt.

The correction declares pinned Minitest as a test-only bundle dependency, loads
Bundler first and executes both Ruby helper suites through `bundle exec` in
ordinary CI and TestFlight source verification. The bootstrap uses the same
resolved bundle. App code, versions, Apple API operations, certificate permissions
and all release gates remain unchanged. A fresh workflow run from the merged
correction is required; rerunning the old source would repeat the dependency
failure.

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
local candidate set; maintainer selection and approval remain pending.
The local `index.html` gallery, `manifest.json` inventory and 25 final review
sheets (`review/<language>-<layout>.jpg`) are present. The manifest records all
200 originals, 40 per layout, their dimensions and SHA-256 hashes, together with
the reviewed app-source identifier. These are local review materials; no App Store
upload is recorded.

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

### Remaining distribution gates

- Obtain maintainer selection and approval of the app, screenshots and localized
  release copy before merging into `main`.
- Prepare and inspect App Store distribution profiles and signed exports for
  `com.shigorefu.thruflow.notifications` on both platforms. Automation includes
  this extension in match/signing/export checks and requires its App Group;
  it does not require CloudKit entitlements. Development profiles and unsigned
  builds do not establish distribution readiness.
- Update App Store privacy answers and the public policy page before
  distribution. Source privacy policy and app/extension manifest edits do not
  establish that external disclosures were published.
- Complete the exact-build signed-device notification and cross-device checks
  in [Notifications](NOTIFICATIONS.md) and [CloudKit](CLOUDKIT.md), or retain
  their explicit unverified status in the release decision. Physical APNs/NSE
  delivery, production-signed exports and real device exchange remain unverified.
  Server-only opt-out leaves iCloud and connectors unchanged; its contract and
  actual server checks are recorded in
  [Notifications](NOTIFICATIONS.md#per-device-server-preference).

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
