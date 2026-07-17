# ThruFlow Localisation

The application catalog is
[`ThruFlow/Localisation/Localizable.xcstrings`](../ThruFlow/Localisation/Localizable.xcstrings).
It is the single source of truth for user-facing text. Japanese (`ja`) is the
source and fallback language.

## Add a language without changing Swift code

1. Open `ThruFlow/Localisation/Localizable.xcstrings` in Xcode.
2. Choose `Editor` -> `New Localization`.
3. Select the language.
4. Translate the `String` column. Do not edit the source key.
5. Preserve placeholders such as `%lld`, `%@`, and `%1$@`. Xcode validates
   placeholder types and plural variants.
6. Select the language in the app scheme and build the macOS app for review.

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
