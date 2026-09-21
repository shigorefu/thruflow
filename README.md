# ThruFlow

ThruFlow / スルフロ is an Apple-first productivity app that turns focused work into visible task progress.

```text
Area -> Task -> Flow -> focused time -> progress -> statistics
```

Released app version: **1.3.1 (12)**. See the [release notes](docs/releases/1.3.1.md).

The latest released version is [1.3.1](https://github.com/shigorefu/thruflow/releases/tag/v1.3.1)
(build `12`), available on the [App Store](https://apps.apple.com/app/id6798609191).
See the [changelog](CHANGELOG.md) for released versions. Development branches
may contain upcoming features; back up important data before testing them and
report reproducible problems through the
[GitHub issue templates](https://github.com/shigorefu/thruflow/issues/new/choose).

## What ThruFlow does

- Records focused work with Sprint, Focus, and Deep timers.
- Connects actual focused time to Tasks and long-lived Areas.
- Preserves a detailed Flow/rest timeline and recalculates progress from history.
- Shows daily, weekly, monthly, yearly, Task, and Area statistics.
- Syncs through the user's private iCloud database while retaining a local-only development mode.
- Provides iPhone and macOS widgets, Live Activity and Dynamic Island, plus an Apple Watch companion.
- Uses Japanese by default and includes English and Russian localizations.

`1 Block` is always 25 focused minutes. Breaks are not counted.

## Connectors

Version 1.3.0 adds Apple Reminders and Todoist task imports on
macOS, iPhone, and iPad. Open Connectors above Settings in the Mac sidebar,
in the iPhone Flow More menu, or in the iPad sidebar footer. Choose lists or
projects for each destination Area, then import their unfinished tasks.
Version 1.3.1 adds per-Area mappings and improves Toggl project loading and
Keychain access prompts. Connectors remain in beta.

Reminders uses the system permission prompt; Todoist opens its own sign-in and
consent screen. No ThruFlow account or custom backend is required. Access tokens
stay in the device Keychain, and imported tasks use the existing local and
private-iCloud storage. Refresh updates external titles and deadlines while
preserving ThruFlow notes, planning, and Flow history. Check-task completion
and reopening synchronize both ways.

See [Connectors](docs/CONNECTORS.md) for behavior, limitations, and setup.

Version 1.3.0 also includes Toggl Track: API-token connection,
Area/project mapping, and outgoing completed focus time from the recording device.
See [connector behavior and release checks](docs/CONNECTORS.md#toggl-track-outgoing-focus-time).

## Platforms and requirements

| Target | Minimum OS |
| --- | --- |
| macOS app | macOS 14.0 |
| iPhone and iPad app | iOS/iPadOS 17.0 |
| Apple Watch app | watchOS 10.0 |

Development currently uses Xcode 26.6 and Apple system frameworks only. The app has no third-party runtime dependencies.

## Build locally

1. Clone the repository and open `ThruFlow.xcodeproj` in Xcode.
2. Select `ThruFlow`, `ThruFlow iOS`, or `ThruFlow Watch`.
3. For a signed iCloud build, replace the development team, bundle identifiers, App Group, and CloudKit container with values owned by your Apple Developer account.
4. For deterministic local development, add the `--local-store` launch argument or set `THRUFLOW_DISABLE_CLOUDKIT=1`.

Unsigned local verification:

```sh
THRUFLOW_DISABLE_CLOUDKIT=1 xcodebuild test \
  -project ThruFlow.xcodeproj \
  -scheme ThruFlow \
  -destination 'platform=macOS' \
  -only-testing:ThruFlowTests \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -derivedDataPath DerivedData/Tests \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project ThruFlow.xcodeproj \
  -scheme 'ThruFlow iOS' \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData/iOS \
  CODE_SIGNING_ALLOWED=NO
```

CloudKit synchronization cannot be validated in the simulator. Use signed builds on a real iPhone, Apple Watch, and Mac, and follow [the CloudKit guide](docs/CLOUDKIT.md).

## Documentation

- [Product overview](docs/PRODUCT.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Domain model](docs/DOMAIN_MODEL.md)
- [Data model](docs/DATA_MODEL.md)
- [UX flows](docs/UX_FLOWS.md)
- [CloudKit setup](docs/CLOUDKIT.md)
- [Connectors and native OAuth setup](docs/CONNECTORS.md)
- [Localization](docs/LOCALISATION.md)
- [Release process](docs/RELEASE.md)
- [Roadmap](docs/ROADMAP.md)

## Project policies

- [Contributing](CONTRIBUTING.md)
- [Contributors and attribution](CONTRIBUTORS.md)
- [Licensing model](LICENSING.md)
- [Security](SECURITY.md)
- [Privacy](PRIVACY.md)
- [Support](SUPPORT.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

## Release status

Passing CI is necessary but not sufficient for a TestFlight or App Store release. Device, CloudKit Production, StoreKit, privacy metadata, signing, archive validation, and TestFlight smoke checks remain manual release gates; see [Release process](docs/RELEASE.md).

## License

Unless otherwise noted, all original repository content is available under
[`AGPL-3.0-or-later`](LICENSE). Official TestFlight and App Store binaries are
separately distributed under Apple's applicable terms, and incoming
contributions are accepted under `BSD-3-Clause`. See
[`LICENSING.md`](LICENSING.md) for the complete policy.
