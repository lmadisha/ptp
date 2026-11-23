# ADR-0003: Arm for occasions, not all day

- **Status:** Accepted
- **Date:** 2026-11-23

## Context
Being armed all the time costs watch battery and causes false alarms in places where separation is normal: at home, at a desk. Users want protection mainly for higher-risk occasions such as festivals, clubs, and unfamiliar areas.

## Decision
Three triggers arm the app:
1. **Event mode:** started by the owner, with a timer (2 h, 4 h, or until home).
2. **New-area prompt:** on arrival somewhere visited fewer than 3 times in 60 days. Visits are learned on the device with iOS visit monitoring.
3. **Risky regulars:** places the owner visits often but marks as unsafe. These arm automatically.

The new-area trigger **asks** instead of arming on its own, because many unfamiliar places are harmless.

## Consequences
- **Familiar does not mean safe.** Thefts on daily routes are covered only if the owner sets up risky regulars, so onboarding asks for 1–3 of them.
- The app can't read Apple's own Significant Locations data, so place learning starts empty. For the first 2–3 weeks, everywhere except home and work counts as unfamiliar.
- Event mode needs the watch to last a full festival day. This is measured in Phase 0.
