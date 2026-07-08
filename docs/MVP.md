# MVP 0.1

MVP 0.1 proves the core ThruFlow loop with local SwiftData storage.

## Included

### Direction

- create;
- edit;
- archive;
- list;
- type: Must, Neutral, Bonus;
- color or symbol;
- optional goal.

### Todo

- create;
- choose Direction;
- checkbox or target blocks;
- show on Today;
- change status;
- reschedule;
- archive or delete.

### Basic Flow

- choose Direction;
- choose Todo when available;
- enter Intent;
- modes: 12/3, 25/5, 50/10;
- Start, Pause, Resume, Finish;
- save FlowSession;
- add Result after completion.

Local notifications can be deferred.

### Adaptive Flow

- starts at 12 minutes;
- can extend by 13 minutes to 25;
- can extend by 25 minutes to 50;
- keeps one FlowSession.

### Today

- Must Directions;
- manual Todos;
- Bonus items;
- progress;
- successful day calculation.

### History

- FlowSession list;
- time;
- Direction;
- Todo;
- Intent;
- Result;
- actual duration.

### Tests

- progress calculation;
- daily goal;
- weekly goal;
- Adaptive Flow transitions;
- timer restoration;
- Day Completion event rules.

## Excluded

- AI;
- AWS;
- full Timeline editor;
- Apple Watch;
- WidgetKit;
- Live Activities;
- social features;
- accounts;
- subscriptions;
- payments;
- complicated analytics;
- gamification store;
- public profiles;
- distributed active timer sync.

## Success Criteria

The MVP is successful when a user can:

1. Create Directions with required and optional goals.
2. Create Todos under Directions.
3. See a Today plan.
4. Run and finish Flow sessions.
5. Record what actually happened.
6. See basic history.
7. Complete a day when Must requirements are satisfied.

