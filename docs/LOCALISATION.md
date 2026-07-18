# Localisation Architecture

## Source of Truth

`ThruFlow/Localisation/Localizable.xcstrings` owns all user-facing copy.
Japanese is the development and fallback language. The catalog is part of the
application target and uses Apple's String Catalog format so macOS and future
iOS presentation layers share translations without sharing screen layouts.

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

## Contributor Workflow

The non-programmer workflow is documented in `Localisation/README.md`. A new
language is added in Xcode's String Catalog editor and requires no Swift or
SwiftData changes. Local SwiftData remains independent of the selected locale.

`Localisation/TERMS.csv` is the contributor-facing terminology glossary. Its
first column contains stable code references, while language columns contain
approved translations. It is intentionally not loaded at runtime and therefore
cannot diverge application behavior from the validated String Catalog.
Unambiguous glossary terms are checked against the catalog by unit tests.

## Context-Specific Labels

Entity names remain singular in prose and editors (`Task`, `Direction`), while
navigation labels name collections and therefore use plurals:

| Context | Japanese key | English | Russian |
| --- | --- | --- | --- |
| Tasks navigation | `タスク` | Tasks | Задачи |
| Directions navigation | `方向` | Directions | Направления |
| Statistics completed-task count | `達成` | Tasks | Задачи |
| Current year period | `今年` | this year | Этот год |
| Current month period | `今月` | This month | Этот месяц |

Translators must use the UI context from `Localisation/TERMS.csv`; identical
Japanese wording does not imply that English and Russian should use a singular
entity label in collection navigation.
