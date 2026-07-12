# ThruFlow

ThruFlow / スルフロ is an Apple-first productivity app for turning focused work into task progress.

Core loop:

```text
方向 -> Task -> Flow -> actual focused time -> progress -> statistics
```

The product is not a Pomodoro clone, a standalone habit tracker, or a generic Todo list.

## Current Product Model

- `方向`: persistent activity area.
- `通常`: normal area.
- `習慣`: scheduled recurring requirement.
- `ナイス`: optional positive activity.
- `その他`: system Direction for work without a chosen Direction. It is hidden from Direction editing but can appear in task context and statistics.
- `Task`: daily or Inbox item.
- `Flow`: media-player-like focused-work recorder.
- `Flow dashboard`: the first screen, with the expanded player, animated daily stream, totals, and a 24-hour Flow timeline.
- `メモ`: stored on Todo.
- `統計`: contribution-style grid for Tasks and Flow.
- `履歴`: day timeline and Task/Direction summaries, available directly below `タスク` and from statistics cells.

## Platforms

The app is being built for Apple platforms, with current hands-on work focused on macOS while keeping iPhone/iPad compatibility in mind.

Default user-facing language is Japanese. Code identifiers and enum raw values stay in English.

## Technology

- Swift
- SwiftUI
- SwiftData
- Swift Testing
- Apple system frameworks
- Offline-first local storage

No third-party dependencies are used in the MVP.

## Documentation

- [Concept](CONCEPT.md)
- [Product](docs/PRODUCT.md)
- [Domain Model](docs/DOMAIN_MODEL.md)
- [UX Flows](docs/UX_FLOWS.md)
- [Technical Plan](docs/TECHNICAL_PLAN.md)
- [MVP](docs/MVP.md)
- [Roadmap](docs/ROADMAP.md)
- [Decisions](docs/DECISIONS.md)
- [Japanese Vocabulary](docs/VOCABULARY.md)
