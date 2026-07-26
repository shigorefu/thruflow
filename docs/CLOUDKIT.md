# CloudKit

## Configuration

- Apple Developer Team: `BR727PS795`.
- macOS and iOS bundle identifier: `com.shigorefu.thruflow`.
- Test bundle identifiers use the lowercase suffixes `.tests` and `.uitests`.
- Shared container: `iCloud.com.shigorefu.thruflow`.
- Service: CloudKit private database. There is no public/shared database product
  behavior in the current MVP.
- iOS minimum deployment target: 17.0. Builds use Xcode 26 and the installed iOS
  26 SDK without making iOS 26 the deployment target.

Both app targets contain the CloudKit entitlement. `AppModelContainerFactory`
uses the same SwiftData schema and private container on normal signed runs.
macOS additionally verifies the entitlement on the running process before
opening the CloudKit-backed store. iOS device builds rely on the signed target
entitlement; the simulator is rejected earlier by the platform check and stays
local-only.

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

## Development Verification

1. Sign in to an Apple ID with iCloud Drive enabled on the Mac and iPhone.
2. In Xcode, select team `BR727PS795` for both application targets.
3. Connect the iPhone once and trust the Mac so Xcode can register the device
   and create the `com.shigorefu.thruflow` development profile.
4. Run both signed apps. The development schema is materialized from the
   SwiftData model when the CloudKit-backed store starts.
5. Create or edit a Direction/Task/Flow on one device and verify it arrives on
   the other after both apps have had network time to process CloudKit changes.
6. Start Flow on one device while the other application is active. Verify that
   Task, Direction, mode, phase, pause state, and remaining time are adopted
   without restarting the timer. Repeat the command in the opposite direction.

Simulator builds cannot validate CloudKit synchronization because Xcode strips
the iCloud container entitlement for the simulator SDK. Use signed macOS and
physical iPhone builds for synchronization diagnostics.

## Active Flow Runtime

The active timer is synchronized through the current `FlowSession`. Absolute
timestamps, pause/break anchors, and a runtime revision allow another client to
reconstruct the timer without transferring per-second ticks. macOS, iOS, and
watchOS reconcile on launch, foreground entry, and while active. The same
mechanism works in local-only mode.

CloudKit does not provide a guaranteed real-time wakeup channel for a suspended
application. If the iPhone app is suspended when Flow starts on macOS, the
session is adopted the next time iOS receives and processes the CloudKit change,
typically when the app becomes active. Guaranteed background creation or
updating of Dynamic Island requires ActivityKit push tokens and an APNs
provider. That server-assisted transport is not part of the current private
CloudKit implementation.

## Production Schema

Before distributing a build, open CloudKit Console for
`iCloud.com.shigorefu.thruflow`, inspect the Development schema and indexes, then
deploy that schema to Production. Do not deploy schema changes casually:
production CloudKit schema changes are forward-only and must remain compatible
with existing app versions and local SwiftData stores.

## Current Provisioning Blockers

The project and entitlements are configured. A physical-device development
profile cannot be generated until at least one iPhone is registered with the
team. The current Mac must also be registered before Xcode can issue the Mac App
Development profile needed for signed UI tests and CloudKit diagnostics.
Connecting/registering both devices through Xcode resolves these provisioning
blocks; they are not code or schema failures.
