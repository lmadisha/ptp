# ADR-0001: Replace "force lock" with a guided Mark as Lost

- **Status:** Accepted
- **Date:** 2026-11-23

## Context
The original idea was to lock the iPhone automatically when it moves away from the watch. iOS has no public API that lets a third-party app lock the device:
- The only known route is a private API, which gets an app rejected from the App Store.
- The Screen Time API does not offer it either.

## Decision
The app does not try to lock the phone. On alarm, the watch takes the owner straight to Find My's Mark as Lost, aiming for under 15 s from alert to action.

## Consequences
- Locking depends on the owner acting. Speed of alert is therefore the core of the product.
- The App Store listing must say clearly that the app does not lock the phone itself.
- MDM remote lock on company-managed phones stays possible as a later business tier.
