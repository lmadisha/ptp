# ADR-0015: The watch queues each "I have it" for the phone's alarm log

- **Status:** Proposed
- **Date:** 2026-11-26

## Context
Plan 2.2 asks that "I have it" stop the alarm and log the event for tuning. Stopping already works: the watch's haptic loop ends when the state leaves Alarm, and the iPhone siren stops on any non-Alarm state (ADR-0013).

The alarm log lives on the iPhone (ADR-0005) and is written from the state the watch reports in the WatchConnectivity application context (ADR-0008). That misses two things tuning needs:
- A Warning the owner dismisses. The phone sees Warning → Armed, which is also what happens when the distance comes back, so it can't tell them apart.
- The context keeps only the latest value. A short Alarm → Armed while the phone is out of reach can arrive as "armed" alone.

## Decision
1. When "I have it" ends a Warning or an Alarm, the watch sends its wall-clock time with [`transferUserInfo`](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:)). The system queues each item and delivers all of them in order, also after the phone app was closed.
2. The phone writes one row, `ihaveit`, at the watch's time. Still a time and one word, no distance or location.
3. The state entries stay as they are, so an Alarm the owner dismisses reads `alarm`, `ihaveit`, `armed`. An `ihaveit` with no `alarm` before it is a dismissed Warning.
4. Nothing on the watch waits for this; the watch still alarms and recovers without the phone (hard rule 5).

## Consequences
- False alarms can be counted per week (Gate 1's under 1 per week) from the log alone.
- The row's time comes from the watch clock. A wrong clock dates it wrongly; rows far in the future are already deleted (`AlarmLog`).
- A tap made before WatchConnectivity activates (just after launch) isn't logged.
- Revisit if tuning needs more than the word, such as how long the Warning lasted; that would be new stored data and needs PRIVACY.md first.
