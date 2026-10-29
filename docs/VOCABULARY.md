# Vocabulary

| Term | Meaning |
| --- | --- |
| Area | An ongoing responsibility; types are Anytime, Habit and Optional. |
| Project | An optional finite goal within one Area. |
| Task | A dated or undated work item; the implementation type is `Todo`. |
| Habit | A recurring goal owned by an Area or Project, producing separate Task occurrences. |
| Flow | The focus workspace, or a recorded session when used in History. |
| Focus | The act or duration of working, excluding breaks. |
| Focus Block | 25 focused minutes; 12 minutes are presented as half a Block. |
| Short / Standard / Deep | Visible mode names; stable code values remain `Sprint` / `Focus` / `Deep`. |
| Focus Calendar | The daily grid visualization; legacy source key `Dots`. |
| Other | The system Area with stable role `taskInbox`. |

Use singular entity names in editors and plural names for collection navigation.
Translate each UI context rather than substituting one term globally.

[Domain model](DOMAIN_MODEL.md) owns behavior. [Data model](DATA_MODEL.md) owns
storage compatibility, including the legacy `Direction` entity and `direction`
relationship behind `Area` APIs. The multilingual translation glossary lives only
in [TERMS.csv](../Localisation/TERMS.csv); do not duplicate it in prose documents.
