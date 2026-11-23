---
name: privacy-review
description: Review the current changes for privacy problems — network calls, location or distance data being stored, logged or exported, and fixtures with real coordinates — and check docs/PRIVACY.md still matches. Use before committing anything that stores, logs, exports data or touches location.
allowed-tools: Bash(git diff:*) Bash(git status:*)
---

# Privacy review

Review `git diff HEAD` plus untracked files. Check each item and report it as ✅, ⚠️ or ❌, with the file and line:

1. **Network:** no `URLSession`, `URLRequest`, `NWConnection`, or analytics, ads or crash SDKs, including in new SwiftPM dependencies (`Package.swift`, `Package.resolved`).
2. **Location storage:**
   - Places are stored only as rounded areas with visit counts, never raw `CLLocation` trails.
   - Anything older than 60 days is deleted.
   - Stored with file protection `.complete` or `.completeUntilFirstUserAuthentication`.
3. **Logging:** no coordinates, place names or addresses in `print`, `os_log` or `Logger` calls. Use `privacy: .private` for anything user-specific.
4. **Diagnostics export:** the exported file has distances, timings and states only. No coordinates.
5. **Fixtures:** files under `Tests/Fixtures/` contain only `t_ms, distance_m, source, app_state`.
6. **Watch sync:** WatchConnectivity sends arm state and settings only, never place data.
7. **Docs:**
   - If the change adds or changes stored data, permissions or retention, `docs/PRIVACY.md` is updated to match.
   - If not, say "PRIVACY.md unchanged, still accurate".
8. **App Store privacy labels:** say whether they need updating (precise location: used on-device, not collected).

End with a one-line verdict:
- **Ready to commit**, or
- **Blocked**, with the ❌ items to fix.

Don't fix things silently. List them, then offer to fix.
