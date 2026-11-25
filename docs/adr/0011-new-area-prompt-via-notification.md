# ADR-0011: The new-area prompt is an iPhone notification the watch answers

- **Status:** Proposed
- **Date:** 2026-11-25

## Context
ADR-0003 says the watch asks "New area. Arm PTP?" on arrival somewhere visited fewer than 3 times in 60 days. Visits are learned on the iPhone (ADR-0010), usually while the phone is in a pocket and the PTP apps on both devices are in the background. The watch owns the arm state (ADR-0008), so the phone must never arm it, and a WatchConnectivity message only reaches the watch app while it is running (#73).

## Decision
1. **The iPhone posts a local notification** ("New area", "Arm PTP on your watch?", category `NEW_AREA`) when an arrival report comes for an area with fewer than `StoreConfig.newAreaMinVisits` (3) visit days in the last 60 days, counted before this visit is recorded. Departure and late reports never prompt. The notification carries no coordinate, area key or place name.
2. **iOS forwards it to the watch** while the phone is locked and the watch is worn. Only the watch registers the category's "Arm" action (opens the app); tapping it arms the watch in normal mode on the watch itself. The phone's copy of the category has no action, so the phone can't arm the watch.
3. **Notification permission is asked when place learning starts** (right after Always location is granted, or at launch for an owner who granted it earlier), so the reason is clear. Refusing it still learns visits; there is just no prompt.
   - Rejected: `sendMessage` or `transferUserInfo` to the watch app. The first needs the watch app running; the second arrives late and still needs the app to show something.
   - Rejected: a threshold in `DetectionConfig`. It is a visit count about stored places, not a detection timing or distance, so it sits beside the 60-day retention in `StoreConfig`.

## Consequences
- **No prompt while the phone is unlocked and in use**: iOS shows the notification on the phone then, without the action. The owner can still arm from the watch.
- The prompt comes when iOS reports the arrival, which can be minutes after arriving.
- **Home and work are not special yet.** The "first 2–3 weeks" rule in ADR-0003 waits for safe places. Until then each place prompts until it has 3 visit days, so home prompts on the first three days of learning.
- Whether the watch shows the forwarded notification with "Arm" and arms from it must be checked on devices.
