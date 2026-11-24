# ADR-0007: How the state machine treats signal loss and UWB dropouts

- **Status:** Proposed
- **Date:** 2026-11-24

## Context
The state-machine table in [ARCHITECTURE.md](../ARCHITECTURE.md) and ADR-0004 (UWB distance plus a Bluetooth heartbeat) leave four cases open. They decide whether PTP misses a theft or raises a false alarm, so they're recorded here. The owner approved all four on issue #47.

The two test traces that pull in opposite directions (`docs/TESTING.md`):
- `pocket-crowd`: UWB flickers while the phone never leaves the owner. No alarm.
- `airplane-mode`: every signal stops at once. Alarm within 3 s.

## Decision
1. **"Signal" means any sample, UWB or heartbeat.** The no-signal timer (`DetectionConfig.signalLossDelay`, 3 s) restarts on either.
   - Rejected: UWB only. A pocket or a crowd would alarm.
2. **When UWB drops out but the heartbeat continues, the last range verdict stands.** In range stays in range. Over the threshold stays over, and its countdown carries on to Warning and Alarm. Only a new distance changes the verdict.
   - Rejected: treat no distance as in range (walking out of UWB range would cancel the countdown), or as out of range (a pocket would alarm).
3. **Signal loss during Warning raises the Alarm after the same 3 s**, whichever of the two timers ends first.
   - Rejected: only the 5 s Warning timer. Switching the phone off 1 s into a Warning would buy 4 more seconds.
4. **Alarm latches.** Coming back in range doesn't cancel it. Only "I have it", Mark as Lost or disarming leaves Alarm.
   - Rejected: cancel when back in range. Walking past the owner would silence it.

Also, as the table already says: **Lost is final** for a session. A new session starts at Disarmed.

Timing rules that follow:
- A Warning becomes an Alarm `alarmDelay` after the Warning **fell due**, not after the app noticed it. A late timer tick can shorten or skip the Warning, never delay the Alarm.
- A sample that arrives exactly on a deadline counts as signal. One that arrives after it can't undo the Alarm.
- An owner action is applied after any deadline that fell due before it.
- Arming starts a new time base. While armed, time never runs backwards.
- Every sample is stamped on the receiving device's clock. A sample dated in the future would read as silence.

All delays and distances are fields of `DetectionConfig`. "I have it" restarts every timer and clears the smoother, so readings from before the tap can't raise a new Warning.

## Consequences
- The heartbeat matters as much as UWB: while it arrives, the watch never alarms for signal loss. If Gate 0 shows the heartbeat can't stay alive in the background, decision 1 falls back to UWB alone and `pocket-crowd` needs another answer.
- Decision 2 leaves a gap: if UWB is lost while in range and the phone is then carried off inside Bluetooth range, nothing fires until the heartbeat is lost too. The heartbeat's signal strength could close it; that's not built. Revisit with the Gate 0 traces.
- "I have it" also resets the verdict to in range, because that is what the owner just said. A mistaken tap while UWB is down falls into the same gap as above until a distance or signal loss arrives.
- There's no hysteresis around the threshold, so a distance hovering at it can flip between Armed and Warning. Tune from real traces before adding any.
- These rules are tested with synthetic samples only until the Gate 0 recordings become fixtures.
