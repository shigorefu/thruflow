# Product

ThruFlow is a free, ad-free Apple productivity app combining Tasks, Habits,
a flexible Pomodoro timer, History and Statistics. No ThruFlow account is required.

```text
Area -> optional Project -> Task -> Flow -> focused time -> progress -> statistics
```

## Organizing work

Areas represent ongoing responsibilities, such as Work or Study. Their types
are Anytime, Habit and Optional. The hidden system Area, Other, provides a
fallback for unassigned work. Archived Areas can be restored without losing
history; archival stops automatic Habit generation.

Projects are optional finite goals inside an Area, such as preparing a report.
They inherit the Area color and can be completed or reopened. A Project may own
one independent Habit. Tasks can remain directly under an Area without a Project.
Project completion does not complete ordinary Tasks or rewrite recorded work.

Tasks support checkbox, focused-minute and Focus Block goals, optional dates,
local clock times, reminders, priority and tags. Empty titles are valid: show the
Project name when assigned, otherwise the Area placeholder. New clock times
default reminders on; existing reminder choices are preserved.

Habits generate scheduled occurrences with independent identities and progress.
An incomplete earlier occurrence remains on its date; a fresh eligible day does
not inherit its progress. Statistics includes partial progress. Detailed schedule,
archive and ownership rules belong in [Domain model](DOMAIN_MODEL.md).

## Focus and reflection

Short, Standard and Deep modes start at 12, 25 and 50 focused minutes. Focus
continues beyond the planned end until the user acts. Task switches keep one
running timer and preserve earlier Area-colored segments. The task-switch form
accepts the previous Task's name, Project and result before switching; elapsed
time continues to belong to that Task until submission.

Rest is explicitly started and reflects actual focused work and recovery.
One Focus Block always means 25 focused minutes; breaks do not count. History
preserves sessions, context segments and breaks, and edits rebuild derived progress.

Statistics reports selected periods, multiple Area filters, search, Task/Area/
Project distributions, trends, a focus calendar, Habit completion and CSV export.
See [UX flows](UX_FLOWS.md) for presentation and [Domain model](DOMAIN_MODEL.md)
for calculations and date boundaries.

## Devices and integrations

- macOS, iPhone/iPad and Apple Watch share domain logic and persistence; each
  platform owns native presentation. Expanded iPad/Duo layouts adapt to available
  width, preserving drafts across size changes.
- Widgets and Live Activities project app-owned state rather than running another
  timer or opening another SwiftData store.
- Data is local first, with optional private CloudKit synchronization.
- Beta connectors import Reminders/Todoist Tasks and synchronize checkbox
  completion both ways. Toggl exports eligible completed focus time from its
  recording device. See [Connectors](CONNECTORS.md) for exact limitations.
- The interface supports Japanese, English, Russian, Simplified Chinese and
  Traditional Chinese. This does not change user-authored data or stored identifiers.

The [READMEs](../README.md) introduce the app. [Roadmap](ROADMAP.md) tracks future
scope; [Release](RELEASE.md) records delivery status. Optional future integrations
are not covered by a promise that every future feature will be free.
