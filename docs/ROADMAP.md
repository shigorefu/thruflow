# Roadmap

## 1.0.0 — First stable release (released)

Released on GitHub on 2026-08-26. Version 1.0 delivered the core loop:

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

### Archived release preparation checklist

Version 1.0.0 is released. The entries below preserve the preparation record;
unchecked manual items mean their verification was not recorded here. They do
not mean that 1.0.0 remains unreleased.

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

## 1.1.0 — History correctness and workflow polish (released)

Released on GitHub on 2026-09-03.

### Task capture and Flow

- [x] Reset an idle Flow player's previous-day Task occurrence when the app day
  changes on macOS or iOS. Prefer today's incomplete occurrence from the same
  Area, then another incomplete Task for today; keep only the Area when today
  has no Tasks, and never switch a running Flow automatically.
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

- [x] Reconcile an existing Habit Area's Tasks from the current app day after
  its schedule or goal changes on macOS or iPhone. Rebuild only unstarted
  occurrences; preserve completed Tasks, measured progress, and every Task
  already linked to Flow history.
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

## 1.2.0 — Area naming and compatibility (released)

Released on GitHub on 2026-09-08; shipping build `10`.

### Code and persistence

- [x] Rename source files, feature folders, domain/application APIs, views,
  widgets, and tests from Direction to Area.
- [x] Keep the existing SwiftData/CloudKit runtime entity `Direction` and the
  stored Todo/Flow relationship fields `direction`; expose the same records to
  application code through `Area` / `area` without a data migration.
- [x] Preserve stable enum raw values, legacy preference keys, and existing
  Widget/Live Activity Codable wire keys.
- [x] Add a schema contract test that detects an accidental `Area` entity or
  persisted `area` relationship.
- [x] Rename the Statistics CSV column from `direction` to `area`.
- [x] Isolate Debug and Production SwiftData stores so Development CloudKit
  export metadata cannot suppress the later Production export. Keep the
  shipped Production filename `default.store` unchanged.
- [x] Use the rest color for both the Flow timer's resume control and progress
  ring while paused, while keeping focus overtime Area-colored on macOS,
  iPhone, and Apple Watch.
- [x] Make the minimal Dynamic Island timer drain its ring and remaining-time
  number toward zero when another Live Activity shares the Island.
- [x] Allow `−5` and `+5` to adjust the active or paused rest timer on macOS,
  iPhone, Apple Watch, and expanded Dynamic Island while preserving at least
  one minute and keeping long rests classified as long rests.
- [x] Animate timer-ring progress and the active Elastic timeline plan when
  `−5`, `+5`, or a focus-mode change adjusts the current duration.
- [x] Show recognized quick-input values as removable semantic chips above the
  Task title field on iPhone, matching the macOS composer.
- [x] Add title-history suggestions above the iPhone Task edit form without
  changing the edited Task's status, progress, Area, or other metadata.

- [x] Cross out the leading and trailing Statistics Dots cells that belong to
  adjacent months so they are distinct from empty days in the selected month.

### Delivery

- [x] Ship the app, extension, and Watch with marketing version `1.2.0` and
  build number `10`.
- [x] Skip Apple build/test jobs for Markdown-only changes while keeping the
  required GitHub CI status resolvable. Run the complete Apple gate whenever
  any non-Markdown file changes.

## 2.0 — Local connectors (upcoming)

This is development scope for the next major release, not an App Store release
announcement. Existing marketing/build metadata remains on the 1.2.0 line
until the release process explicitly advances it. APNs remains deferred.

### Implemented in the development branch

- [x] Apple Reminders list selection through native EventKit permission.
- [x] Todoist read/write OAuth with PKCE and public HTTPS client metadata.
- [x] Per-device Keychain credentials and local source/Area configuration.
- [x] Connectors above Settings in the Mac sidebar, iPhone Flow More menu,
  and regular-width iPad sidebar footer.
- [x] First import of unfinished Check Tasks; title/deadline refresh preserves
  local completion, planning, memo, progress, Area, and Flow history.
- [x] Manual and foreground refresh, clear error state, safe reconnect and
  disconnect, and Todoist links in imported Task editors.
- [x] Additive optional Todo link metadata; concurrent import reconciliation
  preserves exact Flow relationships and prevents deleted-task resurrection.
- [x] Imported-task protection against generated-Habit merging, schedule edits,
  and pause-driven deletion after a user changes its Area.
- [x] Isolated provider, authorization, import, store, and navigation tests.

### Release gates

- [ ] Pass the complete sequential macOS suite and builds for all supported
  targets; finish Japanese, English, and Russian visual/accessibility review.
- [ ] Verify native Reminders allow/deny/revoke paths and account/list behavior
  on signed macOS and physical iPhone/iPad builds.
- [ ] Deploy and validate the static Todoist client metadata, callback, and
  Associated Domains document on the app website, then test signed OAuth,
  cancellation, token renewal, disconnect, and reconnect on supported OSes.
- [ ] Verify a copy of an existing SwiftData store migrates with all Task and
  Flow relationships intact; deploy the optional link field from CloudKit
  Development to Production before distributing the connector build.
- [ ] Verify repeated and simultaneous imports, source moves, offline recovery,
  late CloudKit history, and local/deleted/completed Task preservation across
  Mac and iPhone using real supported accounts.
- [ ] Complete privacy-policy/App Store metadata, archive, signing, TestFlight,
  and physical-device checks under `docs/RELEASE.md` and `docs/CONNECTORS.md`.

### Deferred

- APNs provider, synchronized remote Live Activity delivery, and webhooks.
- Writing completion or task edits back to external providers.
- New local occurrences generated from recurring external tasks.
- Additional providers, connector management on Watch, and any new pricing.

Connector Check completion/reopening now includes a durable retry outbox and
explicit remote completion reads. Signed two-device conflict and recurrence
checks remain required before the 2.0 release.
