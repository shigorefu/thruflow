# Privacy Policy

Last updated: November 24, 2026

ThruFlow is designed to keep productivity data under the user's control.

## Data handled by the app

ThruFlow stores the information users enter or create, including Areas, Tasks, Flow sessions, breaks, notes, settings, and calculated statistics. This data is required to provide the app's core functionality.

By default, supported signed builds may synchronize this data through the user's private Apple iCloud/CloudKit database. Apple processes that data under the user's Apple account and Apple's terms. ThruFlow's developer does not operate a separate analytics, advertising, or account server and cannot browse records stored in a user's private CloudKit database.

When iCloud is unavailable or intentionally disabled, ThruFlow uses local SwiftData storage on the device.

## Data collection and tracking

ThruFlow does not include advertising SDKs, third-party analytics, cross-app tracking, or data brokers. The app does not sell personal information.

The app uses:

- local notifications and the notification delivery service described below;
- Apple StoreKit for optional consumable tips;
- Apple system services for iCloud synchronization, widgets, Live Activities, and App Store review requests.

Apple may process diagnostic, purchase, iCloud, and App Store information according to the user's Apple settings and Apple's privacy policy. ThruFlow does not receive payment-card details.

TestFlight automatically provides the developer with crash logs and statistical
or usage information under [Apple's TestFlight terms](https://www.apple.com/legal/internet-services/itunes/testflight/).
Testers may also choose to send feedback, including comments or screenshots,
through TestFlight. This beta testing information is used only to diagnose
defects and improve release quality.

For App Store releases, Apple may provide aggregated sales and performance
metrics. App usage and diagnostic data is available to the developer only under
Apple's applicable [privacy, opt-in, and reporting-threshold rules](https://developer.apple.com/help/app-store-connect-analytics/).
ThruFlow does not add a separate analytics SDK.

## Notification delivery service

Starting with version 1.5.0, supported Mac and iPhone/iPad builds use a
developer-operated HTTPS service to schedule Apple Push Notification service
(APNs) alerts for Flow completion, break completion, running-too-long alerts,
and Task reminders. Local notifications provide a fallback. Apple Watch uses
local notifications and does not enroll with this service.

The service processes the following information to operate notifications:

- a randomly generated installation identifier, APNs device token, APNs
  environment, and platform (macOS or iOS);
- an installation credential used to authenticate requests, stored on the
  server only as a hash;
- notification event identifiers and versions, schedule revisions, deadlines,
  badge counts, delivery/retry state, and fixed localized notification copy.

These device identifiers and product-interaction data are associated with the
installation and used only for app functionality: authenticating requests,
scheduling, delivering, updating and cancelling notifications, and protecting
the service. They are linked to the device for privacy disclosure purposes even
though ThruFlow does not require a separate user account. They are not used for
advertising, behavioral analytics, cross-app tracking, or data brokerage.

Task names, notes, and Flow memos are not sent to this service. Remote Task
reminders use a generic title with an empty body; local fallback notifications
may include the Task title on the device. The service does not receive the
user's private CloudKit database or Apple account credentials. APNs receives
the device token and notification payload needed to deliver the alert. Network
requests necessarily expose connection information to the hosting infrastructure;
operational error logs may contain connection or request metadata.

Notification permissions and Focus settings are controlled by Apple system
settings. Disabling alert display does not itself delete the installation's
server record. Delivery timing and receipt are subject to system and network
conditions; the local fallback may occasionally result in a late or duplicate
alert.

The ThruFlow notification server setting is enabled by default and can be
disabled in Settings under Notifications. This preference applies only to the
current device. Turning it off stops new server notification scheduling and
keeps local notifications available; iCloud synchronization and connector
settings do not change. For an existing installation, the app makes one final
authenticated request to remove its server schedules and device token. It does
not automatically retry that request while the setting is off. If removal cannot
be confirmed, the app shows a warning; previously scheduled or already-sent
remote alerts may still arrive. Re-enabling the setting creates a new
installation identifier and credential.

## Retention and deletion

Local data remains on the device until the user deletes records or removes the app and its data. Synced data remains in the user's private iCloud storage until it is deleted from the app or through the user's iCloud data controls. Copies may remain in the user's own device or iCloud backups according to Apple's backup settings.

The notification service clears notification title/body text when an event is
accepted by APNs, cancelled, or expired. Terminal event records are removed after seven days.
Installation records, including the device token and credential hash, are removed
after 90 days without an installation update when no event records remain.
Pending events remain until delivered, cancelled, or expired; removing the app
does not send an immediate server-deletion request. These are the live service's
automatic retention rules, not a promise to erase device or iCloud backups.

When the server accepts the setting's removal request, it deletes that
installation's token and event records. It retains only the revoked installation
identifier, credential hash, and revocation time for 90 days to reject older
requests that are still in flight. If removal is unsuccessful, the automatic
retention rules above continue to apply.

## Children

ThruFlow is a general productivity tool and is not directed to children. The
notification service handles the limited device and schedule data described
above for installations using supported builds.

## Changes

Material changes to this policy will be published in this repository with an updated date.

## Contact

For privacy questions, open a support request using the options in [SUPPORT.md](SUPPORT.md). Report security-sensitive matters privately as described in [SECURITY.md](SECURITY.md).
