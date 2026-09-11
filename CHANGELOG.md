# Changelog

All notable user-facing changes to ThruFlow are documented in this file.
Release dates below record GitHub publication in Asia/Tokyo (JST).

## [1.3.0] - Unreleased

### Added

- Flow palette changes sweep softly from right to left over 2.4 seconds; rapid
  changes queue the latest palette. Reduced Motion uses an immediate update.

- The macOS Flow stream blurs while its window is inactive and smoothly clears
  when the window becomes active and rendering resumes.

- Debug-only Demo schemes for macOS and iOS provide an isolated sample workspace
  with three Areas, 21 historical Flows, and 24 Tasks for manual testing.

- Statistics and CSV export support selecting multiple Areas on macOS and
  iOS/iPadOS. Clear the selection with All to include every Area.

- Settings now lets you hide the planned end on the Flow timeline and show
  only elapsed time on macOS and iOS/iPadOS. The existing planned-end view
  remains enabled by default; the preference is saved on each device.

### Changed

- Custom Statistics Dots ranges use a compact chronological grid of actual
  selected days, without weekday labels, calendar padding, or a legend.
  Preset Week, Month, and Year calendars keep their existing layouts.

### Fixed

- Resuming the Flow stream explicitly resets its animation time baseline,
  preventing a catch-up jump when no paused frame was rendered.

- Custom Statistics ranges and CSV exports preserve selected calendar dates
  with a non-midnight day start, including repeated period navigation.
- Statistics reloads when calendar or day-start settings change and no longer
  reuses projections grouped with the previous settings.

- Selecting a Statistics month now keeps Dots in that month when the Flow day
  starts after midnight. Week and year selections also retain their boundaries.

- Removed the separate bar-material background behind the iOS/iPadOS Tasks,
  History, and Areas top controls.

- iOS/iPadOS Area rows now show only the icon and name, removing repeated
  type explanations and goal subtitles from the list.

- The minimal Dynamic Island focus ring now fills like the in-app timer, while
  its numeric label keeps counting down. Rest still drains.

- Rest on the Flow timeline now shows only elapsed time. The planned-end
  setting applies only to focus blocks on macOS and iOS/iPadOS.

- Custom Statistics ranges no longer draw empty Dots cells outside the selected
  dates on macOS and iOS/iPadOS. Preset calendar grids remain complete.

- Weekly habits measured in minutes or Blocks reconcile recorded progress
  before automatic rescheduling, so a completed occurrence with stale progress
  is not moved into today. The next occurrence starts with zero progress.
- macOS task move menus now enforce the same completion and weekly schedule
  checks as drag and drop.

- The Flow timeline refreshes immediately when starting, pausing, or resuming
  playback on macOS and iOS. Time labels animate with the rail instead of
  jumping ahead of delayed dashboard updates.

## [1.2.0] - 2026-09-08

### Changed

- Renamed source files, application/domain APIs, views, widgets, tests, and
  developer documentation from Direction to Area.
- The Flow timer now uses the rest color for both its resume control and ring
  while paused, and keeps the selected Area color while focus overtime counts
  upward on macOS, iPhone, and Apple Watch.
- The minimal Dynamic Island timer now counts remaining time down and drains
  its circular progress when another Live Activity shares the Island.
- The `−5` and `+5` timer controls now adjust rest as well as focus on macOS,
  iPhone, Apple Watch, and expanded Dynamic Island. Subtraction keeps one minute
  remaining, and adjusted long rests retain their long-rest behavior.
- Timer rings and the active Elastic timeline now animate when seeking or
  changing focus mode; the timeline distinguishes recorded time from the
  translucent remaining plan.
- The iPhone Task composer now keeps recognized quick-input values as the same
  removable semantic chips used by the macOS composer.
- The iPhone Task editor now shows title-history suggestions in a separate row
  above the edit form; choosing one changes only the current Task title.
- Month Dots now cross out non-interactive boundary cells from adjacent months
  instead of presenting them like empty days in the selected month.
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

## [1.1.0] - 2026-09-03

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

## [1.0.0] - 2026-08-26

### Added

- First stable release for macOS, iPhone, and iPad, with an Apple Watch companion.
- Task and Area management, focus timers, Flow/rest history, and statistics.
- Private iCloud synchronization, widgets, Live Activity, and Dynamic Island.
- Japanese, English, and Russian localizations.

### Fixed

- Improved History timeline editing and natural localized copy before release.

[1.2.0]: https://github.com/shigorefu/thruflow/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/shigorefu/thruflow/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/shigorefu/thruflow/releases/tag/v1.0.0
