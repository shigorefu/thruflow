# Documentation

Documentation describes the 1.4.0 implementation. Both 1.4.0 (14) builds were
submitted to App Review on 2026-10-29; publication is not yet confirmed.
See [Release](RELEASE.md) for evidence and outstanding device checks.

The root [English](../README.md) and [Japanese](../README.ja.md) READMEs are
public introductions. All other documentation is maintained in English.
Localized source keys, stored identifiers and translation resources retain their
original spelling; documentation cleanup must not rename those contracts.

## Find the owning document

| Question | Source of truth |
| --- | --- |
| What does the app do? | [Product](PRODUCT.md) |
| How do I use each screen? | [UX flows](UX_FLOWS.md) |
| What do product terms mean? | [Vocabulary](VOCABULARY.md) |
| How do Tasks, Habits and timers behave? | [Domain model](DOMAIN_MODEL.md) |
| Where does code belong? | [Architecture](ARCHITECTURE.md) |
| Which fields and identities must stay compatible? | [Data model](DATA_MODEL.md) |
| How does iCloud work, and what is deployed? | [CloudKit](CLOUDKIT.md) |
| How are external services connected? | [Connectors](CONNECTORS.md), [artwork provenance](CONNECTOR_ASSETS.md) |
| How are translations maintained? | [Localization](LOCALISATION.md) |
| How do I test with isolated data? | [Development and QA](TECHNICAL_PLAN.md) |
| How do builds reach Apple? | [Release](RELEASE.md), [TestFlight](TESTFLIGHT.md) |
| What changed or is planned? | [Changelog](../CHANGELOG.md), [Roadmap](ROADMAP.md) |
| Why were earlier choices made? | [Decisions](DECISIONS.md) |

## Maintenance

Update the owning specification when behavior changes; link to it elsewhere
instead of duplicating its rules. Decisions retain historical rationale, while
later accepted decisions and current specifications take precedence. Release
notes describe user-facing changes; dated operational evidence belongs in Release
and CloudKit. Git history preserves retired plans and old verification logs.

Contributor policies live at the repository root. AI operating instructions
live only in [AGENTS.md](../AGENTS.md).
