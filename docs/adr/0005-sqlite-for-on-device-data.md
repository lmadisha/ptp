# ADR-0005: Store on-device data in SQLite, not SwiftData

- **Status:** Proposed
- **Date:** 2026-11-23

## Context
ADR-0002 keeps all data on the device and named SwiftData for the place areas and the alarm log. The owner asked to use SQLite instead. No store code exists yet (the stores are Phase 1.3 and 2.1), so switching now costs nothing.

These stores need:
- simple tables: places with visit counts, and an alarm log;
- age-based deletion (60 days for places, about 30 days for the log);
- encryption while the phone is locked;
- unit tests without a device.

## Decision
- Use **SQLite through the system `SQLite3` library** (`import SQLite3`, which links `libsqlite3`). No third-party package, which keeps hard rule 1 and the supply chain simple.
- Put the stores in a small pure-Swift package, **`Packages/PTPStore`**, kept separate from `PTPCore`. It has:
  - a thin wrapper (open, execute, query, transaction);
  - one schema with a `PRAGMA user_version` migration step;
  - `PlaceStore` and `AlarmLog` types.
  `PTPStore` takes its retention values from `DetectionConfig`, or a sibling config type, never hard-coded (hard rule 4).
- **One database file** in the app's container, on the iPhone only:
  - created with file protection `.completeUntilFirstUserAuthentication`, so background arming can still write while locked;
  - excluded from iCloud backup.
- **Retention** is enforced with `DELETE … WHERE created_at < ?` at app start and after each write.
- **Tests** use an in-memory database (`:memory:`) with an injected clock. No `Date()` in tests.
- Settings stay in app-group key-value storage, as ADR-0002 says.

## Consequences
- Explicit schema and SQL: easy to audit for privacy, and retention is one statement.
- We write and maintain migrations and the wrapper ourselves. SwiftData would have generated them.
- No SwiftUI `@Query` convenience; views read through the store types.
- `.completeUntilFirstUserAuthentication` is weaker than `.complete`. It's needed because the app writes while locked in the background. Revisit if writes can be deferred until unlock.
- Revisit if the schema grows past a handful of tables, or if CloudKit sync is ever wanted. Either would need a new ADR anyway, because of ADR-0002.
