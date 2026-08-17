# Localisation Architecture

## Source of Truth

`ThruFlow/Localisation/Localizable.xcstrings` owns all user-facing copy.
Japanese is the development and fallback language. The catalog is part of the
application target and uses Apple's String Catalog format so macOS and
iOS/iPadOS presentation layers share translations without sharing screen
layouts.

The maintained application locales are Japanese (`ja`), English (`en`), and
Russian (`ru`). Every catalog entry must contain complete English and Russian
translations before the localisation tests pass.

## Code Rules

- SwiftUI literals and `String(localized:)` are extracted into the catalog.
- Strings returned by domain display helpers, validation, notifications, and
  application state must use `String(localized:)` explicitly.
- Persisted raw values, stable identifiers, SF Symbol names, asset names, and
  user-authored or persisted content are never localization keys.
- Dynamic sentences are localized as one interpolation-aware resource. Do not
  concatenate translated sentence fragments.
- Dates and times use locale-aware Foundation format styles where possible.

The catalog currently uses source-text keys, matching Apple's extraction model.
This keeps existing Japanese product terminology visible to translators while
Xcode preserves placeholder type information and generates compile-time string
symbols. Renaming a source key is a product-copy migration and should be
reviewed like an API rename.

## Product Terminology and Context

Japanese product terminology is translated by UI meaning, not by replacing an
English domain word everywhere. In particular, `Flow` has no single canonical
Japanese rendering:

| UI context | Japanese |
| --- | --- |
| Main Flow navigation and workspace | `流れ` |
| Persisted Flow session or History record | `集中記録` |
| Start, continue, or switch focused work | `集中` |
| Number of recorded Flow sessions | `集中回数` |
| Statistics focus / Task switch | `集中` / `タスク` |
| Flow mode selector | `集中モード` |
| Sprint / Focus / Deep / Adaptive mode | `短め` / `標準` / `じっくり` / `自動` |
| Focus Block name / short unit | `集中ブロック` / `ブロック` |
| Dots visualization | `集中カレンダー` |

For example, an action should read `集中を始める`, not a mechanical
`流れを開始`. A History row should use `集中記録`, while the main workspace may
use `流れ`. Translators must inspect the originating screen and choose the
contextual term recorded in `Localisation/TERMS.csv`.

The persistent activity-area entity is `分野` in Japanese UI. Its visible types
are `いつでも`, `習慣`, and `できたら`. Other context-sensitive terms include
`日付なし` for the Inbox projection, `週に数回` for the weekly-count Habit
schedule, and `集中カレンダー` for Dots.

These copy choices never rename implementation or persisted identifiers.
Swift types and properties such as `Direction`, `FlowSession`, and `FlowMode`,
enum cases, raw values, storage keys, and stable code references remain in
English. A terminology update must not migrate user data or user-authored
content.

## Contributor Workflow

The non-programmer workflow is documented in `Localisation/README.md`. A new
language is added in Xcode's String Catalog editor and requires no Swift or
SwiftData changes. Local SwiftData remains independent of the selected locale.

Xcode may update the catalog automatically while extracting SwiftUI and
accessibility strings. Review those diffs against the originating Swift code:
empty keys indicate an extraction bug, obsolete `stale` entries should be
removed when no source still references them, and dynamic placeholders must use
translator-readable source keys with complete `ja`, `en`, and `ru` values.

`Localisation/TERMS.csv` is the contributor-facing terminology glossary. Its
first column contains stable code references, while language columns contain
approved translations. It is intentionally not loaded at runtime and therefore
cannot diverge application behavior from the validated String Catalog.
Unambiguous glossary terms are checked against the catalog by unit tests.

Task quick-input aliases are domain syntax rather than translated UI strings.
English forms (`b`, `m`, `high`, `today`, weekday names, and related short forms)
must remain available under every app locale. Japanese and Russian forms are
additive aliases documented in `docs/UX_FLOWS.md`; translators must not replace
or remove the universal English forms.

## Context-Specific Labels

Entity names remain singular in prose and editors (`Task`, `Direction`), while
navigation labels name collections and therefore use plurals:

| Context | Japanese key | English | Russian |
| --- | --- | --- | --- |
| Tasks navigation | `タスク` | Tasks | Задачи |
| Directions navigation | `分野` | Directions | Направления |
| Main Flow navigation | `流れ` | Flow | Flow |
| Saved Flow session | `集中記録` | Flow | Flow |
| Flow count | `集中回数` | Flows | Сессии Flow |
| Flow mode selector | `集中モード` | Flow Mode | Режим Flow |
| Statistics focus mode | `集中` | Focus | Фокус |
| Statistics Task mode | `タスク` | Tasks | Задачи |
| Statistics completed-task count | `達成` | Tasks | Задачи |
| Current year period | `今年` | this year | Этот год |
| Current month period | `今月` | This month | Этот месяц |

Translators must use the UI context from `Localisation/TERMS.csv`; identical
Japanese wording does not imply that English and Russian should use a singular
entity label in collection navigation.
