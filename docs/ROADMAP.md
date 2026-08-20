# Roadmap

## 1.0 — First stable release

The goal for 1.0 is to ship a reliable core loop, not expand the product:

```text
Area -> Task -> Flow -> focused time -> progress -> statistics
```

### Implemented

- [x] Shared SwiftData domain and private CloudKit store for macOS and iOS.
- [x] Complete macOS product with Flow, Tasks, History, Areas, and
  Statistics.
- [x] Flow-first iPhone app with Tasks, History, Areas, Statistics, and
  Settings.
- [x] Native wide iPad layout.
- [x] Basic Apple Watch companion.
- [x] Live Activity, Dynamic Island, and Home Screen widgets.
- [x] Exact Flow history, Task switches, breaks, and Flow series.
- [x] Task and Area progress reconciliation after history creation,
  editing, and deletion.
- [x] Japanese, English, and Russian localizations.
- [x] Theme, language, first-weekday, time-format, and new-day-boundary settings.
- [x] Version 1.0.2 eight-step onboarding on macOS, iPhone, and iPad. An empty
  first run can create a real Area and Task only after user confirmation, then
  shows the complete production Flow player in a transient scripted sequence:
  Task selection, visual Play, accelerated Short focus from `12:00` to `00:00`,
  and the demonstrated regular break at `03:00`, with no credited or
  synchronized data. The demo omits the note panel; a real Flow starts its break
  only after note confirmation.
  Existing-workspace first launch and Settings replay are read-only, every step
  is skippable, and preview schemes isolate confirmed examples in memory.
- [x] A non-intrusive system review request after confirmed use, a GitHub link,
  and optional StoreKit tips: coffee ¥100 / ramen ¥500.
- [x] Core Tasks, Flow timer, History, and Statistics remain free and ad-free
  without required payment; future optional integrations are not covered by
  that pricing promise.
- [x] Configurable Statistics CSV export.
- [x] Safe deletion of all Flow history from Settings while preserving Tasks
  and Areas, resetting derived progress, and syncing through private
  CloudKit.

### Release gates

Every item below is required before publishing 1.0:

- [ ] Complete at least one week of daily-use burn-in without lost or duplicate
  Tasks, Habits, Flow segments, breaks, or completion progress.
- [ ] Complete the real-device matrix: signed macOS app, physical iPhone, and
  Apple Watch. Verify launch, pause/resume, break, force-quit/reboot restoration,
  and adopting an active Flow from another device.
- [ ] Verify CloudKit conflict and reconciliation behavior for simultaneous
  edits, offline-to-online recovery, history deletion/editing, and Habit
  deduplication.
- [ ] Migrate a copy of the current user SwiftData database to a release build
  without clearing the store.
- [ ] Complete targeted tests for timer restoration, history mutation, progress
  reconciliation, Habit materialization, and CloudKit runtime revisions; fix
  all reproducible crashes and UI freezes.
- [ ] Verify Live Activity, Dynamic Island, widgets, and Watch on a release
  build, including extension termination and a temporarily unavailable App
  Group.
- [ ] Finish the `ja`, `en`, and `ru` review for truncation, Dynamic Type,
  VoiceOver labels, light/dark appearance, and narrow windows or screens.
- [x] Add and verify `PrivacyInfo.xcprivacy` for the app, Watch app, and
  widget/Live Activity extension.
- [ ] Complete App Store privacy answers, privacy-policy and support URLs, and
  the private-iCloud-sync description.
- [ ] Create consumable IAPs in App Store Connect with identifiers
  `com.shigorefu.thruflow.tip.coffee` and
  `com.shigorefu.thruflow.tip.ramen`; set Japanese prices to ¥100 and ¥500,
  provide localizations and a review screenshot, then define
  `THRUFLOW_APP_STORE_ID` for the direct review link.
- [ ] Deploy the verified CloudKit Development schema to Production and verify
  a clean install against the Production environment.
- [ ] Confirm app, extension, and Watch version `1.0.2`, aligned build numbers,
  Release signing, icons, and archives without validation errors.
- [ ] Complete closed TestFlight and external smoke tests before submitting an
  App Store build.

### Not blockers for 1.0

- Additional visual polish that does not obstruct the core workflow.
- More Task quick-input capabilities.
- A continuous non-Flow timeline.
- New rewards, AI, or external connectors.

## 1.1 — Intentional unrecorded time

This feature does not block TestFlight or 1.0. In 1.0, History continues to
show unrecorded gaps and lets the user fill them manually. After validating the
core loop with real users, the app may gently offer to classify long periods
outside Flow.

- [ ] Validate a useful threshold from TestFlight feedback before building it;
  the initial assumption is `60–90` minutes without a record.
- [ ] Present an optional suggestion when opening the app or History, not an
  interrupting popup or automatic notification.
- [ ] Ask neutrally, “What occupied this time?”, without implying inactivity.
- [ ] Offer quick choices for Sleep, Rest, Meal, Travel, Other, and Skip.
- [ ] Allow dismissing the question, disabling suggestions for the current day,
  or turning the feature off entirely.
- [ ] Avoid a series of prompts after a night or long absence; combine gaps into
  one calm review.
- [ ] Store non-Flow time separately from Task and Area progress. These
  records never earn Blocks or count as focused time.

## Other work after 1.0

- More detailed watchOS Statistics.
- Further improvements to the quick Task composer.
- A more deliberate reward system for Optional Areas (`できたら`).

## 2.0 — Server transport and connectors

- [ ] Add an optional serverless APNs backend:
  `API Gateway -> Lambda -> EventBridge Scheduler -> APNs`.
- [ ] Register and update ActivityKit push tokens without storing the Apple
  `.p8` key in the app.
- [ ] Update Live Activity through APNs at the `00:00` boundary so a suspended
  iPhone reliably shows overtime as `+MM:SS`.
- [ ] Add a server reminder for a Flow or break that continues for more than an
  hour.
- [ ] Add retry and idempotency, one-shot schedule cleanup, minimal CloudWatch
  logs, and AWS Budget alerts.
- [ ] Keep the local timer and CloudKit as the source of truth: missing backend
  connectivity must never prevent starting or saving Flow.
- [ ] Add connectors such as Toggl, Strava, Jira, and other OAuth/webhook
  integrations.

## After 2.0

- AI summaries.
- Pets.
