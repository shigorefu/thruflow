# Connectors

This document describes the upcoming 1.3.0 implementation. It does not declare
an App Store release or completion of the device and deployment checks below.
Apple Reminders and Todoist run directly from macOS, iPhone, and iPad. The
existing local SwiftData/CloudKit core remains usable without any connection.
APNs, webhooks, and an application server are outside this implementation.

## User workflow

Open `コネクタ` immediately above Settings in the macOS sidebar footer, the
iPhone Flow More menu, or the regular-width iPad sidebar footer. Choose a
service, authorize access, select one or more lists/projects, and choose an
active non-Habit Area. The default destination is `その他` when available.
Press Import to save the selection and import Tasks. Changing the destination
later applies only to newly imported Tasks.

Apple Reminders presents the system permission dialog. Todoist presents its own
login and read/write consent flow; no ThruFlow registration or provider password
entry in the app is required. Canceling leaves a previous working connection
intact. Account changes reset source/Area selections while preserving Tasks
already imported from the previous account.

The form shows the last successful update and the number of newly imported
Tasks. Manual refresh and opening the app can update configured connections;
automatic attempts are throttled and are not guaranteed background delivery.
Failures remain visible in the connector form and do not update its successful
import timestamp. Disconnect removes this device's connection and credentials
and retains imported Tasks and all Flow history. Other devices manage their
connections separately. Local disconnect does not revoke authorization in the
provider's account settings.

Imported Tasks begin in `日付なし`; schedule them locally and record Flow as
usual. Their editor explains that title and deadline refresh from the source.
Todoist Tasks include `Todoistで開く`. Reminders displays only its source label
because EventKit offers no supported public link to an individual reminder.
The Watch can use Tasks received through CloudKit; it has no connector setup UI.

## Data ownership

| Field or behavior | First import | Later refresh |
| --- | --- | --- |
| Local Todo UUID | Create a normal stable UUID | Preserve it |
| External identity | Provider + account + task ID | Preserve identity across source moves |
| Title | Copy external title | Refresh from source |
| External due date | Store in `deadline` | Refresh or clear from source |
| Local scheduled date | Leave unset | Preserve local planning |
| Memo | Copy initial source notes | Preserve local memo |
| Completion | Create unfinished Check Tasks only | Sync Check completion and reopening both ways; pending local changes win |
| Area, priority, measurement, target | Normal local Task defaults and selected Area | Preserve local choices |
| Focus, progress, Flow relationships | No invented work | Preserve recorded work |
| Remote task missing or deleted | Nothing to import | Retain the local Task |
| Repeating remote task with the same ID | One local Task | Follow provider current state; no new local occurrence |

Check completion is synchronized in both directions. Title/deadline remain
source-owned; no remote deletion, memo, planning, or Flow-history write occurs.
Measured Minute/Block Tasks retain local timer-owned completion semantics.
Missing items never imply completion or deletion. Newly discovered completed
items are not imported. Legacy links establish a remote baseline without
retroactively exporting old local completion.

### Completion delivery and conflicts

Local checkbox actions append stable UUID commands to optional link JSON fields
`completionChanges`; this outbox saves in the same transaction as the checkbox.
Acknowledgements remove only the dispatched UUID after re-reading a fresh
context, preserving newer toggles. `acknowledgedCompletionIDs` prevents stale
duplicate copies from reintroducing delivered operations. Pending local actions
win over incoming status; after acknowledgement, explicit remote status wins.
Duplicate queues merge by timestamp and UUID. Simultaneous independent device
edits still depend on CloudKit convergence; signed multi-device verification is
a release gate, not an atomic global ordering guarantee.

While the scene is active, a five-second wake checks for newly saved commands;
ordinary reads and repeated failures are throttled to 60 seconds. No background
execution or push delivery is promised. Unsaved editor changes defer sync.
Disconnect stops this device's delivery and retains pending Task commands;
reconnecting the same account resumes them. Other authorized devices can send
CloudKit-synchronized commands. A different Todoist account cannot receive them.
Deleted/archived local Tasks and unselected lists are not written.

Todoist uses Sync API `item_close` / `item_uncomplete` with the persisted command
UUID and checks `sync_status`, including errors inside HTTP 200. Retry keeps the
same UUID. Completed tasks are read explicitly from the paginated completion-date
endpoint in windows below three months; active/reopened tasks take precedence
over older completion records. Old read-only credentials require reconnecting;
refreshing them does not grant write permission. `data:read_write` is requested,
without either deletion scope. Parent/subtask effects follow Todoist's own
completion rules. Recurring tasks advance as in Todoist; their next active
occurrence can reopen the same local Task. Reopening does not promise to undo
a previous recurrence's date advancement.

Reminders resolves the exact stable identity, rejects ambiguity, checks selected
list and write access, then saves only `isCompleted`/`completionDate`. A retry
that already has the desired state does not save again. Existing Flow history
and local notes remain intact when adopting either remote state.

References: [Todoist API](https://developer.todoist.com/api/v1/) (command UUIDs,
completion-date queries, item close/uncomplete),
[EventKit save](https://developer.apple.com/documentation/eventkit/creating-events-and-reminders).

`Todo.externalTaskLinkRawValue` contains non-secret JSON identity and source
metadata. Provider + account + task ID form the deduplication key; source ID is
metadata because a task can move between projects/lists. Corrupt identity data
fails explicitly rather than creating an unlinked duplicate. No separate
SwiftData entity is introduced; see [Data model](DATA_MODEL.md) and the
[CloudKit migration gate](CLOUDKIT.md#connector-link-migration--upcoming-20).

Concurrent imports before CloudKit convergence may temporarily create two Todos.
The importer retains the oldest record, with UUID as the tie-breaker, reconnects
FlowSession and FlowSegment references, preserves local memos and completion,
and rebuilds measured progress from actual history. Redundant records are
soft-deleted with a `supersededByTodoID` marker in their link JSON. This marker
distinguishes merge tombstones from deliberate user deletion, which must never
resurface. Late-arriving Flow references are repaired on subsequent passes.

Imports initially exclude Habit Areas. If the user later moves an imported Task
into a Habit Area, the external link excludes it from generated-Habit planning,
deduplication, template rewrites, and pause-driven removal.

## Credentials and settings

`ConnectorKeychain` stores Todoist access/refresh tokens as generic-password
items under service `com.shigorefu.thruflow.connectors.v1`. Items are
non-synchronizing and use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
Tokens never enter SwiftData, CloudKit, UserDefaults, repository files, URLs
shown by the app, or error messages. Keychain failures are surfaced and must
not silently replace a working connection with incomplete credentials.

`ConnectorStore` keeps only provider/account display metadata, source IDs,
Area UUID, and import-success details in local UserDefaults under
`connectors.connections.v1`. Each device needs its own authorization and
selection. A missing or expired credential requires renewal or reconnecting;
configuration surviving without its device credential is not proof of access.

A separate ModelContext owns each import transaction, so rollback cannot
discard an open Task or Flow editor's pending changes. The success timestamp
advances only after the imported data saves. Tests and previews inject fake
credentials, provider clients, browser behavior, and local model containers.

## Apple Reminders identity and permission

EventKit full reminder access is required on the supported OS versions. The
application reads and writes completion only after permission; list selection
limits what is imported. Permission denial or later revocation is an actionable
connection error. Selecting a missing list fails rather than being treated as
an authoritative empty source.

Normal synchronized reminders use `calendarItemExternalIdentifier` for identity
across devices. Their selected list identifiers remain device-local. EventKit
can assign the same external identifier to copied items, so ambiguous external
IDs across accessible reminder lists are rejected before import. Resolve the
copies in Reminders before retrying; merely selecting a different list does
not make a shared identifier unique.

Local reminders and Exchange reminders cannot supply the same cross-device
identity guarantee. Their fallback identity includes a persisted installation
UUID and the local calendar-item identifier. This prevents unrelated device
records from being merged, but importing the same fallback reminder on two
devices can create separate ThruFlow Tasks. EventKit identifier changes after
store resets or account changes also require real-device verification. The
connector does not match titles or dates heuristically.

Apple documents the identifier behavior in
[`calendarItemExternalIdentifier`](https://developer.apple.com/documentation/eventkit/ekcalendaritem/calendaritemexternalidentifier).
No private Reminders URL scheme is assumed.

## Todoist authorization and static website

The app is a public OAuth client with `data:read_write` scope, a fresh random state,
and an S256 PKCE verifier/challenge. Native AuthenticationServices opens the
provider consent screen. The callback must match the expected origin/path,
contain one matching state and one authorization code, and carry no OAuth error.
The app exchanges the code directly with Todoist and stores the resulting
user credentials in Keychain. Before dispatching a token renewal, the app
persists the existing credentials with their refresh token removed; the original
refresh token remains only in the in-memory request. If that initial Keychain
save fails, no renewal request is sent. A successful replacement is saved before
any provider API read. A lost or canceled response, process exit during renewal,
or failure to save the replacement leaves no reusable refresh token, so the next
renewal requires reconnection. The app never retries a potentially consumed
refresh token: Todoist can revoke the user's app authorizations on every device
when a consumed token is replayed after its grace window. This conservative rule
can require reconnection after a temporary network failure. No `client_secret`
is distributed in the app or served by the website.

The app uses these public URLs:

| Purpose | URL |
| --- | --- |
| Public OAuth client identifier and metadata | `https://thruflow.shigorefu.com/oauth/todoist/client.json` |
| Registered HTTPS redirect | `https://thruflow.shigorefu.com/oauth/todoist/callback/` |
| Apple Associated Domains declaration | `https://thruflow.shigorefu.com/.well-known/apple-app-site-association` |
| Todoist authorization | `https://app.todoist.com/oauth/authorize` |
| Todoist token exchange and renewal | `https://api.todoist.com/oauth/access_token` |

The public website files live in the sibling `thruflow-site` repository. They
are static metadata, a callback page, and an association document, not a signup
service or an API backend. Keep client metadata, redirect paths, app constants,
Associated Domains entitlement, and AASA app identity consistent when changing
domain, bundle ID, or signing team.

macOS 14.4+/iOS 17.4+ use the native HTTPS callback API. Earlier supported
versions use the callback page's `thruflow://oauth/todoist` bridge; the app still
validates callback path/state and exchanges the code with PKCE. The callback
page must not expose codes to analytics, third-party scripts, referrers, or
persistent browser storage. Static file presence in a checkout alone does not
prove the public OAuth flow works.

On AWS Amplify, the website build copies AASA to a JSON artifact and an exact
200 rewrite serves it at the required extensionless URL. The rule is versioned
in the website repository under `infra/amplify-custom-rules.json`; see its
infrastructure README. A 301/302 response is not a valid association response.
The public connector announcement, support copy, and privacy additions remain
commented out in `app/site.tsx` until the owner enables the announcement. The
static OAuth endpoints stay deployed independently.

Todoist's current API and public-client requirements are documented in
[Authorization](https://developer.todoist.com/api/v1/#tag/Authorization).
Connector tests use mock responses; they do not establish that the public
metadata URL or a signed app callback has been accepted by Todoist or Apple.

## Provider branding

Connector screens use the official Apple Reminders app icon and Todoist brand
assets. Keep their original shape and colors, use the supplied dark-background
Todoist variant where needed, and retain the [asset provenance](CONNECTOR_ASSETS.md). ThruFlow is not
created by, affiliated with, or supported by Todoist. Include that relationship
statement in the public application description as required by
[Todoist brand usage](https://developer.todoist.com/api/v1/#section/Developing-with-Todoist/Brand-usage).

## Development verification (2026-09-07)

- The complete sequential macOS unit suite passed: 366 tests in 36 suites.
- Unsigned Debug builds passed for macOS and iOS Simulator, including the
  embedded Watch app and Live Activity extension.
- The static website passed lint/build and eight callback bridge checks. The
  production metadata, AASA, and callback return HTTP 200 without redirects;
  JSON content types and callback no-store/no-referrer/CSP headers were checked.
  The public connector announcement remains absent from the rendered pages.
- An unauthenticated Todoist authorization request reached its sign-in page;
  no account sign-in or consent was submitted. This is not a complete OAuth test.
- The macOS UI test runner was killed before XCTest bootstrap in the unsigned
  environment; an ad-hoc signing attempt failed in the Code Signing subsystem.
  This navigation automation is not reported as passing. Native visual review
  covers the provider screens separately; signed device checks below remain.

## Verification and release gates

Run macOS tests sequentially, including `ConnectorTaskImporterTests`,
`ConnectorStoreTests`, provider and OAuth tests, plus the full existing suite
because the shared persistence schema changes. Use
`-parallel-testing-enabled NO -maximum-parallel-testing-workers 1` as in the
[README build instructions](../README.md#build-locally). Build macOS, iOS, and
watchOS; watchOS must still compile the shared DTO/link/reconciliation path.
Native navigation tests should open both provider screens without accessing
real accounts or triggering an OS permission prompt.

Before release:

- Verify the complete local suites, source diff, and Japanese/English/Russian
  visual review, including compact screens, keyboard navigation and VoiceOver.
- Deploy and inspect the exact public metadata, callback, and AASA responses
  with HTTPS, correct content types, no unwanted redirects, and the signed app's
  actual team/bundle identity. Check macOS/iOS Associated Domains entitlements
  and provisioning profiles, then allow Apple association caching to refresh.
- Verify Todoist login, deny/cancel, account switch, read/write consent, expired
  tokens, token rotation, offline errors, and disconnect/reconnect on signed
  Mac and physical iPhone/iPad builds. Exercise both native HTTPS and supported
  older-OS callback behavior. An unsigned build is not this verification.
- Verify Reminders allow/deny/revoke, multiple accounts/lists, dates, source
  moves, local/Exchange limitations, duplicate IDs and recurring tasks on
  physical devices. Keep original reminders unchanged throughout.
- Migrate a backed-up existing SwiftData store without clearing it. Initialize
  and inspect the nullable Todo link field in Development, deploy it to
  CloudKit Production, then check clean installs and upgrades.
- Exercise simultaneous offline imports, CloudKit convergence, late Flow
  references, user-deleted/completed Tasks, and local memo/planning preservation
  across signed Mac and iPhone installations. The simulator cannot validate
  real CloudKit delivery.
- Review public privacy policy and App Store disclosures for explicit provider
  access and device-local tokens, then finish normal archive, TestFlight, and
  release checks. No new pricing is introduced by this implementation, and the
  existing free, ad-free core commitment remains unchanged.

## Toggl Track: outgoing focus time

Toggl Track is a separate time-export connector, not a task importer and not
Toggl Focus / Toggl 2.0. macOS and iOS offer it in the same connector list.
The user enters a Track API token from <https://track.toggl.com/profile>, selects
one workspace, maps any active Areas (including Habits) to existing active
projects, and explicitly saves with automatic export enabled. Unmapped Areas
are excluded. Tokens remain in the existing per-device Keychain; no backend,
client secret, OAuth callback, or website change is needed for this connector.

Only completed FlowSessions created and started after activation on the current
recording device are eligible. A pause/resume of automatic export establishes a
new start boundary; it does not backfill disabled periods. Existing queued jobs
remain pending. Legacy records without a recording-device identifier, imported
history, active/provisional/interrupted sessions, and records started on another
device (including Watch) are not automatically exported. If a Flow is continued
on another device, its originating Mac/iPhone exports it after receiving the
completed record. That device must run the app with its connector enabled.

Each completed context segment creates one completed time entry: Task title
(or Area name), mapped project, segment start, and exact focused seconds. Empty segment relationships wait for delivery; they do not fall back to a whole-session entry. Partial segment delivery is
not exported until segment focus totals match the session total. Breaks and
paused seconds are excluded. Toggl accepts start plus duration; when a segment
contains pauses, its derived stop is start plus focused duration rather than the
wall-clock end. No remote timer is started/stopped. Entries receive a single
`ThruFlow` tag and `created_with: ThruFlow`. Workspace rules must permit this tag.

### Delivery semantics

The application writes an atomic local JSON outbox before POST, then stores
remote IDs as durable receipts. Job identity includes account, session, and
segment UUIDs; every job is also restricted to its recording device. Jobs and
receipts are local, not CloudKit records, and never contain API tokens. The
optional `FlowSession.recordingDeviceID` travels through CloudKit, while its
matching random device identity remains in a ThisDeviceOnly Keychain item.
This prevents two devices independently exporting the same CloudKit session
without relying on distributed locks or synchronization timing.

Definite pre-connection failures and rejected requests remain retryable. Before
POST, a job is marked uncertain on disk. A timeout, cancellation, malformed
success response, process exit, or failed receipt save leaves it uncertain.
The next attempt reads the narrow original start-time range and adopts only a
unique match of workspace, project, start, focused duration, description, and
the ThruFlow tag. Multiple or absent matches never trigger another automatic
POST. The UI lets the user inspect Toggl and explicitly authorize retry if the
entry is absent; this confirmation explains duplicate risk. The Track API does
not supply an assumed idempotency contract. An explicit retry after a lost
response can duplicate a remote entry; automatic sending does not silently
make that decision.

Export runs on the existing scene-scoped foreground loop, at most every 30
seconds when enabled, plus manual Send now. No pending jobs means no provider
requests. The API client spaces requests and honors quota Retry-After cooldowns
for automatic sync. There is no guaranteed background delivery. Account identity
is verified before draining an outbox. Reconnect to another account cannot send
the previous account's jobs; disconnect stops export and removes the token,
while retaining local/remote history and receipts. Same-account pending jobs
can resume after reconnect and re-enabling. Deleting a Flow before its first
successful dispatch cancels its unsent job. Already exported or uncertain jobs
are never deleted remotely. Captured sessions and their payloads are immutable; later local edits
and deletions are not synchronized in this first outgoing-only version.

### Verification and release gates

Tests use stubbed HTTP and isolated SwiftData/queue stores, covering authorization,
request payloads, projects, quota handling, segment projection, device ownership,
relaunch, lost responses, storage failures, account changes, and disconnect.
Real-account consent, quota/tags/project permissions, signed two-device handoff,
and receipt recovery remain integration checks before release. No real customer
token or Toggl account is used by automated tests.

API references:
- <https://engineering.toggl.com/docs/authentication/>
- <https://engineering.toggl.com/docs/track/api/me/>
- <https://engineering.toggl.com/docs/track/api/time_entries/>
