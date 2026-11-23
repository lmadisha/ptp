# ADR-0006: Keep a reading log on each device in test builds

- **Status:** Proposed
- **Date:** 2026-11-23

## Context
Gate 0 asks whether the watch and phone stay armed for 2+ hours and what that costs in battery. Phase 1's tests replay traces recorded on real devices. Both need every reading written down on the device that took it (plan task 0.3).

ADR-0002 keeps all data on the device. PRIVACY.md said the app never writes the phone–watch distance to a file, except in diagnostics the user exports.

## Decision
- **Test builds only** (Phase 0 until the beta): each app appends one CSV row per reading to a file in its Documents folder, one file per launch, named `ptp-<phone|watch>-<unix seconds>.diagnostics.csv`.
- **Columns:** `t_ms,distance_m,source,app_state,battery_pct`. No location, names or device identifiers (hard rule 6).
- **Protection:** `.completeUntilFirstUserAuthentication`, because rows are written while the phone is locked. Excluded from iCloud backup.
- **Retention:** until the user deletes the file or the app. There's no automatic deletion: a 4-hour session is a few MB, and the owner needs old sessions.
- **Access:**
  - iPhone: the Documents folder shows in the Files app.
  - Watch: "Send logs to phone" copies its files to the iPhone over `WCSession.transferFile`. Nothing moves unless the button is tapped, and the phone accepts only files with the log's name pattern.
- **Removal:** the log, its screen lines, the button and the two Files-app Info.plist keys are deleted before public release, or folded into Phase 2's "Export diagnostics". After that, distance is written only to diagnostics the user exports.
- Real logs are never committed (`diagnostics/` and `*.diagnostics.csv` are gitignored and blocked by the hooks). Traces become fixtures only after they're cut down to the fixture columns.

## Consequences
- Gate 0 and the Phase 1 traces can be measured without Xcode attached.
- Distance history sits in a user-visible folder on test devices. That's acceptable for the owner's own devices, not for the public; hence the removal step.
- A write on every reading costs a little battery, which slightly overstates the Gate 0 battery figure.
- Revisit if testers outside the owner get these builds before the log is removed: add a retention limit and an on/off switch first.
