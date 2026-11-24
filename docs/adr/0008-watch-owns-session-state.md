# ADR-0008: The watch owns the session state; the iPhone mirrors it

- **Status:** Proposed
- **Date:** 2026-11-24

## Context
Plan task 1.3 asks for the arm state to be synced between the phone and the watch. Two devices could each hold a copy and disagree. The watch must raise the Alarm even if the phone never sends a message (hard rule 5), and the phone is the device that gets stolen, so it can't be trusted to decide.

## Decision
1. **The watch runs the only state machine.** Its state is the truth.
2. **The phone shows the last state the watch reported.** The watch adds its state to the WatchConnectivity application context it already publishes. The plan also names `sendMessage` for alarm events. It is left out for now: a message and the context travel separately and can arrive out of order, so a late "alarm" could overwrite a newer "armed". Add it, with a sequence number, when the phone has to act on an Alarm (siren, 2.2).
3. **Publishing is fire-and-forget.** Nothing on the watch waits for the phone, and a failed send changes nothing on the watch.
4. **The phone can't change the state yet.** Arming from the phone comes with Event mode (plan 2.1), as a request the watch decides on.
   - Rejected: a state machine on each device, kept in step. Two clocks and two sets of samples would disagree exactly when it matters.
   - Rejected: the phone as the owner. A thief holding the phone could disarm it, and the watch would depend on the phone.

## Consequences
- The phone's copy can be stale: the application context only arrives when the system delivers it, and it stays as it was if the watch app is killed. The phone must not act on it as if it were live. The Live Activity and the siren (2.2) need a freshness rule before they rely on it.
- The state names (`PTPState` raw values) are now a wire format between app versions on the two devices, and a storage format on the watch. Renaming one is a breaking change.
- The watch's state (one word) is handed to WatchConnectivity, which keeps the latest value on both devices (`docs/PRIVACY.md`).
