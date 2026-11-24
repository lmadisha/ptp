# Testing

Three layers of testing:
- **Unit tests** for logic.
- **Trace replay** for detection.
- **Field drills** for the real world.

## 1. Unit tests (`PTPCore`)
- Run: `swift test --package-path Packages/PTPCore`
- Cover every state-machine transition in [ARCHITECTURE.md](ARCHITECTURE.md), with its timing.
- Use an injected clock. Never call `Date()` or sleep in tests.

## 2. Trace replay
Recorded distance logs from real devices live in `Packages/PTPCore/Tests/Fixtures/`. Each trace is a CSV with these columns: `t_ms, distance_m, source, app_state, battery_pct, rssi_dbm`.

Each trace has an expected outcome:

| Trace | Expected |
|---|---|
| `table-walk-away.csv` | Warning, then Alarm |
| `snatch-run.csv` | Alarm within 5 s of separation |
| `pocket-crowd.csv` | No Alarm (at most one Warning) |
| `airplane-mode.csv` | Alarm 3 s after the last signal (the app notices it up to one `tickInterval`, 0.5 s, later) |
| `bag-noise.csv` | No Alarm |

**Rules:**
- Any change to `DetectionConfig` must keep all traces passing.
- A new false alarm found in beta becomes a new trace.

## 3. Field drills
Run these before each phase gate, on at least two watch models:

| Drill | Repeats | Pass |
|---|---|---|
| Walk away from the phone on a table | 10 | Alert in under 5 s |
| Helper grabs the phone and walks off fast | 10 | Alert in under 5 s |
| Airplane mode switched on while armed | 10 | Alarm 10/10 |
| Alarm → Mark as Lost screen | 10 | Under 15 s |
| 4 h armed, normal use | 2 | Under 15% watch battery |
| Club or crowd simulation, phone in pocket | 3 sessions | No false alarm |

For Gate 0, follow [GATE0_RUNBOOK.md](GATE0_RUNBOOK.md): it has the exact steps for the 4-hour sessions and the trace recordings.

Log each drill in `docs/drills/YYYY-MM-DD.md`: device models, OS versions, results, notes.

## Safety during drills
Only drill with your own phone or a helper's, with their agreement. Never stage a "theft" in public where bystanders could react.
