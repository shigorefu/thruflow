# Notification delivery (1.5.0)

## Contract

Mac and iOS use `Shared/Application/Notifications/NotificationDeliveryRuntime`
for Flow completion, break completion, running-too-long alerts, and Task
reminders. SwiftData/CloudKit and the timer remain authoritative. This service
is not a timer, synchronization replacement, Matrix chat bot, or ActivityKit
push provider. Watch remains local-only; widgets keep their snapshot contract.

At scheduling time the app installs a local notification first. After an
explicit durable server acceptance, a still-future local request becomes a
30-second delayed safety notification. Failure to register with APNs, enroll,
authenticate, or schedule on the server keeps the original local deadline.
A matching actual receipt cancels the local safety request. APNs HTTP 200 is
provider acceptance, not proof of device delivery. The notification service
extension is embedded in both clients and cancels only the exact notification
version, avoiding cancellation of a subsequently rescheduled Task.

The app's serialized queue handles adds, cancellations and acceptance callbacks.
Full snapshots have monotonically increasing revisions and immutable event
versions. Server cancellation cannot recall a push already in flight. Extension
execution, receipt storage and notification display are system controlled:
late or duplicate alerts remain possible after suspension, crash, connectivity
loss or a race. Do not describe this transport as exactly-once delivery or a
guaranteed delivery deadline. Notifications muted by permission settings or
Focus are not treated as failed delivery.

A per-installation random capability is stored in nonsynchronizing Keychain;
there is no shared secret embedded in the app and no new user account. Mac and
iOS enroll independently. Changes made on another device reach that device's
notification schedule through existing CloudKit exchange, not through a new
server-wide user identity. The server cannot instantly cancel an offline
second device's old schedule.

## Per-device server preference

The notification setting enables server delivery by default on Mac and iOS.
It is stored only on that device as `notification.remote.enabled`; it does not
change iCloud synchronization, connectors or another device's setting. Turning
it off keeps local notification routing active and requires no restart.

OFF immediately blocks enrollment, schedule uploads and periodic retries,
cancels in-flight transport work and invalidates its asynchronous responses.
The serialized local queue restores future notifications to their original
deadlines. An already-due notification with a still-pending 30-second safety
request keeps that existing future deadline, including across rapid toggles
and relaunches; it is not replayed immediately. Transport event versions change
so an old push or extension receipt cannot cancel the restored notification.
The extension also checks the shared App Group preference before cancelling
local requests.

If an existing installation capability is available, switching off makes one
final authenticated `DELETE /v1/installations/<id>` cleanup request. It does not
create or enroll an identity for cleanup. Success erases that installation's
token and event rows; a bounded revocation tombstone rejects a late enrollment
or schedule request for the old identity. No cleanup retry, enrollment or
schedule upload runs while OFF, including after relaunch. A failed cleanup
request leaves a persistent unconfirmed-cancellation warning; a later successful
cleanup for a different identity cannot clear that earlier uncertainty.

Offline cleanup cannot recall the server's accepted queue, and no cleanup can
recall an APNs push already in flight. Previously accepted notifications may
therefore still arrive late or duplicate a local notification after OFF. The
setting must not promise immediate withdrawal of all previously sent alerts.
Turning ON creates a fresh installation identity and requests fresh native APNs
registration without restarting the app; local notifications remain available
when registration or server acceptance fails.

Demo, screenshot and test isolation gates take precedence over this preference:
changing the switch there does not contact the server or write live App Group
state, create a Keychain installation identity, or change normal app preferences.

## Data and safety

The server receives APNs device token/environment, installation/event IDs,
revisions, deadlines and fixed localized app notification copy. Task names and
memo text stay on the device: remote Task reminders have the generic existing
Task reminder title and an empty body. No SwiftData schema change is required.
Local fallback retains its normal detailed copy. Enrollment secrets are stored
as hashes server-side; device tokens are stored in the private SQLite volume.
No request bodies, authorization headers, tokens or notification copy are logged.
Terminal event text is cleared; terminal rows are retained seven days, and
inactive installations without events expire after 90 days. Successful
revocation deletes installation and event data immediately, retaining only the
random installation ID, capability hash and revocation timestamp until
maintenance removes the tombstone after 90 days. Active installations and revocation tombstones share the enrollment bound.

The public enrollment API has request/body/event/concurrency/installation bounds
and an Nginx IP rate limit. It is an installation capability API, not verified
App Attest or user authentication. Anonymous enrollment abuse remains a capacity
risk; do not reuse it to authorize access to user records or privileged APIs.

Demo, screenshot and test modes do not enroll devices or contact this service.
Existing notification authorization prompts remain attached to user actions;
APNs registration does not itself request permission to display alerts.

## Server

Source: `server/notifications`. Python standard library provides HTTP, SQLite
and scheduling; system OpenSSL signs ES256 JWTs, and curl sends HTTP/2 to APNs.
No pip dependencies are installed. The dedicated Docker service has a read-only
root filesystem, non-root UID 10001, dropped capabilities, bounded logs, memory
128 MiB, CPU 0.25, PID limit 64 and an 8 MiB temporary filesystem. Only loopback
port 18081 is published. Existing Nginx terminates HTTPS at
`https://matrix.shigorefu.com/thruflow-push/` and strips that prefix.

On `matrix-server`, files live in `/opt/thruflow-notifications`:

- `compose.yml`, `Dockerfile`, `server.py`: deployed source.
- `.env`: APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC (ThruFlow only).
- `secrets/apns.p8`: UID 10001, mode 0600, read-only mount.
- Docker volume `notification-state`: durable private SQLite queue.

Do not commit `.env`, signing keys, volume exports, installation credentials or
private request samples. Install a real APNs key before enabling server
acceptance. `/health` reports process health and key/configuration readiness;
it does not prove APNs authorization or device delivery.

```sh
cd /opt/thruflow-notifications
sudo docker compose up -d --build --wait
curl --fail https://matrix.shigorefu.com/thruflow-push/health
sudo docker compose ps
```

Back up the volume and the APNs key through private operational storage, never
Git. To roll back transport, clear `THRUFLOW_PUSH_ENDPOINT` in both app builds
and retain the local notifier. Stopping the server leaves already accepted
clients with their delayed local safety notification; do not delete the volume
to perform a deployment. Nginx edits must pass `nginx -t` before reload. Existing
Matrix services are independent and are not restarted by this deployment.

## Signing and checks

Both app targets need Push Notifications plus the existing App Group. The new
`com.shigorefu.thruflow.notifications` extension also needs that App Group and
its own valid profile. Debug uses development APS / sandbox endpoint; Release
uses production APS / production endpoint. `THRUFLOW_PUSH_ENVIRONMENT` must match
the **exported signed entitlement**; override it together with `APS_ENVIRONMENT`
when using nonstandard Release development signing. A build alone does not
verify this. Do not infer APNs environment from token bytes.

```sh
python3 -m unittest discover -s server/notifications -p 'test_*.py'
```

Run notification regression suites and the full app unit suite. Signed Mac and
physical iPhone tests must cover foreground/background/terminated delivery,
all notification kinds, offline fallback, rescheduling/cancellation, NSE receipt,
registration failure and production/sandbox token routing. Simulator injection
and APNs responses to synthetic tokens do not establish end-to-end delivery.

## Verification — 2026-11-24

The implementation/logic orchestrator and independent macOS and iOS reviewers
agreed on the contract before editing, and agreed on the final source after
fixing stale receipt, pending safety-window, foreground duplicate and
reschedule/cancellation race findings. The localization reviewer agreed on all
eight reused static titles across Japanese, English, Russian, Simplified and
Traditional Chinese; no catalog edits or native-speaker/visual claim were made.

Actual checks:

- Full macOS unit suite: 603 tests in 60 suites passed, including ten new remote
  delivery tests and one Task safety-window regression. The release-only
  screenshot fixture was excluded according to the normal test command.
- Backend: 24 standard-library tests passed, covering authentication, revisions,
  cancellation, immutable event versions, bounded retry, restart recovery,
  HTTP limits, payloads, and a disposable OpenSSL ES256 signing roundtrip.
- Platform-review map: validation and 14 script tests passed. CI runs backend
  tests with its existing Linux classification/validation step.
- Final unsigned macOS/iOS Release builds passed (iOS includes Watch). Final
  Apple Development-signed Mac and iOS Debug builds passed. iOS provisioning
  for the new notification extension was explicitly authorized by the owner.
  Processed Info.plist and signed APS environment were checked: sandbox matches
  development on both clients; both embed the App Group-enabled extension.
- Live Docker service is healthy. TLS enrollment, unauthorized access rejection,
  schedule acceptance, queue recovery after restarting only this container,
  cancellation and rejection of an older revision passed using one isolated
  synthetic installation, removed after the test. Matrix's versions endpoint
  and existing services remained available.
- Both APNs hosts returned HTTP 400 for a deliberately invalid all-zero token.
  This is a connectivity/provider-request check, **not device delivery proof**.
- Observed idle service usage was about 14.4 MiB / 128 MiB and 0.19% CPU. This
  is a single idle sample, not a load/capacity test.

Local logs are in ignored `DerivedData/PushQA/` (unit-tests, final Release and
signed build logs, and platform-review report). No user database was reset,
exported or migrated, and no CloudKit schema was changed. The downloaded APNs
key's temporary local copy was removed after server installation; it is not
in Git or the application.

Not verified: real alert receipt/display on a physical iPhone or running Mac,
NSE execution/cancellation on locked/suspended devices, offline-to-online real
network transitions, notification permissions/Focus modes, production-signed
App Store delivery, and load testing. Do not mark those release gates complete
from the successful signed builds or synthetic APNs response. Before App Store
submission, review the privacy disclosures for the new installation/token and
schedule metadata processed by the server.

### Server preference follow-up — 2026-11-24

The backend suite passed 28 tests, including authenticated revocation, private
schedule deletion, pre-enrollment revocation races and bounded tombstone
retention. A live isolated synthetic installation passed enrollment by `PUT`,
revocation by `DELETE`, and rejection of a subsequent stale enrollment with
HTTP 410. The synthetic test data was removed. These checks establish the
server cleanup path, not actual device delivery or offline withdrawal of an
already accepted APNs push.

The final preference candidate passed 613 ordinary macOS unit tests plus the
separate release screenshot fixture (614 tests total), 28 backend tests, and both
unsigned Release builds. Both built notification extensions contain their
required-reason privacy manifest. The macOS and iOS reviewers agreed on the
server-only preference contract and final source; the localization reviewer
agreed on its five new strings in all five supported locales. Physical-device
delivery and exact production-signed exports remain unverified.
