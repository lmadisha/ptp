# ADR-0010: Learn places as rounded grid cells, one row per visit day

- **Status:** Proposed
- **Date:** 2026-11-24

## Context
The new-area prompt (ADR-0003) needs "visited fewer than 3 times in 60 days". iOS visit monitoring ([`startMonitoringVisits()`](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringvisits())) reports arrivals with a coordinate. PRIVACY.md promises rounded areas, not exact trails, kept for 60 days, on the iPhone only (ADR-0002, ADR-0005).

## Decision
1. **An area is a grid cell, never a coordinate.** Latitude and longitude are each floored to a grid of `StoreConfig.placeGridDegrees` (0.0025°, about 250–280 m) and stored as the two cell indices as text. The exact coordinate is dropped as soon as the visit arrives.
2. **One row per visit: the cell and the arrival day** (start of its UTC day). A count of rows in the last 60 days answers the prompt's question exactly, and each row expires on its own after `StoreConfig.placeRetention` (60 days).
   - Rejected: one row per cell with a count and a last-visit time. It can't say how many visits fall inside the last 60 days.
   - Rejected: the exact arrival time. The prompt needs days, not minutes.
3. **At most one visit per cell and day.** iOS can report the same visit at arrival and again at departure, or only once it is over, so every report with a real arrival date is stored and a repeat for the same cell and day is ignored. Visits without an arrival date are dropped. Several separate visits to one place on one day count once, which suits "visited fewer than 3 times".
4. **Its own file, `places.sqlite`**, file-protected until first unlock and excluded from backup, like the alarm log. Separate files keep each store's `user_version` schema number its own.
5. **The `VisitLearner` is created at app launch**, so a background relaunch for a visit is recorded.

## Consequences
- **A place on a cell edge can split its count** across two cells, so a familiar place can look new. Revisit by counting neighbouring cells if the owner's drills show it.
- Cells are narrower east–west away from the equator (about 250 m at 26° S). Acceptable for "is this place new".
- A list of cells with days is still a coarse history of where the owner went. It stays on the device, expires after 60 days, and the owner can delete it all.
- Visit monitoring needs Always location. Refusing it leaves Event mode and manual arming working (Gate 2).
