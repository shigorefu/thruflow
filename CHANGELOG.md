# Changelog

All notable user-facing changes to ThruFlow are documented in this file.
Release dates below record GitHub publication in Asia/Tokyo (JST).

## [1.3.1] - Unreleased

App, extensions, Watch, and test targets use version **1.3.1**, build **12**.

### Added

- Per-Area source mappings for Reminders and Todoist, with existing imported
  Tasks retaining their local Area and history.
- Mac Flow Task context menus and navigation from Task/Habit headings.
- A localized API-token/Keychain explanation before opening Toggl setup.

### Changed

- Flow distribution bars stack cumulatively from right to left.
- Beta badges appear on each connector, rather than the main navigation entry.
- Manually extended focus sessions over one hour skip the one-hour reminder.

### Fixed

- Missing active Toggl projects and unexpected startup Keychain prompts.
- Duplicate Habit reconciliation and manual Tasks incorrectly treated as Habits.
- iPhone bottom-control backgrounds and Mac History header bounds.
- Localization gaps and SDK 27 compatibility issues.
- Missing Production CloudKit Habit occurrence field; cross-device recovery
  confirmed by the maintainer after deployment on 2026-09-20.

See [release notes](docs/releases/1.3.1.md) for details and connector limitations.

## [1.3.0] - 2026-09-15

App, extensions, Watch, and test targets use version **1.3.0**, build **11**.

### Added

- Statistics Month trends show every day, with an explicit moving-average line,
  date details on hover/tap, and future dates kept on the axis without plotted zeros.

- Toggl Track exports new completed focus segments from their recording device,
  with Keychain token storage, Area/project mapping, an offline outbox, and
  explicit recovery for uncertain deliveries on macOS and iOS.

- Apple Reminders and Todoist Check tasks synchronize completion and reopening
  both ways, with a persistent offline outbox and pending-state indication.
- Todoist requests read/write authorization; existing read-only connections
  need to reconnect before sending completion changes.

- Task creation suggestions float above the composer on macOS and iPhone,
  including quick-input options and existing tags. Empty @ suggests five Areas
  ordered by recent Task creation, with alphabetical fallback.

- Statistics distribution selections show daily minute bars for Tasks and
  Task/time bars for Areas on macOS and iOS. Select a sector or legend row.

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

- Dots opens a daily summary before History on both platforms, including Year.
- Quick-input priority, date, and measurement suggestions use shared icons and
  filtering. Flow quick creation now offers a date control on macOS and saves
  the selected date, including changes made through quick input.

- Menu Bar task suggestions open below the composer. Quick input no longer
  offers or opens Area creation on macOS or iOS.

- Area type explanations appear once beneath group headings on macOS and iOS;
  macOS cards no longer repeat the type name or generic description.

- macOS Area group headings use the same checklist, repeat, and sparkles icons
  as Flow. Japanese copy consistently uses フロー in place of the former term.

- Custom Statistics Dots ranges use a compact chronological grid of actual
  selected days, without weekday labels, calendar padding, or a legend.
  Preset Week, Month, and Year calendars keep their existing layouts.

### Fixed

- iPhone task suggestions sit entirely above the input instead of overlapping
  it. Area type headings and descriptions occupy a separate header above the list.

- macOS Statistics keeps its four report cards mounted during scrolling and
  gives native segmented controls explicit widths to avoid repeated recreation
  and intrinsic-size negotiation.

- Editing a recorded segment’s Area during an active or paused Flow no longer
  replaces the timer deadline with that segment’s end or produces false overtime.

- Completing Tasks no longer rebuilds the unrelated Flow Dots widget. Widget
  updates coalesce rapid edits after the immediate UI response. On macOS task
  boards, double-click editing is restricted to the text, outside the checkbox.

- macOS Statistics card switches now align to the same trailing inset instead
  of centering inside differently sized invisible frames.

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

[1.3.1]: https://github.com/shigorefu/thruflow/compare/v1.3.0...main
[1.3.0]: https://github.com/shigorefu/thruflow/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/shigorefu/thruflow/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/shigorefu/thruflow/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/shigorefu/thruflow/releases/tag/v1.0.0
