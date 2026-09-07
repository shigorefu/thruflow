# Connectors

This document describes the upcoming 2.0 implementation. It does not declare
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
login and read-only consent flow; no ThruFlow registration or provider password
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
| Completion | Create unfinished Check Tasks only | Preserve local status and completion date |
| Area, priority, measurement, target | Normal local Task defaults and selected Area | Preserve local choices |
| Focus, progress, Flow relationships | No invented work | Preserve recorded work |
| Remote task missing or deleted | Nothing to import | Retain the local Task |
| Repeating remote task with the same ID | One local Task | No new local occurrence or implicit reopening |

The connectors never complete, edit, or delete source tasks. Remote completion
does not complete an existing ThruFlow Task. An external Task that is already
completed before its first import is skipped. There is no inference of deletion
from an empty or partial provider response.

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
application performs read operations only after permission; list selection
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

The app is a public OAuth client with `data:read` scope, a fresh random state,
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
- Verify Todoist login, deny/cancel, account switch, read-only consent, expired
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
