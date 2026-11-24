# ADR-0007: How the state machine treats signal loss and UWB dropouts

- **Status:** Proposed
- **Date:** 2026-11-24

## Context
The state-machine table in [ARCHITECTURE.md](../ARCHITECTURE.md) and ADR-0004 (UWB distance plus a Bluetooth heartbeat) leave some cases open. They decide whether PTP misses a theft or raises a false alarm, so they're recorded here. The owner approved decisions 1 to 4 on issue #47. Decisions 5 to 8 came later (#49, #50, #51).

The two test traces that pull in opposite directions (`docs/TESTING.md`):
- `pocket-crowd`: UWB flickers while the phone never leaves the owner. No alarm.
- `airplane-mode`: every signal stops at once. Alarm 3 s after the last signal.

## Decision
1. **"Signal" means any sample, UWB or heartbeat.** The no-signal timer (`DetectionConfig.signalLossDelay`, 3 s) restarts on either.
   - Rejected: UWB only. A pocket or a crowd would alarm.
2. **When UWB drops out but the heartbeat continues, the last range verdict stands.** In range stays in range. Over the threshold stays over, and its countdown carries on to Warning and Alarm. Only a new distance changes the verdict. (ADR-0009 changes this last part: without a fresh distance, the heartbeat's signal strength can change it.)
   - Rejected: treat no distance as in range (walking out of UWB range would cancel the countdown), or as out of range (a pocket would alarm).
3. **Signal loss during Warning raises the Alarm after the same 3 s**, whichever of the two timers ends first.
   - Rejected: only the 5 s Warning timer. Switching the phone off 1 s into a Warning would buy 4 more seconds.
4. **Alarm latches.** Coming back in range doesn't cancel it. Only "I have it", Mark as Lost or disarming leaves Alarm.
   - Rejected: cancel when back in range. Walking past the owner would silence it.
5. **Arming allows a longer silence until the first sample** (`DetectionConfig.linkStartupDelay`, 10 s). After arming, or after the watch app restarts while armed, Bluetooth and UWB need a few seconds to connect. Counting the usual 3 s from the tap would alarm with the phone in the owner's pocket. The first sample ends the allowance; from then on decision 1 applies. If no sample ever arrives, the Alarm is raised when the allowance ends. The 10 s default is a guess until the link start-up time is measured on devices. After an Alarm raised by that silence, "I have it" doesn't get the allowance again: the usual 3 s applies after the tap (decision 7 has the one exception).
   - Rejected: count the usual 3 s from the tap (a false alarm on every arm), or wait for the first sample without a limit (a phone taken before the link came up would never alarm).
6. **"I have it" is accepted in Warning as well as Alarm.** Both return to Armed with the same reset of the range verdict, smoother and timers. The usual signal-loss delay applies after the tap.
   - Cost: a mistaken tap in Warning cancels a countdown that would otherwise always end in an Alarm. If UWB then drops out while the heartbeat still reaches the watch, nothing fires until the heartbeat is lost too (the gap under Consequences). The same was already true of a mistaken tap in Alarm.
   - Rejected: ignore "I have it" in Warning. The Warning screen would have a button that does nothing, and the owner would have to wait for the Alarm to dismiss it.
7. **A suspension is not signal loss.** A gap longer than `DetectionConfig.suspensionGap` (3 s, never shorter than `signalLossDelay`) between calls means the watch app was not running. On waking, the no-signal timer restarts with the link start-up allowance (decision 5), once: until a sample arrives, a second gap gets no new allowance. The range verdict stands, so an over-threshold verdict from before the suspension whose countdown has run out becomes an Alarm at once. "I have it" keeps the allowance while no sample has arrived since arming, a restart or a suspension; after an Alarm raised by silence it gets the usual 3 s.
   - Cost: the watch is blind while suspended. A phone taken then alarms only up to `linkStartupDelay` after the app wakes. A tick that runs more than 3 s late while the app is awake reads as a suspension and delays a signal-loss Alarm by up to the same 10 s, once.
   - Rejected: alarm on waking (a false alarm on every wrist raise after a suspension), or wait without a limit.
8. **Alarm and Lost survive a restart of the watch app.** The watch stores the latched state and restores it. Only an owner action leaves Alarm (decision 4).
   - Rejected: come back Armed (a crash or a force-quit would silence an Alarm).

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
- Decision 2 leaves a gap: if UWB is lost while in range and the phone is then carried off inside Bluetooth range, nothing fires until the heartbeat is lost too. The heartbeat's signal strength now narrows it (ADR-0009), with provisional thresholds. Revisit with the Gate 0 traces.
- "I have it" also resets the verdict to in range, because that is what the owner just said. A mistaken tap while UWB is down falls into the same gap as above until a distance or signal loss arrives.
- There's no hysteresis around the threshold, so a distance hovering at it can flip between Armed and Warning. Tune from real traces before adding any.
- These rules are tested with synthetic samples only until the Gate 0 recordings become fixtures.
