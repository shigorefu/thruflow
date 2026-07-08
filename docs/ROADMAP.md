# Roadmap

## Stage 0: Analysis and Documentation

Status: complete in this documentation pass.

Deliverables:

- README;
- AGENTS;
- product model;
- domain model;
- UX flows;
- technical plan;
- MVP scope;
- roadmap;
- decisions.

## Stage 1: Template Cleanup

Status: implemented by replacing the template `Item` model with the Direction schema and UI entry point.

## Stage 2: Direction Vertical Slice

Status: implemented as the first vertical slice; build/test verification remains part of each follow-up change.

Included:

- SwiftData Direction model.
- Stable enums for Direction type, goal period, and goal unit.
- Direction list.
- Create and edit form.
- Validation.
- Archive action.
- Swift Testing coverage.

## Stage 3: Todo Vertical Slice

Status: in progress.

Included in the first pass:

- SwiftData Todo model.
- Direction relationship.
- Today list integration.
- Checkbox, block, and minute target progress.
- Create, edit, and archive support.
- Tests.

## Stage 4: Basic Flow

Status: first vertical slice implemented.

Included:

- FlowSession model.
- Timer state machine.
- Start, pause, resume, finish.
- Intent and Result capture.
- Persistence.
- Bottom mini-player shell.
- Tests.

## Stage 5: Adaptive Flow

Status: domain logic implemented; UI decision controls are in the mini-player.

Included:

- 12 to 25 to 50 minute transition logic.
- One timer/session state across extensions.
- Transition tests.
- Timer restoration after app backgrounding.

## Stage 6: Must Goals and Today Completion

- Daily goals.
- Weekly goals.
- Deterministic Today inclusion.
- DailyCompletion event.
- Simple reward placeholder.
- Tests.

## Stage 7: History and Basic Statistics

- Flow history.
- Total focus duration.
- Direction totals.
- Todo progress.

## Stage 8: Polish

- accessibility pass;
- localization readiness;
- empty states;
- error states;
- Dark Mode review;
- macOS compatibility check.

## Later

- Continuous Timeline editor.
- Contribution grid for Direction progress.
- Rich statistics.
- AI summaries and suggestions.
- CloudKit sync across iPhone, iPad, and Mac.
- Active Flow visibility across devices.
- Apple Watch, widgets, Live Activities, and Shortcuts.
- ActivityKit Widget Extension and Dynamic Island UI for Flow.
- Web client and AWS backend only if later explicitly required.
