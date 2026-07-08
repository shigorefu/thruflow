# Decisions

## Accepted

### D-001: Local-first SwiftData MVP

Use SwiftData locally for MVP 0.1. CloudKit is planned but must not be required for launch or local testing.

Reason: the core product loop must be reliable before sync complexity is introduced.

### D-002: Direction is the central object

Direction represents a recurring area of attention and owns the meaning that habit categories, activity areas, and life domains would otherwise split across multiple concepts.

Reason: this keeps Today, Todos, Flow, and future statistics connected to a stable domain object.

### D-003: Must, Neutral, and Bonus are explicit types

Use stable enum raw values for Direction type:

- `must`
- `neutral`
- `bonus`

Reason: successful-day logic depends on the difference between required work, optional work, and positive optional activity.

### D-004: Weekly goals are not failed by empty days

Weekly goals are judged by week totals. Individual empty days are factual empty days, not failed habit days.

Reason: this matches goals such as training 3 times per week and avoids punishing flexible schedules.

### D-004a: Required Direction goal schedule is explicit

Only `必須` Directions ask for a goal. The creation flow records a goal value, a unit, and one frequency mode: `毎日`, `週回`, or `曜日`. `通常` and `ボーナス` Directions stop after type selection and do not carry goal fields.

Reason: goal setup should stay clear at creation time and avoid showing irrelevant controls for non-required Directions.

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

The Today screen creates checkbox Todos from a bottom messenger-style input. The Direction picker appears only while the user is typing or focusing the field. Detailed measurement setup belongs to a later edit flow.

Reason: Today capture should be fast and visually quiet, with Direction available only when it helps the current entry.

Task rows use the selected Direction color in Today. Tasks captured without a selected Direction route to the automatic `タスク` Direction but render without a Direction color.

### D-011: Direction icons use local Unicode emoji

Direction icons are Unicode emoji strings. The picker stores recent emoji locally, keeps the latest 20 values, and removes duplicates. Manual emoji input is normalized to the first valid `Character`; plain text is rejected and falls back to the default `🎯`.

Reason: using Unicode keeps the model simple and supports ZWJ and skin tone emoji without image assets or third-party emoji libraries.

## Current Risks

- The project deployment targets are set to OS version 26.5, which may restrict local simulator/device availability.
- CloudKit entitlement exists but no iCloud container identifier is configured.
- The app target currently includes visionOS platforms, although the product scope is iPhone, iPad, and macOS first.
- Todo capture is still a narrow vertical slice; Flow, Today completion, and History are still pending.
- CoreSimulator was unavailable from the current sandbox during `xcodebuild -list`; full build/test verification may need Xcode or an approved command environment.

## Open Questions

- Should visionOS remain in supported platforms for now, or be removed until there is a product plan?
- What default Direction symbols and colors should seed an empty install, if any?
- Should archive or soft delete be the default for Todos in MVP 0.1?
- How strict should Today be for weekly Must goals before a user-facing strict planning mode exists?
