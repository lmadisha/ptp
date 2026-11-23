# ADR-0002: No backend; all data stays on the device

- **Status:** Accepted
- **Date:** 2026-11-23

## Context
The app stores settings, learned places, safe and risky places, and an alarm log. None of these needs to be shared between users. Location history is sensitive personal information under POPIA.

## Decision
v1 has no server and no remote database.
- **Settings:** app-group key-value storage, synced to the watch over WatchConnectivity.
- **Places and the alarm log:** SwiftData on the iPhone, encrypted while the phone is locked.
- **Payments, crash reports and backup:** handled by Apple (StoreKit, App Store Connect, the owner's own iCloud).

## Consequences
- We can honestly say "your locations never leave your phone". This is a selling point.
- Works offline, for example at festivals with poor signal. Nothing to host.
- No real-world data from users by default. Beta data comes from an "Export diagnostics" file that testers share.
- A server becomes necessary only for the MDM business tier or emergency-contact messages. That needs a new ADR.
