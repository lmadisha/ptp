# ADR-0016: Settings live on the iPhone; the alert distances reach the watch in the context

- **Status:** Proposed
- **Date:** 2026-11-26

## Context
Plan 2.3 asks for a settings screen: alert distance, arming triggers, risky regulars, safe places, siren on/off and Event mode defaults. ADR-0002 keeps settings in app-group key-value storage and syncs them to the watch over WatchConnectivity. The watch owns the session (ADR-0008) and must alarm without the phone (hard rule 5). Every threshold lives in `DetectionConfig` (hard rule 4).

## Decision
1. **One Settings screen on the iPhone**, opened from the main screen. Values are kept in the app's own `UserDefaults`, not the app group: no extension reads them, so the group would add nothing. This narrows ADR-0002.
2. **Alert distances:**
   - The owner picks normal (5–15 m) and Event mode (2–8 m) distances, in 1 m steps.
   - The ranges, the step and the defaults (8 m and 4 m) are in `DetectionConfig`.
3. **Sync to the watch:**
   - The phone adds both distances to the application context it already publishes.
   - The watch stores its own copy and builds its config at every arm with `withOwnerDistances`, which clamps to the ranges and ignores missing or invalid values.
   - A change applies from the next arm, never mid-session, so a session keeps one threshold.
   - Without the phone, the watch uses its last copy, or the standard values.
4. **Arming prompts:** "In new areas" and "At risky places" toggles, both on by default, gate the two notifications. These are phone-only, since the phone posts them.
5. **Places:** the learn, mark and remove controls move into Settings, unchanged.
6. **Left out:**
   - Siren on/off: the siren is in #89, not yet merged. It's a follow-up after #89.
   - Event "haptics first": the watch only uses haptics.
   - Event durations: fixed at 2 h and 4 h.

## Consequences
- The owner can trade false alarms against detection range. Below 5 m, UWB noise in a pocket would alarm often. Above 15 m, a thief could get well away before the Warning.
- The phone's context is resent whole on every change, so the watch also gets the distances after a reinstall or a new pairing, once the phone app runs.
- A change made while armed doesn't apply until the next arm. The footer says so.
- Revisit the ranges after the Gate 1 field drills.
