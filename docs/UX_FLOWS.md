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

Tasks offers day, week and month views, overdue work and an undated inspector.
Search covers the Task database rather than just the selected date. Compact
period strips use native snapping; dragging does not mutate dates until the
selection settles. Task moves still obey Habit scheduling rules.

## Flow player

The dashboard combines the stream, today's timeline, Tasks, the player and a
compact Statistics carousel. Desktop context menus reuse Task actions; Task and
Habit headings navigate to their corresponding Tasks groups. On mobile, the
player places its dial beside the controls, including expanded Duo.

Selecting an Area explicitly creates an unnamed Task for today. Selecting a Task
with a Project shows Area/Project context. Earlier focus ring colors remain when
context changes; pauses add no colored time. The planned-end setting applies to
focus only; rest displays elapsed time on the dashboard timeline.

Finishing focus, starting rest or switching Tasks opens a form with Task name,
eligible Project and result memo. Switching waits for submission; the current
Task keeps receiving elapsed time while the form is open. The new Task begins
receiving time only after the switch. See [Decisions](DECISIONS.md) for the
accepted memo-before-switch contract.

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
Habit completion includes partial progress, with overall and per-Habit values.

Mac has a persistent calendar column; mobile uses native sheets and a vertical
report. Widgets retain their separate compact snapshots.

## Connectors and Settings

Each provider has a Beta badge; the Connectors navigation item does not.
After connection, mapping rows pair local Areas with provider lists/projects.
Toggl explains API credentials and Keychain access before opening setup.
See [Connectors](CONNECTORS.md) for authentication and synchronization behavior.

Settings owns appearance, language, calendar/day-boundary preferences, timeline
presentation, support, onboarding replay and confirmed data-reset actions.
Mac theme and language controls use dropdowns. Chinese selections show an
AI-translation notice and support link. Changing language requires a restart.

## Onboarding and companion surfaces

Onboarding uses a horizontal sequence, with guided creation only for an empty
workspace. Example records require explicit confirmation; the timer preview is
transient and adds no history. Existing-workspace tours and Settings replay are
read-only. Steps can be skipped or closed.

Watch keeps a native compact player and Tasks experience backed by shared rules.
Widgets and Live Activities show app-generated snapshots and system-driven time
projections. Signed-device checks remain necessary; see [Release](RELEASE.md).
