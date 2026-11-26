# Changelog

All notable changes are recorded here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]
### Added
- Project docs: README, implementation plan, architecture, ADRs 0001–0004, privacy, testing, contributing.
- Open-source setup: MIT license, security policy, code of conduct, issue and pull-request templates.
- AI agent setup: AGENTS.md, CLAUDE.md, Claude Code skills and hooks.
- Issue, branch and PR workflow (`develop` → `main`), PR evidence rules, and `.githooks/` that block commits and pushes to `main` and `develop` (#1).
- `apple-skills` Claude Code plugin enabled for the project, with the skills that break the hard rules listed in CLAUDE.md (#4).
- Model roles: Claude Opus/Fable or GPT-6.2 Astra plan and review, Claude Sonnet or GPT-6.2 Sol implement, Haiku or Luna run QA (`docs/MODEL_ROLES.md`, #8).
- Xcode project `PTP.xcodeproj` with placeholder `PTPApp` (iOS 18.4), `PTPWatch` (watchOS 11) and `PTPLiveActivity` targets (#10).
- Local Swift package `Packages/PTPCore` (iOS 18.4, watchOS 11, macOS 15) with Swift Testing, linked into `PTPApp` and `PTPWatch` (#15).
- App Group `group.com.lmadisha.ptp` shared by `PTPApp` and `PTPLiveActivity` (#17).
- Nearby Interaction usage description (iPhone and watch), `audio` and `location` background modes, and Live Activities support in `PTPApp` (#19).
- CI (`.github/workflows/ci.yml`): `PTPCore` tests, both app builds for the Simulator, and hook tests on every PR and on pushes to `develop`/`main` (#23).
- Spike: phone and watch exchange Nearby Interaction discovery tokens over WatchConnectivity (`Shared/TokenExchange.swift`), with status on both screens (#25).
- Spike: an `NISession` on both devices ranges against the peer token and shows the live distance in metres (`Shared/Ranging.swift`). Nearby Interaction moved out of `TokenExchange` (#27).
- Spike: a Live Activity (Lock Screen and Dynamic Island) shows the ranging state and distance, so iPhone ranging can continue in the background (ADR-0004). It replaces the placeholder widget (#29).
- Spike: the watch can try two keep-alive modes, an extended runtime session (`physical-therapy`) or an `HKWorkoutSession` that saves nothing to Health, to measure how long it stays armed (#35).
- Spike: a Bluetooth heartbeat from the iPhone (peripheral) to the watch (central), once per `DetectionConfig.heartbeatInterval`, with the last beat shown on the watch. First `DetectionConfig` in `PTPCore` (#37).
- Spike: both apps log every reading (time, distance, signal source, app state, battery %) to a CSV file in their Documents folder. The iPhone's folder shows in the Files app, and the watch can send its files to the phone (ADR-0006). `ReadingRow` in `PTPCore` formats the rows (#39).
- Gate 0 runbook (`docs/GATE0_RUNBOOK.md`): exact device steps for the short checks, the 4-hour sessions and the trace recordings, with commands that read a log (#41).
- `DistanceSample` in `PTPCore`: an optional distance in metres, the source (UWB or Bluetooth) and the time since the session started. First Phase 1 type; nothing uses it yet (#43).
- `MedianSmoother` in `PTPCore`: the median distance over `DetectionConfig.smoothingWindow` (1 s), so one wild reading can't cross a threshold. Nothing uses it yet (#45).
- `PTPStateMachine` in `PTPCore`: Disarmed, Armed, Warning, Alarm and Lost, driven by samples, ticks and owner actions. Alert distances (8 m, Event mode 4 m) and delays (2 s, 5 s, 3 s) are in `DetectionConfig`. ADR-0007 records the signal-loss rules. Not wired into the apps yet (#47).
- `WatchSession` on the watch: it keeps the arm mode, feeds UWB and heartbeat samples to `PTPStateMachine` on the watch's own clock and ticks it, so the watch alarms on signal loss without any message from the phone. The tick period is `DetectionConfig.tickInterval` (0.5 s). The setup screen gains Arm, Disarm, "I have it" and "Mark as Lost" buttons. Arming allows 10 s of silence until the first sample (`DetectionConfig.linkStartupDelay`, ADR-0007 decision 5) (#49).
- The watch shows separate Disarmed, Armed, Warning, Alarm and Lost screens. Armed shows live distance and the alert threshold, Warning adds a countdown, and Alarm repeats the notification haptic. "I have it" returns to Armed from Warning or Alarm. Setup readings and controls are under Diagnostics (#50).
- `Packages/PTPStore`: a SQLite alarm event log through the system `SQLite3` library, with 30-day retention. Not linked into the app yet (ADR-0005, now Accepted; #63).
- The iPhone app writes the alarm log: one entry when the watch reports an Alarm and one when it ends. The database is file-protected and excluded from backup (#65).
- The watch reads the heartbeat's signal strength, logs it, and uses it to judge range when it has no UWB distance, for example with PTP off screen. Thresholds are provisional until tuned from device logs (ADR-0009, #67).
- Event mode on the watch: "Event 2 hours" and "Event 4 hours" arm with the 4 m alert distance and disarm by themselves when the time is up, unless a Warning or an Alarm is showing (#69).
- The iPhone can ask the watch to start an event (2 or 4 hours) while the watch app is open and disarmed. The watch decides; the phone can never disarm it (ADR-0008, #73).
- Visit learning on the iPhone: with Always location, each visit is stored as a rounded grid cell (about 250 m) and its arrival day, and deleted after 60 days. The phone shows how many areas it has learned and can delete them all (`PTPStore.PlaceStore`, ADR-0010, #76).
- New-area prompt: arriving in an area with fewer than 3 visit days in 60 days posts "New area · Arm PTP on your watch?". Forwarded to the watch, its "Arm" action arms the watch in normal mode. On the phone the same action only opens PTP; the phone never arms the watch (ADR-0011, #78).
- Risky and safe places: "Mark here as risky" or "Mark here as safe" on the iPhone stores the spot rounded to about 110 m (at most 20). Arriving at a risky place asks on the watch to arm; a safe place never prompts, not even as a new area (ADR-0012, #80).
- Quick-arm complication (`PTPWatchWidget`): an "Arm PTP" complication for the circular, corner and inline slots. Tapping it opens PTP on the watch and arms in normal mode when Disarmed; otherwise it leaves the state alone (#83).
- Mark as Lost hand-off: the watch's Lost screen shows four numbered steps to Mark As Lost in Find Devices, then the icloud.com/find fallback. watchOS has no supported way to open Find Devices from another app (ADR-0014, #90).

### Changed
- Gate 0 is recorded as passed on the owner's device check, with the 4-hour battery figure and the trace files still unrecorded (`docs/IMPLEMENTATION_PLAN.md`, #54).
- On-device stores (places, alarm log) will use SQLite through the system `SQLite3` library in a `PTPStore` package, not SwiftData (ADR-0005, #30).
- The iPhone shows the watch's state (Disarmed, Armed, Warning, Alarm, Lost), sent over WatchConnectivity. The watch owns the state; the phone only mirrors it (ADR-0008, #59).
- The Live Activity shows the watch's state above the ranging status and distance, and turns red while the watch reports an Alarm (#61).

### Fixed
- A Nearby Interaction session that ends, and a heartbeat connection to a phone that isn't serving the heartbeat, are retried after `linkRestartDelay` (2 s) instead of at once, so a link that keeps failing can't spin until the system stops the app (#57).
- Watch: the keep-alive restarts when it ends, a suspension counts as link start-up instead of signal loss, and Alarm and Lost survive an app restart (ADR-0007 decisions 7 and 8, #51).
- `guard_bash.py` no longer blocks commands that only mention a push (`chmod +x`, `rm -f`, heredocs), and now checks every unquoted push in a command, so it also catches `git -C … push -f`, `-fu`, and pushes behind `command`, `sudo`, `then`, `xargs`, subshells, `env` or `bash -c` (#2).
