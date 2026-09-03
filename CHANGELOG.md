# Changelog

All notable user-facing changes to ThruFlow are documented in this file.

## [1.2.0] - Unreleased

### Changed

- Renamed source files, application/domain APIs, views, widgets, tests, and
  developer documentation from Direction to Area.
- The Flow timer now uses the rest color for both its resume control and ring
  while paused, and keeps the selected Area color while focus overtime counts
  upward on macOS, iPhone, and Apple Watch.
- The minimal Dynamic Island timer now counts remaining time down and drains
  its circular progress when another Live Activity shares the Island.
- Renamed the machine-readable Statistics CSV column from `direction` to
  `area`.
- Markdown-only pull requests and pushes now skip Apple builds while retaining
  the required CI status. Any non-Markdown change still runs macOS tests and
  macOS/iOS Release builds.

### Compatibility

- Preserved the existing SwiftData/CloudKit entity name `Direction`, the
  stored Todo/Flow relationship name `direction`, stable enum raw values, and
  legacy preference and Widget/Live Activity wire keys. Existing local and
  synchronized data requires no migration.
- Added a schema contract test that rejects an accidental persisted `Area`
  entity or `area` relationship.
- Separated Debug and Production SwiftData files so Development CloudKit
  metadata cannot cause History records to be skipped during a Production
  export. Production continues using the existing `default.store`; no shipped
  data is moved.

## [1.1.0] - Unreleased

### Added

- Added Task-title suggestions based on previously used titles when creating a
  Task on macOS, iPhone, and iPad.
- Added the same title-only suggestions when renaming the current Task in the
  macOS Flow timer. Suggestions open below the field without changing the
  timer layout height.
- Added a compact seven-position slider for the `Times per Week` Habit
  frequency on macOS and iPhone. The selected value appears inside the slider
  thumb and remains adjustable with VoiceOver.

### Changed

- Task-title suggestions copy only text. They never reuse completion, progress,
  Area, measurement, date, or the identity of a historical Todo.
- The compact iPhone Flow Statistics card now changes pages with a horizontal
  swipe, keeps page dots visible, and no longer shows arrow buttons.
- Statistics Dots now keeps the complete selected Week, Month, or Year visible.
  Future cells remain empty and disabled, while Elastic continues to represent
  only the selected date.
- Area editors now show types in the fixed order
  `Anytime | Habit | Optional` on macOS and iPhone.
- Editing an existing Habit Area now rebuilds its unstarted Tasks from the
  current app day forward to match the new schedule, frequency, unit, and
  target. Completed, progressed, and Flow-linked Tasks remain unchanged.
- The macOS Area editor now uses a content-fitted window width.

### Fixed

- Fixed the Flow player retaining a Task occurrence from the previous day.
  When the app day changes while the timer is idle, selection moves to an
  incomplete Task from the current day, preferring the same Area. If no current
  Task exists, only the Area remains selected. A running Flow is not changed.
- Fixed the compact iPhone Flow Task composer appearing transparent after
  pressing `+`.
- Fixed editing one Habit Task occurrence in History also changing a different
  occurrence from another day.
- Fixed History Area summaries collapsing a whole period's focused time into a
  single misleading Task row. Focused time is now distributed across the exact
  Todo occurrences that recorded it.
- Fixed Statistics opening the previous month after selecting a numbered month
  on macOS or iOS.
- Fixed a separate black strip appearing below iPhone History content.
