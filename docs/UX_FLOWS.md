# UX flows

This document describes the current presentation. Business rules belong in
[Domain model](DOMAIN_MODEL.md); persistence contracts in [Data model](DATA_MODEL.md).

## Areas and Projects

Areas are grouped as Anytime, Habit and Optional. Mac and expanded iPad/Duo show
three columns; compact layouts use a type picker. Group descriptions appear once
in the header. Archived Areas can be restored from archive management.

Projects appear as indented colored children connected to the Area emoji. There
is no folder icon or plus button on each Area row. Create Projects in the saved
Area editor; Areas without Projects retain the simple layout. The Project editor
follows the Area editor design and optionally configures one Habit. It does not
create ordinary Tasks or expose the old Project memo field.

On Mac, Save validates the current Habit goal text, including an active edit.
Invalid goal text keeps the editor open with the goal validation message.

## Tasks and quick capture

Create ordinary Tasks in Tasks or Flow. Expanded Tasks has a persistent input
panel; compact iPhone/folded Duo retains the plus button. Panels have an opaque
system background and preserve drafts across layout changes without forcing focus.

Suggestions float above the mobile composer. Mac menu-bar capture places them
below the field; owned forms close with the host window. Title suggestions copy
text only, never another Task's identity or progress. Quick syntax can select an
Area, priority, date, duration or clock time; time hints use `9:00`. The time
control is a dropdown containing the clock and reminder preference. See the
parser and its tests for supported aliases; English aliases work in every locale.

Hide the Project picker when the Area has no eligible Projects and there is no
existing selection to clear. Changing Area clears an incompatible Project.
Unnamed Tasks display their Project name when assigned, otherwise the Area
placeholder. Flow rows have three lines: title, colored Area or Area/Project context,
then available Task attributes separated by `・`. Omit the third line when
there are no attributes. Checkbox Tasks have no redundant
Completed/Incomplete subtitle; numeric progress remains visible.

Task rows show the Area name or Area/Project context alongside the Area emoji.
Tasks offers day, week and month views, overdue work and an undated inspector.
Search covers the Task database rather than just the selected date. Compact
period strips use native snapping; dragging does not mutate dates until the
selection settles. Task moves still obey Habit scheduling rules.

On Mac, the Task editor places classification and scheduling above the notes and
tags. The sheet keeps Save and Cancel accessible while its content scrolls.

## Flow player

On wide Mac windows, the Flow dashboard aligns Tasks, Habits, and Statistics
in one row. On narrow windows, the timer and stream stack with a fixed gap and
the dashboard scrolls vertically. In Mac Areas, three columns share the height
of the tallest column; horizontal scrolling preserves all three at narrow widths.

The dashboard combines the stream, today's timeline, Tasks, the player and a
compact Statistics carousel. Mac Task context menus show Start Focus first,
then Edit and Move when available, with Delete in its own final group. Task and
Habit headings navigate to their corresponding Tasks groups. On mobile, the
player places its dial beside the controls, including expanded Duo.

Selecting an Area explicitly creates an unnamed Task for today. Selecting a Task
with a Project shows Area/Project context. Earlier focus ring colors remain when
context changes; pauses add no colored time. The planned-end setting applies to
focus only; rest displays elapsed time on the dashboard timeline.

Finishing focus and starting rest open a form with Task name, eligible Project
and result memo. Typing in Task name suggests up to three matching titles from
local Task history. Selecting one fills the title draft without submitting the
memo or switching the timer. Watch shows matches after system text entry.
Switching Tasks opens the same form only after at least 60
focused seconds in the current segment. Switching waits for submission; the current
Task keeps receiving elapsed time while the form is open. The new Task begins
receiving time only after the switch. See [Decisions](DECISIONS.md) for the
accepted memo-before-switch contract. A shorter segment switches immediately
without a form, transferring its focused time to the selected Task. Pauses do
not count toward this threshold.

Focus does not automatically stop or start rest. Five-minute adjustments preserve
elapsed time and at least one remaining minute. The rest ring is neutral and
drains; the focus ring fills. Stream motion pauses when inactive and respects
Reduce Motion; rendering never controls timer or persistence state.

## History

History contains focus records, Task summaries and Area summaries. Calendar
items represent actual sessions and breaks. Selecting a timeline item opens its
detail; editing completed history recalculates progress through shared commands.
Habit occurrences keep their individual dates and identities. A series can be
shown as a connected rail without merging its stored records.

## Statistics

Week, month and year presets show their calendar grids; custom ranges show only
chronological cells for the selected range, without weekday labels or padding.
Future cells cannot be selected. Month trends use daily points; year trends use
months. Native month names follow the selected locale.

Multiple Area selections combine with OR; search intersects that selection.
Totals, trends, distributions and calendar indicators use the same filters.
Distribution supports Tasks, Areas and Projects. Selecting a Task shows daily
minute bars; selecting an Area or Project shows Task/time bars. A day cell opens
a summary with a History action. CSV export offers its own configurable scope.
On Mac, the overview spans the report width. Below it, Habit completion sits
to the left of focused-time distribution when space permits. In narrow windows,
Habit completion appears above the distribution. Trend and Dots follow.

Habit completion shows overall and per-Habit values. Fully met goals count
immediately. Partial and zero progress count after the configured day ends.

Mac has a persistent calendar column; mobile uses native sheets and a vertical
report. Widgets retain their separate compact snapshots.

## Connectors and Settings

Provider switches pause or resume synchronization after setup.
After connection, mapping rows pair local Areas with provider lists/projects.
Toggl explains Keychain access in setup and shows failures in red below its name.
See [Connectors](CONNECTORS.md) for authentication and synchronization behavior.

Settings owns appearance, language, calendar/day-boundary preferences, timeline
presentation, support, onboarding replay and confirmed data-reset actions.
Mac theme and language controls use dropdowns. Chinese selections show an
AI-translation notice and support link. Changing language requires a restart.

## Motion

Task and Habit editors use short transitions when optional fields appear or
disappear. The Flow result form fades in on Mac and uses the system sheet on
iPhone and iPad. The Flow primary button crossfades its symbol on state changes.
The iPhone and iPad quick composer fades with a short vertical transition.
The selected destination shows its controls while loading its content.
Tasks uses a system loading indicator for the initial list and a short
top-to-bottom reveal for up to five visible rows. History reveals the selected
period's records inside its calendar. Areas reveals its groups with their
Projects. Statistics can show its overview while the rest of the report is
being prepared. Cached content appears immediately when it matches the current
selection. Loading indicators remain local to the pending content. Reveal
animations follow Reduce Motion and leave the controls interactive.
In the compact Flow Statistics card, time-allocation bars share a right-hand
zero edge and a scale based on today's total focused time.

## Onboarding and companion surfaces

Onboarding uses a horizontal sequence, with guided creation only for an empty
workspace. Example records require explicit confirmation; the timer preview is
transient and adds no history. Existing-workspace tours and Settings replay are
read-only. Steps can be skipped or closed. On macOS, the centered card fits the
current step. If the content is taller than the available space, the body
scrolls while the header and navigation remain visible.

Watch keeps a native compact player and Tasks experience backed by shared rules.
Widgets and Live Activities show app-generated snapshots and system-driven time
projections. Signed-device checks remain necessary; see [Release](RELEASE.md).
