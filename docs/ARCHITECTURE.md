# Architecture

## Overview
Two apps measure the distance to each other and can each raise the alarm on their own.

- **The iPhone** runs the main detection engine.
- **The watch** runs a link-loss watchdog. If the signal vanishes (app killed, airplane mode, phone switched off), the watch alarms without needing the phone.
- **There is no server.** See [ADR-0002](adr/0002-local-only-data.md).

```
┌──────────────── Apple Watch ────────────────┐        ┌──────────────── iPhone ─────────────────┐
│ NISession (distance only, foreground*)      │◄─UWB──►│ NISession (distance + direction)        │
│ Link-loss watchdog (no signal 3 s → Alarm)  │◄─BLE──►│ Detection engine (PTPCore)              │
│ Extended runtime session (keeps app alive)  │        │ Live Activity (keeps ranging alive)     │
│ Arm / Armed / Warning / Alarm screens       │◄─WC───►│ Siren, settings, onboarding, place store│
└─────────────────────┬───────────────────────┘        └─────────────────────────────────────────┘
                      │ owner taps Mark as Lost
                      ▼
               Find My (Apple): locks the phone, shows a message
```
\* watchOS only runs Nearby Interaction while the app is in the foreground. An extended runtime session keeps it there while armed. This is the riskiest part of the design.

WC = WatchConnectivity. BLE = Bluetooth Low Energy heartbeat.

## Components

| Component | Target | Responsibility |
|---|---|---|
| `PTPCore.DetectionEngine` | Package | Smooths samples, applies thresholds, emits events |
| `PTPCore.PTPStateMachine` | Package | Disarmed → Armed → Warning → Alarm → Lost |
| `PTPCore.DetectionConfig` | Package | All timings and thresholds in one place |
| `RangingService` | iOS + watchOS | Wraps `NISession` and the Bluetooth heartbeat; outputs `DistanceSample`s |
| `PairingService` | iOS + watchOS | Exchanges discovery tokens and arm state over WatchConnectivity |
| `Watchdog` | watchOS | Raises Alarm on signal loss, independent of the phone |
| `ArmingService` | iOS | Event mode timers, visit learning, new-area prompt, region triggers |
| `PlaceStore` | iOS | SQLite store of place areas and visit counts (`Packages/PTPStore`, ADR-0005) |
| `SirenService` | iOS | Audio session and full-screen alarm |
| `EventLog` | iOS | Local alarm history and diagnostics export |

## State machine

| From | To | Trigger (defaults in `DetectionConfig`) |
|---|---|---|
| Disarmed | Armed | Event mode, new-area prompt accepted, risky place arrival, manual arm |
| Armed | Warning | Distance over the threshold for 2 s |
| Warning | Armed | Back in range |
| Warning | Alarm | Still out of range after 5 s |
| Armed | Alarm | No signal for 3 s |
| Alarm | Armed | Owner taps "I have it" |
| Alarm | Lost | Owner taps Mark as Lost |
| Any except Lost | Disarmed | Owner disarms, Event mode ends, or arrival at a safe place |

Defaults:
- Normal alert distance: 8 m
- Event mode alert distance: 4 m

## Design rules
1. **`PTPCore` has no Apple UI or device framework imports.** All logic is tested by replaying recorded traces.
2. **The watch never depends on the phone to alarm.** It keeps its own arm state and threshold.
3. **No hard-coded timings.** Everything goes through `DetectionConfig`.
4. **No network calls in v1.**
