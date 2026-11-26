# ADR-0017: First-launch onboarding asks each permission after its reason

- **Status:** Proposed
- **Date:** 2026-11-26

## Context
The iPhone app started Bluetooth and Nearby Interaction in its first view, so iOS showed both prompts at launch with no explanation. Location and notifications were asked from a main-screen button. A refused prompt is hard to undo: iOS asks once, then only Settings can change it. The plan (2.3) asks for onboarding that pairs the watch, asks permissions one at a time with a reason, asks for 1–3 risky regulars and runs a test alarm.

## Decision
1. **A one-time flow on the iPhone**, shown as a full-screen cover until finished. Pages: what PTP does (and that it doesn't lock the phone, ADR-0001); the watch (paired, PTP installed, from WatchConnectivity); Bluetooth; Nearby Interaction; notifications; location; risky places; a test alarm.
2. **Each prompt fires only when the owner taps that page's button.** The Bluetooth heartbeat and the Nearby Interaction session no longer start at launch until onboarding has finished; until then the Bluetooth and distance pages start them. `PlaceWatcher` no longer creates its `CLMonitor` before location has been answered, because creating one makes iOS ask for location (seen in the Simulator); it starts at the first mark instead. Notifications come before location, so the notification prompt also has its reason (place learning asks for notifications as soon as Always is granted).
3. **Notifications and location are optional** ("Not now"). Bluetooth and distance have no skip, because PTP doesn't work without them; refusing the iOS prompt still continues.
4. **Risky places** reuse "Mark here as risky" (ADR-0012), up to 3 during onboarding, only with location Always. Most owners won't be at one during setup, so the page says they can mark them later.
5. **The test alarm is a real one:** arm on the watch and walk away. The page shows the state the watch reports and says when an Alarm arrived. No simulated alarm and no message from the phone starts it, so the test exercises the same path as a theft (hard rule 5). It can be skipped. The test Alarm is written to the alarm log like any other.
6. **Stored:** one flag, `onboardingFinished`, in the iPhone's UserDefaults. Nothing else.

## Consequences
- Owners who updated from an earlier build see onboarding once, and nothing ranges until they finish it.
- iOS asks for Nearby Interaction only when the session runs with the watch's token, so that prompt may come after the page, once the watch app is open.
- The test only passes with the watch app open and both devices set up; it can't run in the Simulator.
- No onboarding on the watch. Revisit if owners install the watch app first or arm before opening the iPhone app.
