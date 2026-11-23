# Architecture Decision Records

One file per significant decision. Never edit an accepted ADR's decision. Write a new ADR that supersedes it.

| # | Title | Status |
|---|---|---|
| [0001](0001-no-programmatic-lock.md) | Replace "force lock" with a guided Mark as Lost | Accepted |
| [0002](0002-local-only-data.md) | No backend; all data stays on the device | Accepted |
| [0003](0003-occasion-based-arming.md) | Arm for occasions, not all day | Accepted |
| [0004](0004-detection-uwb-plus-ble.md) | Detect with UWB distance plus a Bluetooth heartbeat | Proposed |
| [0005](0005-sqlite-for-on-device-data.md) | Store on-device data in SQLite, not SwiftData | Proposed |

## Template
```markdown
# ADR-NNNN: <decision as a short statement>

- **Status:** Proposed | Accepted | Superseded by ADR-NNNN
- **Date:** YYYY-MM-DD

## Context
## Decision
## Consequences
```
