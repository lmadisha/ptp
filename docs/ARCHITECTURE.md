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
| `PTPCore.DetectionEngine` | Package | Smooths samples, applies thresholds, emits events. In code this is `MedianSmoother` plus `PTPStateMachine`; there is no third type |
| `PTPCore.PTPStateMachine` | Package | Disarmed → Armed → Warning → Alarm → Lost |
| `PTPCore.DetectionConfig` | Package | All timings and thresholds in one place |
| `RangingService` | iOS + watchOS | Wraps `NISession` and the Bluetooth heartbeat; outputs `DistanceSample`s. On the watch a heartbeat sample carries the connection's signal strength, which decides range when there is no fresh UWB distance (ADR-0009) |
| `PairingService` | iOS + watchOS | Exchanges discovery tokens over WatchConnectivity, and carries the watch's state to the phone, which only mirrors it (ADR-0008). The phone can send one request, to start an event; the watch decides. Today this is `TokenExchange` |
| `WatchSession` | watchOS | Ticks `PTPStateMachine` on the watch's own clock so it can raise Alarm on signal loss independently of the phone. Restarts the keep-alive when it ends, treats a suspension as link start-up, and restores Alarm and Lost. Runs the Event mode timer: when the event's end time passes it disarms, but only from Armed and, for 15 minutes after the end, only once the phone has answered (ADR-0007 decision 9). The end is a wall-clock time, so changing the watch's clock moves it |
| `ArmingService` | iOS | Event mode timers, visit learning, new-area prompt, region triggers |
| `PlaceStore` | iOS | SQLite store of place visits: a rounded grid cell and the arrival day, deleted after `StoreConfig.placeRetention` (60 days) (`Packages/PTPStore`, ADR-0005, ADR-0010). `VisitLearner` in the app, created at launch, feeds it from iOS visit monitoring. On an arrival in an area with fewer than `StoreConfig.newAreaMinVisits` (3) visit days, `VisitLearner` posts the new-area notification; the watch's `NewAreaPrompt` handles its "Arm" action and arms on the watch (ADR-0011) |
| `SirenService` | iOS | Audio session and full-screen alarm |
| `EventLog` | iOS | Local alarm history and diagnostics export. The store is `PTPStore.AlarmLog`: a SQLite log of alarm events (a time and one word), deleted after `StoreConfig.alarmLogRetention` (30 days). `AlarmHistory` in the app writes an entry when the watch reports an Alarm and when the Alarm ends (ADR-0005) |

## State machine

| From | To | Trigger (defaults in `DetectionConfig`) |
|---|---|---|
| Disarmed | Armed | Event mode, new-area prompt accepted, risky place arrival, manual arm |
| Armed | Warning | Distance over the threshold for 2 s |
| Warning | Armed | Back in range |
| Warning | Alarm | Still out of range after 5 s |
| Armed or Warning | Alarm | No signal (UWB or heartbeat) for 3 s; 10 s is allowed between arming and the first signal |
| Warning or Alarm | Armed | Owner taps "I have it" |
| Alarm | Lost | Owner taps Mark as Lost |
| Any except Lost | Disarmed | Owner disarms, Event mode ends, or arrival at a safe place |

Rules the table doesn't show ([ADR-0007](adr/0007-state-machine-signal-rules.md)):
- If UWB drops out while the heartbeat continues, the last range verdict stands.
- Alarm latches: coming back in range doesn't cancel it.
- Lost is final for a session.

Defaults:
- Normal alert distance: 8 m
- Event mode alert distance: 4 m

## Design rules
1. **`PTPCore` has no Apple UI or device framework imports.** All logic is tested by replaying recorded traces.
2. **The watch never depends on the phone to alarm.** It keeps its own arm state and threshold.
3. **No hard-coded timings.** Everything goes through `DetectionConfig`.
4. **No network calls in v1.**
