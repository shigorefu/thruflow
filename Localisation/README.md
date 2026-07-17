# ThruFlow Localisation

The application catalog is
[`ThruFlow/Localisation/Localizable.xcstrings`](../ThruFlow/Localisation/Localizable.xcstrings).
It is the single source of truth for user-facing text. Japanese (`ja`) is the
source and fallback language.

[`TERMS.csv`](TERMS.csv) is the shared product glossary. It maps stable code
names to their meaning and approved terminology in Japanese, English, and
Russian. The CSV helps translators stay consistent; the runtime source of truth
remains `Localizable.xcstrings`.

## Add a language without changing Swift code

1. Open `ThruFlow/Localisation/Localizable.xcstrings` in Xcode.
2. Choose `Editor` -> `New Localization`.
3. Select the language.
4. Translate the `String` column. Do not edit the source key.
5. Preserve placeholders such as `%lld`, `%@`, and `%1$@`. Xcode validates
   placeholder types and plural variants.
6. Select the language in the app scheme and build the macOS app for review.

## Contribute a language through GitHub

1. Fork the repository and create a branch named `localisation/<language-code>`.
2. Add a column named with the language code to `TERMS.csv`, for example `DE`
   or `UK`, and translate every terminology row.
3. Add the same language to `Localizable.xcstrings` in Xcode and translate the
   catalog entries. The CSV alone does not change text in the application.
4. Do not rename programming identifiers in the first CSV column or source
   keys in the String Catalog.
5. Open a pull request and state which locale and regional variant you tested.

GitHub's web editor can edit `TERMS.csv` directly. Translators who do not use
Xcode may submit the completed CSV column first; a maintainer can then import
the approved terminology into the String Catalog in a follow-up commit.

Do not translate persisted enum raw values, SwiftData identifiers, SF Symbol
names, notification identifiers, or accessibility identifiers. They are code
and storage contracts rather than user-facing copy. Date and time patterns are
locale-aware in code and are intentionally absent from the catalog.

## Add or change product text

- Use SwiftUI localizable initializers or `String(localized:)`.
- Never assemble a translated sentence from separately translated fragments.
- Add translator context in the catalog comment when the meaning is ambiguous.
- Prefer locale-aware `Date.FormatStyle`, `Measurement`, and plural variations.
- Build the app before committing so Xcode can validate placeholders.
