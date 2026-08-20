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

Product terminology is translated by UI meaning, not by replacing an English
domain word everywhere. The Japanese source key may also differ from the text
shown in Japanese when a catalog override exists. In particular, `Flow` has no
single canonical rendering:

| UI context | Source key | Japanese UI | English UI | Russian UI |
| --- | --- | --- | --- | --- |
| Main Flow navigation and workspace | `Flow` | `流れ` | Flow | Flow |
| Persisted Flow session or History record | `集中記録` | `集中記録` | Flow | Flow |
| Start, continue, or switch focused work | `集中` | `集中` | Focus | Фокус |
| Number of recorded Flow sessions | `集中回数` | `集中回数` | Flows | Сессии Flow |
| Statistics focus / Task switch | `集中` / `タスク` | `集中` / `タスク` | Focus / Tasks | Фокус / Задачи |
| Flow mode selector | `Flowタイプ` or `集中モード` | `集中モード` | Flow Mode | Режим Flow |
| Short / Standard / Deep / Auto mode | `Sprint` / `Focus` / `Deep` / `オート` | `短め` / `標準` / `じっくり` / `自動` | Short / Standard / Deep / Auto | Короткий / Обычный / Глубокий / Авто |
| Focus Block name / goal unit | `集中ブロック` / `フローブロック` | `集中ブロック` | Focus Blocks | Блоки фокуса |
| Focus Calendar visualization | `Dots` | `集中カレンダー` | Focus Calendar | Календарь фокуса |

For example, an action should read `集中を始める`, not a mechanical
`流れを開始`. A History row should use `集中記録`, while the main workspace may
use `流れ`. Translators must inspect the originating screen and choose the
contextual term recorded in `Localisation/TERMS.csv`.

The persistent activity-area entity is `分野` in Japanese UI, `Area` in English,
and `Сфера` in Russian. Collection navigation uses `Areas` and `Сферы`. Its
visible types are `いつでも` / Anytime / В любое время,
`習慣` / Habit / Привычка, and `できたら` / Optional / Если получится. The
corresponding source keys remain `通常`, `習慣`, and `ナイス`. Other
context-sensitive terms include `日付なし` for the Inbox projection, `週に数回`
for the weekly-count Habit schedule, and `集中カレンダー` / Focus Calendar /
Календарь фокуса for the calendar-style focus visualization.

Version 1.0.2 onboarding has eight semantic steps: Welcome, Area, Task, Flow,
the transient Flow preview, History, Statistics, and the final workflow summary.
The preview shows only a circular timer that rapidly counts a Short focus
interval from `12:00` to `00:00`, then switches to the regular break at `03:00`.
Translations must not imply that this displayed time becomes real progress or a
persisted record. Translations should describe the loop naturally rather than
mirror Japanese sentence structure. The privacy step may say that records are
stored on the device and, when iCloud is enabled, synchronize through the user's
private CloudKit database. It may also say that
ThruFlow does not send Tasks or History to a developer-operated server. It must
not claim end-to-end encryption, anonymity, that Apple never processes the
records, or that iCloud is required.

Onboarding and product copy may promise that Tasks, the Flow focus timer,
History, and Statistics are free and ad-free and require no payment. It must not
expand that statement into a promise that every current or future feature will
always be free: possible future optional integrations or services may have
separate terms or costs. Coffee and Ramen remain optional tips, not subscriptions,
and unlock no functionality.

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
first two columns are English metadata, its third column contains the actual
Japanese String Catalog source key, and its final columns contain approved
English and Russian UI translations. A source key can intentionally have a
different Japanese catalog override; translators must not expose technical or
legacy source-key wording to users. The CSV is not loaded at runtime and
therefore cannot diverge application behavior from the validated String
Catalog. Unambiguous glossary terms are checked against the catalog by unit
tests.

Task quick-input aliases are domain syntax rather than translated UI strings.
English forms (`b`, `m`, `high`, `today`, weekday names, and related short forms)
must remain available under every app locale. Japanese and Russian forms are
additive aliases documented in `docs/UX_FLOWS.md`; translators must not replace
or remove the universal English forms.

## Context-Specific Labels

Entity names remain singular in prose and editors (`Task`, `Area`), while
navigation labels name collections and therefore use plurals. `Direction`
remains the internal Swift, persistence, and machine-readable CSV identifier;
it is not visible English UI copy:

| Context | Japanese key | English | Russian |
| --- | --- | --- | --- |
| Tasks navigation | `タスク` | Tasks | Задачи |
| Task field or picker | `対象タスク` | Task | Задача |
| Areas navigation | `方向` | Areas | Сферы |
| Area field or picker | `分野` | Area | Сфера |
| Main Flow navigation | `Flow` | Flow | Flow |
| Saved Flow session | `集中記録` | Flow | Flow |
| Flow count | `集中回数` | Flows | Сессии Flow |
| Flow mode selector | `集中モード` | Flow Mode | Режим Flow |
| Short / Standard / Deep / Auto modes | `Sprint` / `Focus` / `Deep` / `オート` | Short / Standard / Deep / Auto | Короткий / Обычный / Глубокий / Авто |
| Statistics focus mode | `集中` | Focus | Фокус |
| Statistics Task mode | `タスク` | Tasks | Задачи |
| Statistics completed-task count | `達成` | Tasks | Задачи |
| Focus Calendar | `Dots` | Focus Calendar | Календарь фокуса |
| Current year period | `今年` | This Year | Этот год |
| Current month period | `今月` | This Month | Этот месяц |

Translators must use the UI context from `Localisation/TERMS.csv`; identical
Japanese wording does not imply that English and Russian should use a singular
entity label in collection navigation. Likewise, English `Area` and Russian
`Сфера` are independent idiomatic choices; neither should be translated
mechanically from the other language.
