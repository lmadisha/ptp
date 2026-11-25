# Architecture Decision Records

One file per significant decision. Never edit an accepted ADR's decision. Write a new ADR that supersedes it.

| # | Title | Status |
|---|---|---|
| [0001](0001-no-programmatic-lock.md) | Replace "force lock" with a guided Mark as Lost | Accepted |
| [0002](0002-local-only-data.md) | No backend; all data stays on the device | Accepted |
| [0003](0003-occasion-based-arming.md) | Arm for occasions, not all day | Accepted |
| [0004](0004-detection-uwb-plus-ble.md) | Detect with UWB distance plus a Bluetooth heartbeat | Proposed |
| [0005](0005-sqlite-for-on-device-data.md) | Store on-device data in SQLite, not SwiftData | Accepted |
| [0006](0006-test-build-reading-log.md) | Keep a reading log on each device in test builds | Proposed |
| [0007](0007-state-machine-signal-rules.md) | How the state machine treats signal loss and UWB dropouts | Proposed |
| [0008](0008-watch-owns-session-state.md) | The watch owns the session state; the iPhone mirrors it | Proposed |
| [0009](0009-signal-strength-without-uwb.md) | Judge by the heartbeat's signal strength when there is no UWB distance | Proposed |
| [0010](0010-place-visits-as-rounded-cells.md) | Learn places as rounded grid cells, one row per visit day | Proposed |
| [0011](0011-new-area-prompt-via-notification.md) | The new-area prompt is an iPhone notification the watch answers | Proposed |
| [0012](0012-risky-and-safe-places.md) | Risky and safe places are marked where you stand and watched with CLMonitor | Proposed |

## Template
```markdown
# ADR-NNNN: <decision as a short statement>

- **Status:** Proposed | Accepted | Superseded by ADR-NNNN
- **Date:** YYYY-MM-DD

## Context
## Decision
## Consequences
```
