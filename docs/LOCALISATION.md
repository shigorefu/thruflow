# Localisation Architecture

## Source of Truth

`ThruFlow/Localisation/Localizable.xcstrings` owns in-app user-facing copy.
`ThruFlow/Localisation/InfoPlist.xcstrings` owns the system-visible application
name used below the icon and in the macOS menu bar, plus system permission text.
Japanese is the development
and fallback language. The catalogs are part of the application targets and use
Apple's String Catalog format so macOS, iOS/iPadOS, and watchOS share
translations without sharing screen layouts.

The system-visible application name is `スルフロ` in Japanese and `ThruFlow`
in English, Russian, and both Chinese variants. This localization does not change
bundle identifiers,
persisted values, or the separately maintained App Store product name.

The maintained application locales are Japanese (`ja`), English (`en`),
Russian (`ru`), Simplified Chinese (`zh-Hans`), and Traditional Chinese
(`zh-Hant`). Both catalogs require complete translations for every non-source
locale before localisation tests pass. Chinese support is part of 1.4.0.
Settings preserves complete locale identifiers so the two scripts remain
separately selectable on Mac and iPhone/iPad. Changes apply after restarting;
Watch and widgets use their system/bundle language selection.
When either Chinese variant is selected (including via the system language),
Mac and iPhone/iPad Settings show a small AI translation notice and a support
link below the language picker. The notice follows the selection immediately;
the interface language itself still requires a restart.

Approved Chinese terminology is recorded in `Localisation/TERMS.csv`.
User-authored data and quick-input syntax are unchanged.

## Code Rules

- SwiftUI literals and `String(localized:)` are extracted into the catalog.
- Strings returned by domain display helpers, validation, notifications, and
  application state must use `String(localized:)` explicitly.
- Persisted raw values, stable identifiers, SF Symbol names, asset names, and
  user-authored or persisted content are never localization keys.
- Dynamic sentences are localized as one interpolation-aware resource. Do not
  concatenate translated sentence fragments.
- Dates and times use locale-aware Foundation format styles where possible.
- Month pickers use Foundation standalone month names with the UI locale and
  calendar (for example, `January` or Russian `январь`), not translated numeric
  month templates. Accessibility labels format the month and year together with
  the same locale, calendar and time zone.

The catalog currently uses source-text keys, matching Apple's extraction model.
This keeps existing Japanese product terminology visible to translators while
Xcode preserves placeholder type information and generates compile-time string
symbols. Renaming a source key is a product-copy migration and should be
reviewed like an API rename.

## Product terminology

Use [Vocabulary](VOCABULARY.md) for English product concepts and
[TERMS.csv](../Localisation/TERMS.csv) for exact source keys and approved
translations. Context matters: the Flow workspace, a saved Flow record, a focus
action and a session count are different meanings. Use collection plurals in
navigation and singular entity names in editors.

Translation changes never rename stored identifiers, user content or enum values.
Do not promise automatic break transitions, credit for the onboarding demo,
end-to-end encryption, required iCloud, or that every future integration is free.
See [Product](PRODUCT.md) for the actual product scope and [Privacy](../PRIVACY.md)
for data handling.

## Contributor Workflow

The non-programmer workflow is documented in `Localisation/README.md`. A new
language is added in Xcode's String Catalog editor, the project localizations,
the glossary, and the localization tests. It requires no SwiftData changes.
Local SwiftData remains independent of the selected locale.

Xcode may update the catalog automatically while extracting SwiftUI and
accessibility strings. Review those diffs against the originating Swift code:
empty keys indicate an extraction bug, obsolete `stale` entries should be
removed when no source still references them, and dynamic placeholders must use
translator-readable source keys with complete values for every supported locale.

`Localisation/TERMS.csv` is the contributor-facing terminology glossary. Its
first two columns are English metadata, its third column contains the actual
Japanese String Catalog source key, and its final columns contain approved
English, Russian, Simplified Chinese, and Traditional Chinese UI translations.
A source key can intentionally have a
different Japanese catalog override; translators must not expose technical or
legacy source-key wording to users. The CSV is not loaded at runtime and
therefore cannot diverge application behavior from the validated String
Catalog. Unambiguous glossary terms are checked against the catalog by unit
tests.

Task quick-input aliases are domain syntax rather than translated UI strings.
English forms (`b`, `m`, `high`, `today`, weekday names, and related short forms)
must remain available under every app locale. Japanese and Russian forms are
additive aliases defined by the shared quick-input parser and its tests; translators must not replace
or remove the universal English forms.

Literal `String(localized:)` keys are also checked against the catalog by
`LocalisationTests`, so a source key cannot silently fall back to Japanese
because its translation in a supported locale is missing. During SDK upgrades,
compare the compiler-generated `.stringsdata` from both macOS and iOS/Watch builds with
the catalog as well; this includes interpolated keys. Review Japanese entries
marked `new` and mark them translated only after checking their actual copy.


## Localization agent review

The orchestrator assigns a dedicated localization agent when app copy changes,
as required by [AGENTS.md](../AGENTS.md#localization-agent). It reviews affected
copy in Japanese, English, Russian, Simplified Chinese and Traditional Chinese
for natural, context-appropriate wording and can correct translations directly.
All catalog/glossary writes have a single assigned owner. Preserve source keys,
format arguments, plural forms and product terminology; check short labels and
accessibility text as well as explanations. Report actual language coverage and
separate linguistic source review from visual checks on each device.
