# ADR-0013: The iPhone siren sounds only on a live, fresh Alarm from the watch

- **Status:** Proposed
- **Date:** 2026-11-26

## Context
Phase 2.2 asks for an iPhone siren while the app is alive: a full-screen alarm and full-volume audio that the owner stops with Face ID. The watch owns the session (ADR-0008). The phone only mirrors the last state from the WatchConnectivity application context. That copy can be old: it is delivered whenever the system chooses, and it stays as it was after the watch app is killed. A live `sendMessage` and the context travel separately and can arrive out of order. ADR-0008 left the alarm message for this task, "with a sequence number", and asked for a freshness rule first.

## Decision
1. **Stamped states.** The watch stamps every state it publishes with its clock (`watchStateSentAt`, seconds since 1970). The stamp goes in both the application context and a live [`sendMessage`](https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage(_:replyhandler:errorhandler:)). The live message is sent only while the phone is reachable and is never queued. It is fire-and-forget, so the watch's alarm never waits on it (hard rule 5). The paired devices share the system clock, so a timestamp does the job of a sequence number and survives app relaunches.
2. **Newest wins.** The phone applies a state only if its stamp is later than the last one it applied (`WatchReport.isNewer` in `PTPCore`). A state without a stamp comes from an older watch build and counts as new.
3. **Freshness rule.** The siren starts only for a live Alarm message sent less than `DetectionConfig.sirenFreshness` (30 s) ago. It never starts from the stored context.
4. **Stopping.** The siren stops when the owner passes `LAContext` `.deviceOwnerAuthentication` (Face ID, Touch ID or passcode), or when a newer state that isn't Alarm arrives. On a phone without a passcode a tap stops it: there is nothing to check against.
5. **Sound.** A generated two-tone square wave (`AVAudioEngine`, no audio file) at full player volume, in a `.playback` session so it sounds with the silent switch on. The app uses the `audio` background mode it already declares.

## Consequences
- Apps can't raise the system volume through public API, so "full volume" means full player volume at the owner's volume setting. Turning the volume up would need a private API, which PTP doesn't use (hard rule 2).
- The siren only sounds while the app is alive and the message gets through. A thief who runs out of Bluetooth and Wi-Fi range of the watch before the Alarm, or a phone whose app was killed, stays silent. The watch alarm and Mark as Lost remain the main response.
- `sendMessage` can wake the iOS app in the background. Whether iOS lets a woken app start audio and present the alarm there is unverified until the owner's device drill.
- If the two clocks drift by more than a few seconds, ordering could be wrong. Revisit with a counter if a drill shows it.
- Revisit if Critical Alerts become available to PTP, or if the siren should also start from the phone's own ranging.
