# ADR-0012: Risky and safe places are marked where you stand and watched with CLMonitor

- **Status:** Proposed
- **Date:** 2026-11-25

## Context
ADR-0003 arms for "risky regulars": places the owner visits often but marks as unsafe. Safe places must never arm. iOS monitors at most 20 regions per app. The phone never arms the watch (ADR-0008); the new-area prompt already reaches the watch as a notification with an "Arm" action (ADR-0011).

## Decision
1. **The owner marks the place they are standing in** ("Mark here as risky" / "Mark here as safe" on the iPhone), from one location fix. No map or search. *(Owner's choice, 2026-11-25.)*
2. **Stored rounded:** latitude and longitude to `StoreConfig.chosenPlaceDecimals` (3 decimals, about 110 m), in `chosen-places.sqlite` on the iPhone, file-protected and excluded from backup, until the owner removes them. At most `StoreConfig.maxChosenPlaces` (20, the iOS limit).
3. **Watched with `CLMonitor`** (`PTPPlaces`; a hyphenated name crashes `CLMonitor.init`), one circle of `StoreConfig.chosenPlaceRadius` (150 m) per place, rebuilt from the store at launch. A place marked where you stand starts as "inside", so marking it doesn't prompt.
4. **Arriving at a risky place prompts on the watch**: "Risky place · Arm PTP on your watch?" in the `NEW_AREA` category, so its "Arm" action arms on the watch (ADR-0011). It does not arm by itself. *(Owner's choice, 2026-11-25.)*
   - Rejected: the watch monitoring regions itself and arming without a tap. Unproven background wake-ups on watchOS, a second location permission and battery cost.
   - Rejected: a queued arm request to the watch. It arms late, or never while the watch app stays closed.
5. **Safe places post nothing**, and a visit inside any chosen place skips the new-area prompt.

## Consequences
- "Arm on arrival" in the plan becomes "ask on arrival": one tap on the watch.
- A rounded centre can sit up to about 55 m from where the owner stood; the 150 m circle absorbs it.
- **Event mode "until home" and auto-disarm at a safe place are not done**: they need the phone to end an event on the watch, which ADR-0008 forbids. They need their own decision.
- Chosen places are real locations kept until removed. They never leave the iPhone and are not logged.
