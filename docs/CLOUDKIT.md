# CloudKit

## Configuration

- Apple Developer Team: `BR727PS795`.
- macOS and iOS bundle identifier: `com.shigorefu.thruflow`.
- Test bundle identifiers use the lowercase suffixes `.tests` and `.uitests`.
- Shared container: `iCloud.com.shigorefu.thruflow`.
- Service: CloudKit private database. There is no public/shared database product
  behavior in version 1.x.
- iOS minimum deployment target: 17.0. Builds use Xcode 26 and the installed iOS
  26 SDK without making iOS 26 the deployment target.
- macOS minimum deployment target: 14.0; watchOS minimum deployment target: 10.0.

Both app targets contain the CloudKit entitlement. `AppModelContainerFactory`
uses the same SwiftData schema and private container on normal signed runs.
macOS additionally verifies the entitlement on the running process before
opening the CloudKit-backed store. iOS device builds rely on the signed target
entitlement; the simulator is rejected earlier by the platform check and stays
local-only.

Development and Production use separate persistent store files so Core Data's
CloudKit export metadata cannot leak between environments. Debug builds use
`default-development.store`; Release, TestFlight, and App Store builds retain
the existing `default.store`. The Production filename must not change because
it owns shipped user data. A new Debug store repopulates from Development
CloudKit on its first signed run. Widgets continue using App Group snapshots
and never open either SwiftData store.

## Persistence Naming Compatibility

Version 1.2.0 renames application symbols and files to `Area`, but does not
rename the stored model. The `@Model` runtime class remains `Direction`, and
the Todo, FlowSession, and FlowSegment relationship fields remain `direction`.
CloudKit therefore continues using the existing entity and fields; no schema
migration, duplicate Area entity, or record copy is introduced. A schema
contract test guards these exact names.

## Connector Link Migration — Released in 1.3.0

Connectors add only `Todo.externalTaskLinkRawValue`, a nullable String scalar
with a `nil` default. Existing Todos stay unlinked and require no backfill.
The five entity names and all relationship names remain unchanged. The JSON
contains provider/account/task/source identity, original URL, last import time,
and an optional duplicate-repair marker; never access or refresh tokens.

Credential storage and list-to-Area configuration are device-local. Only
imported Tasks and their non-secret link metadata follow private CloudKit.
Concurrent imports converge through `ConnectorTaskImporter` during normal
persistence repair, reconnecting FlowSession/FlowSegment history to the
canonical Task. Genuine local deletions cannot be resurrected by later imports.

Before distributing a connector build, run a migration against a backed-up copy
of an existing store, initialize and inspect the new field in Development, then
deploy that additive field to Production. Verify real signed Mac/iPhone imports,
source moves, concurrent imports, and late-arriving Flow records. In-memory
schema and reconciliation tests do not validate production deployment or actual
CloudKit delivery. Native OAuth signing has additional Associated Domains gates
in [Connectors](CONNECTORS.md).

## Local And Test Modes

- Unit/UI tests use an in-memory `ModelConfiguration` with CloudKit disabled.
- iOS Simulator uses a persistent local SwiftData store with CloudKit disabled
  because simulator builds do not receive the iCloud container entitlement.
- Unsigned and ad-hoc macOS diagnostic builds use the persistent local store
  when the running process does not contain the configured iCloud container entitlement.
  This prevents Core Data's CloudKit setup from terminating the process while
  preserving CloudKit for normally signed application builds.
- Set `THRUFLOW_DISABLE_CLOUDKIT=1` for a persistent local-only development run.
- Pass `--local-store` for the same local-only behavior from a scheme.

These modes exist for deterministic development. They must not introduce a
second model schema or different domain behavior.

## Error And Sync Visibility

A successful local SwiftData save means the change is durable on that device;
it does not prove that CloudKit has already exported it. SwiftData save and
fetch failures are handled explicitly and logged by `PersistenceIssueCenter`.
User-initiated failures roll back pending changes and show a recoverable alert.
CloudKit account status and persistent-container import/export events drive the
read-only iCloud status in Settings. A failed CloudKit event is shown as a sync
problem without blocking subsequent local work or changing the local-first data
model.

## System Area Convergence

The built-in `その他` Area is identified by the stable optional
`systemRoleRawValue = taskInbox`, not by its localized name. The optional field
keeps existing SwiftData stores lightweight-migration compatible.

Two devices can create the built-in Area while offline before either sees
the other's record. After CloudKit imports both records,
`DefaultAreaReconciler` deterministically keeps the oldest record (UUID is
the tie-breaker), reconnects Todo and Flow relationships, and soft-archives the
duplicates. The reconciliation uses the existing active persistence polling
cycle; it does not add another timer or require CloudKit for local-only runs.

The new optional field must be present in the Development schema and deployed
to Production with the rest of the SwiftData schema before release.

## Development Verification

1. Sign in to an Apple ID with iCloud Drive enabled on the Mac and iPhone.
2. In Xcode, select team `BR727PS795` for both application targets.
3. Connect the iPhone once and trust the Mac so Xcode can register the device
   and create the `com.shigorefu.thruflow` development profile.
4. Run both signed apps. The development schema is materialized from the
   SwiftData model when the CloudKit-backed store starts.
5. Create or edit an Area/Task/Flow on one device and verify it arrives on
   the other after both apps have had network time to process CloudKit changes.
6. Start Flow on one device while the other application is active. Verify that
   Task, Area, mode, phase, pause state, and remaining time are adopted
   without restarting the timer. Repeat the command in the opposite direction.

Simulator builds cannot validate CloudKit synchronization because Xcode strips
the iCloud container entitlement for the simulator SDK. Use signed macOS and
physical iPhone builds for synchronization diagnostics.

## Active Flow Runtime

The active timer is synchronized through the current `FlowSession`. Absolute
timestamps, pause/break anchors, and a runtime revision allow another client to
reconstruct the timer without transferring per-second ticks. macOS, iOS, and
watchOS reconcile on launch, foreground entry, and while active. Once the
synchronization lifecycle has started, a completed CloudKit import also invokes
the same reconciliation path even after foreground polling stops. This allows a
remote stop or phase change to cancel the receiving device's obsolete local
completion and forgotten-timer notifications. The same timer reconciliation
mechanism works in local-only mode.

CloudKit does not provide a guaranteed real-time wakeup channel for a suspended
application. If the iPhone app is suspended when Flow starts on macOS, the
session is adopted the next time iOS receives and processes the CloudKit change,
typically when the app becomes active. Guaranteed background creation or
updating of Dynamic Island requires ActivityKit push tokens and an APNs
provider. That server-assisted transport is not part of the current private
CloudKit implementation and remains deferred. D-042 allows upcoming local
connectors independently of APNs; they do not change timer delivery. In 1.x,
a suspended iPhone Live Activity may remain at `00:00` until the application
next launches or becomes active; the canonical Flow still
advances from its absolute timestamps. The same delivery limitation applies to
notification cancellation when a device is offline or the user has force-quit
the app; the next received import or foreground reconciliation removes the
obsolete requests.

## Production Schema

Before distributing a build, open CloudKit Console for
`iCloud.com.shigorefu.thruflow`, inspect the Development schema and indexes, then
deploy that schema to Production. Do not deploy schema changes casually:
production CloudKit schema changes are forward-only and must remain compatible
with existing app versions and local SwiftData stores.

## Provisioning Requirements

Signed CloudKit verification requires registered physical devices and matching
development profiles for every tested target. TestFlight/App Store archives
additionally require an Apple Distribution certificate and current App Store
provisioning profiles for the app and each embedded extension. These signing
assets stay outside the repository and must be checked in Xcode and App Store
Connect as part of every release gate.

Toggl Track export adds the optional String `FlowSession.recordingDeviceID`.
Before releasing it, deploy that additive field through the normal Development
and Production schema gates. Legacy nil values are retained; do not backfill
ownership. Tokens and the export outbox are device-local. Two-device verification
must confirm that only the Flow's originating device exports its completed record.

### 1.3.1 Habit occurrence field

The optional `Todo.habitOccurrence` Boolean is represented in CloudKit as
`CD_Todo.CD_habitOccurrence` (`INT64`). It was added in Development and deployed
to Production on 2026-09-20; the Production field was verified after reloading
CloudKit Console. Missing values
retain legacy classification. Older clients do not understand independent Tasks
in Habit Areas and can still merge them: use updated clients on all devices for
this workflow. Local tests do not validate Production schema deployment.

### Production schema repair — 2026-09-18

CloudKit Console confirmed deployment of two missing String fields to Production:
`CD_FlowSession.CD_recordingDeviceID` and `CD_Todo.CD_externalTaskLinkRawValue`.
Both were missing from Development as well and were added there first. The reviewed
deployment changed two record types, with no index or security-role changes.
The missing recording-device field had caused CKError 12/2006 and rejected a batch
of 80 records from the installed 1.3.0 (11) macOS app. No records were deleted or reset.
This deployment does not include the 1.3.1 `habitOccurrence` field described above.

### Production schema repair — 2026-09-20

The installed Mac app was 1.3.0 (11), signed for Production; the maintainer
reported iPhone 1.3.1. Production logs showed an iPhone private-database
`RecordSave` rejected with `BAD_REQUEST` at 04:10:43 UTC, while a Mac export
completed at 04:10:02 UTC. The server entry did not expose a field-level cause.
Inspection confirmed `CD_Todo.CD_habitOccurrence` was absent from both schemas.
Added the optional field as `INT64` in Development and deployed it to Production.
The reviewed deployment changed one field on one record type, with no index
or security-role changes. A fresh Production page showed 27 CD_Todo fields,
including `CD_habitOccurrence`. No user records or stores were deleted/reset.

After the deployment, the maintainer confirmed on 2026-09-20 that cross-device
synchronization worked again. This is user-confirmed recovery, not an automated
record-by-record comparison. Existing 1.3.0 clients still lack the independent-Task/
Habit classification rules added in 1.3.1; use updated clients on both devices.


### 1.4.0 (13) release preparation — 2026-10-16

The initial live Production inspection was blocked: `cktool`
reported no management token, and CloudKit Console opened the Apple Account
sign-in screen. No schema deployment or user-data mutation was performed.
This initial result is superseded by the authenticated inspection below; prior
1.3.1 evidence alone was not treated as a current schema check.


### Projects and Area restoration — 2026-10-16

After the maintainer authenticated, both live environments of
`iCloud.com.shigorefu.thruflow` (team `BR727PS795`) were inspected in CloudKit
Console. Their exported schemas contained the same five application record
types and lacked three fields already used by the app, as well as Projects.
The full Development schema was imported with additive changes only:

| Record type | Added fields | CloudKit types |
| --- | --- | --- |
| `CD_Direction` | `CD_weekdayMask` | `INT64` |
| `CD_Todo` | `CD_archivedAt`, `CD_deadline` | `TIMESTAMP` (Date/Time in Console) |
| `CD_Todo` | `CD_project` | `STRING` |
| `CD_Project` | `CD_id`, `CD_name`, `CD_notes`, `CD_direction`, `CD_entityName` | `STRING` |
| `CD_Project` | `CD_createdAt`, `CD_updatedAt`, `CD_completedAt` | `TIMESTAMP` |

The relationships use the same Core Data CloudKit String representation as
existing to-one links; inverse collections are not added as array fields.
New scalar fields have Queryable/Sortable indexes; String fields also have
Searchable indexes, matching the existing generated schema convention.
The reviewed deployment diff showed 2 new indexes on Direction, 7 on Todo and
21 on Project. It removed or altered no existing fields, indexes or permissions.
The new record type follows the existing record-type grants; app records remain
in the user's private database. No user records or stores were modified/reset.

Console first reported a successful Development import, then **Changes Deployed:
The schema is deployed to Production**. After switching to Production and
reloading, the record list showed `CD_Project` (14 fields including metadata),
`CD_Direction` (25) and `CD_Todo` (30). The fields and their indexes above were
read back on the live Production detail pages. The additive Development revision
was `b1314881-c95b-11f1-a6b6-bfa6b1f81655`.

This verifies the deployed schema, not physical-device synchronization. A signed
Mac/iPhone exchange creating, editing and completing a Project and assigning a
Task still needs to run before distribution. Local migration was verified against
a disk store with the pre-Project schema, preserving identities, progress and
Flow history; the full 499-test suite passed.


### Task times and reminders — 2026-10-18

After the maintainer renewed the CloudKit Console session, both live schemas for
`iCloud.com.shigorefu.thruflow` (team `BR727PS795`) were inspected. Their schema
exports matched before this change, with six application record types and
`CD_Todo` containing 30 fields including metadata. Both lacked the new timing
fields. Added these fields in Development using the record-type editor:

| Record type | Added field | CloudKit type | Indexes |
| --- | --- | --- | --- |
| `CD_Todo` | `CD_scheduledTimeMinutes` | `INT64` | Queryable, Sortable |
| `CD_Todo` | `CD_reminderEnabled` | `INT64` | Queryable, Sortable |
| `CD_Todo` | `CD_scheduledTimeUpdatedAt` | `TIMESTAMP` | Queryable, Sortable |

The exact deployment diff contained only these three additive field lines,
each with both indexes. Existing fields, record types and security grants were
unchanged. The Development revision reviewed was
`72af16b0-cab3-11f1-bd59-17680b734955`. Console confirmed **Changes Deployed**.
After switching to Production and reloading, `CD_Todo` showed 33 fields; all
three names, types and Queryable/Sortable indexes were read back on its live
field page. No user records or local stores were modified or reset.

Legacy records retain no time and reminders off. Permission remains device-local;
only the time, reminder preference and timing revision synchronize. Completion,
archival or time changes update local notification requests after a save/import
is processed; an offline or force-quit device may retain an obsolete request
until its next reconciliation. Actual signed Mac/iPhone exchange and notification
delivery remain unverified and are required before distribution. Full local
validation passed 521 tests, including disk migration and timing reconciliation;
see [Release](RELEASE.md) for platform evidence and remaining gates.


### Project Habits and stable ownership — 2026-10-23

After the maintainer renewed the Console session, live Development and Production
for `iCloud.com.shigorefu.thruflow` (team `BR727PS795`) were compared. Both lacked
the two new optional scalar fields. Added these fields in Development:

| Record type | Added field | CloudKit type | Indexes |
| --- | --- | --- | --- |
| `CD_Project` | `CD_habitSettingsRawValue` | `STRING` | None |
| `CD_Todo` | `CD_habitOwnerKeyRawValue` | `STRING` | None |

No server predicate or sort uses these fields; reconciliation resolves ownership
locally. Existing indexes, types and security grants were preserved. The reviewed
Development revision was `51ee2b30-ce98-11f1-8d2d-dfc7f3b9cc0b`; the deployment
diff contained only these two additive fields. Console confirmed **Changes
Deployed**. After switching to Production and reloading, its record list showed
15 Project fields and 34 Todo fields, including metadata. Both new names and
STRING types were read back on their live field pages. No user records or stores
were reset. Screenshot evidence was saved locally during the task.

Old Projects default to no Habit; legacy Todos infer ownership from relationships.
New generated Todos carry a stable owner key, so incomplete relationship imports
cannot merge unrelated Area/Project occurrences. The full local suite passed 550
tests, including disk migration and both relationship arrival orders. Actual
signed Mac/iPhone exchange of Project settings and generated occurrences remains
unverified and must be checked before distribution.
