# Implementation Plan

PTP — Phone Theft Prevention is an iPhone + Apple Watch app. It alerts the owner within seconds when their phone is separated from their wrist, and gets them to Find My's Mark as Lost fast.

- **Timeline:** about 12 weeks, one developer, part-time.
- **Rule:** no phase starts until the previous phase's gate passes. If a gate fails, re-plan; don't push on.

| Phase | Weeks | Outcome | Gate |
|---|---|---|---|
| 0. Setup and feasibility spike | 1–2 | Repo, targets, and a measured answer to "can the watch stay armed?" | Watch stays armed 2+ h and uses under 15% battery in 4 h |
| 1. Core detection | 3–6 | Working detection, state machine, alarm on watch | Alert within 5 s; under 1 false alarm per week |
| 2. Arming, response and settings | 7–9 | Event mode, new-area prompt, risky regulars, siren, Mark as Lost hand-off | Alert to Mark as Lost in under 15 s across 10 drills |
| 3. Beta and launch | 10–12 | TestFlight beta, App Store submission | App Review approves background runtime use |

---

## Phase 0 — Setup and feasibility spike (weeks 1–2)

**Goal:** prove the riskiest assumption before writing product code. Can a watch app keep measuring distance to the iPhone in the background, and at what battery cost?

### 0.1 Repo and project setup
- [x] Create the Xcode project with these targets:
  - `PTPApp` (iOS)
  - `PTPWatch` (watchOS)
  - `PTPLiveActivity` (widget extension)
- [x] Create a local Swift package `PTPCore`. It holds models, the detection engine and the state machine, with no UIKit, SwiftUI or watch imports, so it can be unit-tested.
- [x] Set up an App Group shared by the app and the Live Activity.
- [x] Add capabilities and Info.plist keys:
  - Nearby Interaction usage description
  - Background modes: audio (siren), location updates (Phase 2)
  - Live Activities enabled (started locally, no push server)
- [x] Set up CI: build both targets and run `PTPCore` tests on every push (GitHub Actions or Xcode Cloud).
- [x] Set minimum versions: iOS 18.4, watchOS 11 (see ADR-0004).

### 0.2 Distance spike
- [x] Exchange discovery tokens between phone and watch over WatchConnectivity.
- [x] Run an `NISession` on both devices and show live distance on each screen.
- [ ] Start a Live Activity on iPhone. Confirm ranging keeps going when the app is backgrounded and the phone is locked.
- [x] On the watch, test keeping the app alive with (the runtime session was confirmed on the device; the workout fallback was not tested):
  1. a `WKExtendedRuntimeSession` (try each session type that fits)
  2. an `HKWorkoutSession`, as the fallback, and note the App Review risk
- [x] Add a Bluetooth heartbeat (one packet per second) as a second signal.

### 0.3 Measurement
- [x] Log every reading to a CSV file on each device: timestamp, distance, signal source, app state, battery %.
- [ ] Run 4-hour armed sessions on at least two watch models (one older UWB model, one Series 9 or later).
- [ ] Record **trace files** for real scenarios: phone on a table while walking away, phone snatched and carried at a run, phone in a pocket in a crowd, airplane mode switched on mid-session.
  These traces become the test fixtures for Phase 1.

### Gate 0
| Check | Pass |
|---|---|
| Watch keeps ranging with the app in the background or screen off | 2+ h without stopping |
| Watch battery used over 4 h armed | under 15% |
| iPhone keeps ranging when locked | 2+ h |

**Result (2026-11-24): recorded as passed on the owner's device check.** The owner reports that ranging, the heartbeat and the keep-alive work on the iPhone and the watch, and asked for Gate 0 to be closed (#54). The gate table is **not** fully measured:
- **Not recorded:** the 4-hour battery figure and the trace files. The Phase 0.3 tasks for 4-hour sessions on two watch models and for trace files stay open, and so does the trace-replay task in Phase 1.1 until fixtures exist.
- **Battery is open:** the drill in [docs/drills/2026-11-24.md](drills/2026-11-24.md) ran 152 min with the wrist down and the phone within 2 m. The watch went from 60% to 40%, which projects to about 33 points over 4 h, against the gate's under 15%. This is a straight-line projection, not a 4-hour run, so the battery check stays unverified.
- **Background ranging:** that same drill ran 152 min with no restart, which is above the 2+ h line for "Watch keeps ranging with the app in the background or screen off". The iPhone-locked check is the owner's report only.

**If it fails:** switch detection to Bluetooth heartbeat only (less precise distance, but signal loss still works), and re-run the gate.

---

## Phase 1 — Core detection (weeks 3–6)

**Goal:** a reliable "is my phone still with me?" signal, and an alarm on the watch.

### 1.1 Detection engine (`PTPCore`)
- [x] `DistanceSample` model: value, source (UWB or Bluetooth), timestamp.
- [x] Smoothing: moving median over about 1 s.
- [x] `PTPStateMachine` with states Disarmed, Armed, Warning, Alarm and Lost, and these transitions:
  - Armed → Warning: over the threshold for 2 s
  - Warning → Alarm: still out of range after 5 s
  - Warning → Armed: back in range
  - Armed → Alarm: no signal for 3 s
  - Alarm → Armed: owner taps "I have it"
- [x] Every timing and threshold lives in a `DetectionConfig` struct, never hard-coded.
- [ ] Unit tests that replay the Phase 0 trace files and assert the expected state at each moment.

### 1.2 Watch app
- [x] Armed screen: live distance, threshold bar, Disarm button.
- [x] Warning screen: amber, distance, countdown, "I have it".
- [x] Alarm screen: red, repeating haptic plus sound, "Mark as Lost", "I have it".
- [x] Link-loss watchdog that runs on the watch itself. It raises the alarm even if the phone never sends a message.
- [x] Keep the arm state and threshold on the watch, so it works without the phone.

### 1.3 iPhone app
- [x] Live Activity showing state and distance; it turns red on Alarm. It shows the watch's last reported state, which can be stale (ADR-0008); a freshness rule comes with the siren (2.2).
- [x] Sync arm state between phone and watch over WatchConnectivity (`updateApplicationContext` for state, `sendMessage` for alarm events). The watch owns the state and the phone mirrors it through the application context (ADR-0008). Still to come: `sendMessage` for alarm events with the siren (2.2), and arming from the phone with Event mode (2.1).
- [x] Local alarm event log (SQLite in `Packages/PTPStore`, ADR-0005), capped at about 30 days. It logs what the watch reports to the phone (ADR-0008), so an Alarm the phone never hears about is not in it, and times are when the phone heard, not when it happened.

### Gate 1
| Check | Pass |
|---|---|
| Time from separation to alert on the watch | under 5 s, median across 20 drills |
| False alarms in daily use while armed | under 1 per week, over 2 weeks of self-testing |
| Alarm when airplane mode is switched on mid-session | 10 out of 10 |

---

## Phase 2 — Arming, response and settings (weeks 7–9)

**Goal:** the app arms itself for the right occasions, and the owner can act on an alarm in one tap.

### 2.1 Arming triggers
- [ ] **Event mode:** start from watch or phone; durations of 2 h, 4 h, or until home; auto-disarm when the timer ends or the owner arrives at a safe place. Event defaults: 4 m threshold, haptics first.
  - Done (#69): start from the watch, 2 h and 4 h, auto-disarm when the timer ends, 4 m threshold. Done (#73): start from the phone, as a request the watch decides on, while the watch app is open. Still open: until home, safe places.
- [ ] **Visit learning:** use `CLLocationManager` visit monitoring. Store rounded place areas with visit counts in SQLite (`PTPStore`, ADR-0005); delete anything older than 60 days.
  - Built (#76): cells and arrival days in `PlaceStore`, fed by `VisitLearner` on the iPhone. Not ticked until the owner's drill shows real visits arriving.
- [ ] **New-area prompt:** on arrival somewhere visited fewer than 3 times in 60 days, the watch asks "New area. Arm PTP?". During the first 2–3 weeks, treat everywhere except home and work as unfamiliar.
  - Built (#78): an iPhone notification forwarded to the watch, whose "Arm" action arms on the watch (ADR-0011). Still open: the first 2–3 weeks rule for home and work, which needs safe places. Not ticked until the owner's drill.
- [ ] **Risky regulars and safe places:** region monitoring (iOS allows 20 regions per app); arm on arrival at a risky place, never at a safe one.
  - Built (#80): marked where you stand, watched with `CLMonitor`; a risky place asks on the watch to arm instead of arming by itself (owner's choice, ADR-0012). Not ticked until the owner's drill.
- [ ] Quick-arm complication on the watch face.
  - Built (#83): tapping "Arm PTP" opens PTP armed (checked in the Simulator). It shows a fixed icon, not the state. Not ticked until the owner's drill.

### 2.2 Response
- [ ] iPhone siren: full-screen alarm and full-volume audio while the app is alive; the owner stops it with Face ID.
- [ ] Mark as Lost hand-off: open Find Devices on the watch, with a fallback instruction to use icloud.com/find on another device.
- [ ] "I have it" stops the alarm and logs the event for tuning.

### 2.3 Settings and onboarding
- [ ] Settings screen: alert distance, arming triggers, risky regulars, safe places, siren on/off, Event mode defaults.
- [ ] Onboarding: pair the watch, ask permissions one at a time with a reason each, ask for 1–3 risky regulars, run a test alarm.
  - Built (#98): a one-time iPhone flow; each prompt fires after its page, and the test alarm is a real walk-away alarm whose state the page shows (ADR-0017). Not ticked until the owner's drill.
- [ ] "Export diagnostics": save the alarm log as a file the user can share.
- [ ] Bluetooth-only mode for devices without UWB, labelled as less precise.

### Gate 2
| Check | Pass |
|---|---|
| Alarm to Mark as Lost screen | under 15 s in 10 drills |
| New-area prompt fires on arrival somewhere new | 9 out of 10 test visits |
| Event mode auto-disarms at home | 10 out of 10 |
| App still works if location permission is refused | Event mode and manual arming work |

---

## Phase 3 — Beta and launch (weeks 10–12)

**Goal:** real-world tuning, then App Store approval.

### 3.1 TestFlight beta
- [ ] About 20 testers who commute or go out often, on a mix of watch models.
- [ ] A one-page tester guide: how to arm, how to report a false alarm, how to export diagnostics.
- [ ] Weekly review of exported logs; tune `DetectionConfig` defaults.

### 3.2 Store readiness
- [ ] Privacy nutrition labels: precise location used on-device only, not linked to identity, not collected.
- [ ] App Review notes that explain the safety use of background runtime, with a short demo video.
- [ ] App Store listing: screenshots, description, and a clear statement that the app does not lock the phone itself.
- [ ] Pricing decision (see open questions in the design doc).

### Gate 3
| Check | Pass |
|---|---|
| Crash-free sessions in beta | 99%+ |
| False alarms in beta | under 1 per user per week |
| App Review | approved |

---

## Later (not in v1)
- Business tier: MDM remote lock on company-managed phones (needs a server).
- Optional emergency-contact message (needs a server, and explicit consent).
- Android / Wear OS research.

## Suggested branches and issues
- One milestone per phase.
- One issue per checkbox.
- Branches: use `<type>/<issue>-<slug>` from `develop`. Open pull requests into `develop` and merge with CI green. Release through a pull request from `develop` to `main`. Follow the workflow in [AGENTS.md](../AGENTS.md).
