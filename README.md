# ThruFlow

**English** · [日本語](README.ja.md)

ThruFlow / スルフロ is a free, open-source app for focused work and building habits on Apple devices. Its flexible Pomodoro timer turns time spent working into visible progress on your tasks.

**[Download on the App Store](https://apps.apple.com/app/id6798609191)** · **1.4.0 (14): awaiting App Review** · [What's new](docs/releases/1.4.0.md)

| Device | Minimum OS |
| --- | --- |
| Mac | macOS 14.0 |
| iPhone and iPad | iOS/iPadOS 17.0 |
| Apple Watch | watchOS 10.0 |

## Screenshots

The Flow screen on Mac and iPhone, version 1.4.0, using demonstration data.

| Mac | iPhone |
| --- | --- |
| <img src="https://d3cwdiba8hmqn5.cloudfront.net/screenshots/1.4.0/en/Mac/01-flow.jpg" alt="ThruFlow 1.4.0 on Mac: focus timer, work timeline, tasks, and statistics" width="680"> | <img src="https://d3cwdiba8hmqn5.cloudfront.net/screenshots/1.4.0/en/iPhone/01-flow.jpg" alt="ThruFlow 1.4.0 on iPhone: the Flow screen with a selected task and timer" width="240"> |

## Features

- **Flexible Pomodoro.** Short, Standard, and Deep modes set the initial session length, which you can adjust to suit the task and your pace. Switch tasks during a session without resetting the timer.
- **Tasks, Areas, and Projects.** Areas organize ongoing parts of your life, such as work or study. Projects group related tasks around a finite goal within an Area. Tasks can have a scheduled time and a reminder.
- **Habits.** Set up a Habit with a schedule and goal for an Area or Project. Tasks are created automatically, and statistics help you track consistency and completion, including partial progress.
- **Quick task capture.** Write down a new task without a lengthy interruption to your work.
- **History and Statistics.** A timeline of Flow sessions and breaks shows how your day went. Daily, weekly, monthly, and yearly statistics reveal where your time goes across Tasks, Areas, and Projects.
- **iCloud sync.** Data is stored locally and syncs through your private iCloud database. No ThruFlow account is needed.
- **Apple device features.** Widgets for iPhone and Mac, Live Activity, Dynamic Island, and an Apple Watch companion app.

## Getting started

1. Install ThruFlow from the App Store.
2. Create an Area, such as Work or Study, and add your first task. You can create a Project later when you need to group tasks around a shared goal.
3. Select a task on the Flow screen and start the timer. Adjust the duration and switch tasks as you work.
4. When you decide to take a break, record your result or continue without a note, then start the break.
5. Check History and Statistics to review your progress. For regular activities, set up a Habit with a schedule and goal.

The basic workflow:

```text
Area -> Task -> Flow session -> focused time -> progress -> statistics
```

## Connectors

Available on Mac, iPhone, and iPad:

- **Apple Reminders** — import unfinished tasks from selected lists.
- **Todoist** — import unfinished tasks from selected projects.
- **Toggl Track** — send completed focus time to mapped Toggl projects from the device that recorded it.

For Reminders and Todoist, completing and reopening checkbox tasks syncs both ways. Todoist and Toggl credentials are stored in the device's Keychain.

Connectors are in beta. See the [connector guide](docs/CONNECTORS.md) for setup and limitations.

## About the project

This is a personal side project I am building for myself and my Apple devices. Existing Pomodoro apps either did not offer the experience I wanted or required payment. So I decided to build my own free, open-source tool for working at a comfortable pace, taking breaks, and maintaining habits.

The project was built from scratch, without basing it on another project or using reverse engineering. I define the idea, interface, and direction of development. Coding, localization, and testing are automated with AI agents.

## Building from source

Local development uses Xcode 27.1. The app uses Apple system frameworks, with no third-party runtime dependencies.

1. Clone the repository and open `ThruFlow.xcodeproj` in Xcode.
2. Select the `ThruFlow`, `ThruFlow iOS`, or `ThruFlow Watch` scheme.
3. To run locally without CloudKit, add the `--local-store` launch argument or set `THRUFLOW_DISABLE_CLOUDKIT=1`.
4. For a signed iCloud build, configure your own Development Team, bundle identifiers, App Group, and CloudKit container using your Apple Developer account.

Test commands are in the [contribution guide](CONTRIBUTING.md), and Release build commands are in the [release guide](docs/RELEASE.md). See the [CloudKit guide](docs/CLOUDKIT.md) for synchronization checks.

Changes go through CI, and the `main` branch is protected. [Automated TestFlight delivery](docs/TESTFLIGHT.md) uploads builds to App Store Connect; publication requires separate verification and Apple review.

## Support and contributions

Report reproducible bugs and suggestions through [GitHub Issues](https://github.com/shigorefu/thruflow/issues/new/choose). See [Support](SUPPORT.md) for other ways to get help and the [security policy](SECURITY.md) for reporting vulnerabilities.

To help with code, translations, or documentation, start with the [contribution guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md). Discuss substantial changes in a GitHub issue first. Contributors and attribution are listed in [CONTRIBUTORS.md](CONTRIBUTORS.md).

Development branches may contain unreleased changes. Back up important data before testing them.

## Documentation

Technical documentation is maintained in English. Start with the [documentation index](docs/README.md).

- [UX flows](docs/UX_FLOWS.md) — screens and workflows.
- [Product overview](docs/PRODUCT.md) — features and app behavior.
- [Architecture](docs/ARCHITECTURE.md) — project structure for developers.
- [Roadmap](docs/ROADMAP.md) and [changelog](CHANGELOG.md).
- [Privacy policy](PRIVACY.md).

## License

Unless otherwise noted, original repository content is available under [AGPL-3.0-or-later](LICENSE). Official TestFlight and App Store binaries are distributed separately under Apple's applicable terms, and incoming contributions are accepted under BSD-3-Clause. See the [licensing policy](LICENSING.md) for details.
