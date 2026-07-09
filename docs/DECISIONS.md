# Decisions

## Accepted

### D-001: Local-first SwiftData MVP

Use SwiftData locally for MVP 0.1. CloudKit is planned but must not be required for launch or local testing.

Reason: the core product loop must be reliable before sync complexity is introduced.

### D-002: Direction is the central object

Direction represents a recurring area of attention and owns the meaning that habit categories, activity areas, and life domains would otherwise split across multiple concepts.

Reason: this keeps Today, Todos, Flow, and future statistics connected to a stable domain object.

### D-003: Habit, Neutral, and Nice are explicit types

Use stable enum raw values for Direction type:

- `habit`
- `neutral`
- `nice`

Reason: the product separates automatic recurring work from manually planned tasks and positive optional activity. Older local stores may still contain `must` and `bonus`; the app reads them as `habit` and `nice`.

### D-004: Weekly goals are not failed by empty days

Weekly goals are judged by week totals. Individual empty days are factual empty days, not failed habit days.

Reason: this matches goals such as training 3 times per week and avoids punishing flexible schedules.

### D-004a: Habit Direction goal schedule is explicit

Only `習慣` Directions ask for a goal. The creation flow records a goal value, a unit, and one frequency mode: `毎日`, `週回`, or `曜日`. `通常` and `ナイス` Directions stop after type selection and do not carry goal fields.

Reason: goal setup should stay clear at creation time and avoid showing irrelevant controls for non-habit Directions.

### D-005: Intent and Result stay separate

FlowSession must keep the pre-work intent separate from the post-work result.

Reason: future summaries and task-progress suggestions need both planned and actual work.

### D-006: Adaptive Flow extends one session

Adaptive Flow changes the planned duration of the same FlowSession through 12, 25, and 50 minutes.

Reason: splitting extensions into multiple sessions would distort history and statistics.

### D-007: DailyCompletion is an event

The first transition into a complete day records one DailyCompletion event.

Reason: this prevents repeated reward triggers when opening an already completed day.

### D-008: Japanese is the default UI language

Use Japanese for user-facing text by default. Keep Swift identifiers, stable enum raw values, and technical documentation in English unless an artifact is directly shown in the app.

Reason: the product should start with a clear default locale while preserving maintainable code and stable persistence values.

### D-009: Todo belongs to Direction, but storage relationship is optional

Todo creation may start without an explicit Direction. In that case the app creates or reuses a neutral default Direction named `タスク`. The SwiftData relationship is optional at the storage level.

Reason: quick task capture must stay low-friction while preserving a Direction relationship for later organization, statistics, and CloudKit schema evolution.

### D-010: Today uses bottom quick capture

The Today screen creates Todos from a bottom composer-style input. The top area is a free text description field. The lower toolbar keeps quick controls visible: Direction as full emoji plus name, date, and Flow amount.

Reason: Today capture should be fast and visually quiet while still making Direction, schedule, and Flow size understandable before submit.

Task rows use the selected Direction color in Today. Tasks captured without a selected Direction route to the automatic `タスク` Direction but render without a Direction color.

Manual Today tasks carry a priority and a record type. Priority is `高`, `中`, or `低い`; when `低い` is selected the user may mark it as `余裕があれば`. Record type reuses `TodoMeasurement`: `チェック`, `ブロック`, and `分`.

Reason: Direction answers "where does this belong?", while priority and record type answer "how should Today treat this specific task?"

### D-011: Direction icons use local Unicode emoji

Direction icons are Unicode emoji strings. The picker stores recent emoji locally, keeps the latest 20 values, and removes duplicates. Manual emoji input is normalized to the first valid `Character`; plain text is rejected and falls back to the default `🎯`.

Reason: using Unicode keeps the model simple and supports ZWJ and skin tone emoji without image assets or third-party emoji libraries.

### D-012: Block is derived from focused duration

Canonical productivity unit:

- `1 Block = 25 focused minutes`.
- Breaks are excluded.
- 12 focused minutes are presented as `0.5 Block`.

Blocks are not stored as standalone durable entities. `FlowSession` records actual focus work, while Todo and Direction progress accumulate focused seconds and display that duration in Blocks.

Reason: one completed FlowSession can be 12, 25, 50, or another duration. Treating every session as one Block would distort progress and history.

### D-013: Flow is controlled from a bottom mini-player

The primary Flow control surface lives at the bottom of the app shell, similar to a compact media player. It is available across the main Today and Direction screens and avoids a heavy form-first start flow.

Reason: Flow is the app's main action and should be startable with minimal navigation.

### D-014: Tests use isolated SwiftData storage

When the app process runs under XCTest or receives `--uitesting`, the SwiftData container uses in-memory storage.

Reason: tests should not read or mutate the user's local app store, and stale development data can contain invalid relationships while the schema is evolving.

### D-015: Live Activity is behind a service boundary before adding a Widget Extension

`LiveActivityService` defines the lifecycle boundary for future ActivityKit integration. The current slice does not create the Widget Extension target.

Reason: adding ActivityKit UI requires target/capability/signing project changes. Those must be done deliberately in Xcode or in a separate target-management slice without changing Bundle ID, Signing Team, or CloudKit configuration by accident.

### D-016: Statistics is derived from FlowSession history

The Statistics tab has two modes: `Flow` and `Achievement`. Flow mode reads existing `FlowSession` records and groups focused seconds by local calendar day. Achievement mode reads currently completed `Todo` records and groups them by their latest update day. Neither mode introduces a separate daily aggregate model in MVP.

When several Directions appear on the same day, the cell color is a weighted mix of Direction colors. Flow mode weights by focused duration; Achievement mode weights each completed Todo equally.

Reason: derived statistics avoid duplicated persistence while the Flow history model is still evolving.

## Current Risks

- The project deployment targets are set to OS version 26.5, which may restrict local simulator/device availability.
- CloudKit entitlement exists but no iCloud container identifier is configured.
- The app target currently includes visionOS platforms, although the product scope is iPhone, iPad, and macOS first.
- Todo capture is still a narrow vertical slice; Today completion and History are still pending.
- Flow mini-player is implemented, but ActivityKit Widget Extension and Dynamic Island UI are not yet added.
- CoreSimulator was unavailable from the current sandbox during `xcodebuild -list`; full build/test verification may need Xcode or an approved command environment.

## Open Questions

- Should visionOS remain in supported platforms for now, or be removed until there is a product plan?
- What default Direction symbols and colors should seed an empty install, if any?
- Should archive or soft delete be the default for Todos in MVP 0.1?
- How strict should Today be for weekly Must goals before a user-facing strict planning mode exists?
