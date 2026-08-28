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
- [x] Version 1.0.0 ten-step onboarding on macOS, iPhone, and iPad. An empty
  first run can create a real Area and Task only after user confirmation, then
  shows the complete production Flow player in a transient scripted sequence:
  Task selection, visual Play, accelerated Short focus from `12:00` to `00:00`,
  and the demonstrated regular break at `03:00`, with no credited or
  synchronized data. The demo omits the note panel; a real Flow starts its break
  only after note confirmation.
  Flow overview and timer guidance are separated, and a dedicated final card
  explains data storage and free core features. Existing-workspace first launch
  and Settings replay are read-only, every card can be closed, and preview
  schemes isolate confirmed examples in memory.
- [x] A non-intrusive system review request after confirmed use, a website
  support link, and a secondary source-code link to GitHub. The first App Store
  release exposes no in-app purchases.
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
- [x] Define `THRUFLOW_APP_STORE_ID` for the direct App Store rating link.
- [ ] Deploy the verified CloudKit Development schema to Production and verify
  a clean install against the Production environment.
- [ ] Confirm app, extension, and Watch version `1.0.0`, aligned build numbers,
  Release signing, icons, and archives without validation errors.
- [ ] Complete closed TestFlight and external smoke tests before submitting an
  App Store build.

### Not blockers for 1.0

- Additional visual polish that does not obstruct the core workflow.
- More Task quick-input capabilities.
- A continuous non-Flow timeline.
- New rewards, AI, or external connectors.

## 1.1.0 — History correctness and workflow polish

### Task capture and Flow

- [x] Suggest previously used Task titles during Task creation on macOS,
  iPhone, and iPad. Rank prefix matches before substring matches, then use
  frequency and recency while deduplicating equivalent titles.
- [x] Reuse the same title-only suggestions while renaming the current Task in
  the macOS Flow timer. Present them as a floating list below the field so the
  timer layout does not change height.
- [x] Keep every newly created Task independent from the historical Todo whose
  title was suggested; copy no completion, progress, Area, measurement, or
  date.
- [x] Give the compact iPhone Flow Task composer an opaque system background so
  opening `+` never exposes transparent content behind the messenger surface.
- [x] Make the compact iPhone Flow Statistics card a swipeable carousel with
  persistent page dots and no previous/next arrow buttons.

### History and Statistics correctness

- [x] Preserve the identity of every Habit Todo occurrence in History. Editing
  a Monday occurrence's title or completion state never mutates a separate
  Wednesday occurrence from the same Habit Area.
- [x] In the History `分野` aggregate, distribute focused time across the exact
  Todo occurrences that recorded it. Show each occurrence's date, Flow count,
  and duration instead of collapsing a whole week into one misleading Task
  row.
- [x] Fix Statistics calendar selection on macOS and iOS so choosing a numbered
  month opens that exact month instead of the previous month, independently of
  the configured Flow-day boundary.
- [x] Keep the complete selected Week, Month, or Year visible in Statistics
  Dots. Future cells remain empty and disabled; Elastic continues to represent
  only the selected date.
- [x] Extend the iPhone History background through the bottom safe area so no
  separate black strip appears below the content.

### Area editor polish

- [x] Use the fixed Area type order `いつでも | 習慣 | できたら` in the macOS and
  iPhone editors without changing persisted enum values or ordering elsewhere.
- [x] Replace the `週に数回` stepper with a compact seven-position slider on
  macOS and iPhone. Show the selected value inside the thumb and keep the
  control accessible through adjustable VoiceOver actions.
- [x] Fit the macOS Area editor window to its content instead of leaving an
  unused column on the right.

### Release metadata

- [x] Align the app and extension marketing versions to `1.1.0` while retaining
  build number `8`.
