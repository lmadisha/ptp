# ADR-0004: Detect with UWB distance plus a Bluetooth heartbeat

- **Status:** Proposed. Confirm at the end of Phase 0.
- **Date:** 2026-11-23

## Context
- Nearby Interaction gives metre-level distance between an iPhone and a UWB Apple Watch.
- iOS keeps ranging going in the background while a Live Activity runs (iOS 18.4+).
- watchOS requires the app to be in the foreground for Nearby Interaction.
- A thief can kill the app or switch on airplane mode. Both stop all signals.

## Decision
- UWB distance is the primary signal. A Bluetooth heartbeat is the fallback.
- Losing every signal for 3 s is itself an alarm trigger.
- The watch stays alive while armed through an extended runtime session; a workout session is the fallback.
- Minimum OS: iOS 18.4, watchOS 11.

## Consequences
- Requires UWB hardware on both devices for precise distance. A Bluetooth-only mode covers older devices with less precision.
- App Review may question the background runtime use. Prepare a clear explanation of the safety use.
- If Phase 0 shows the watch can't stay armed, fall back to Bluetooth-only detection and update this ADR.
