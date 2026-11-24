# Audit findings

Results of each `ponytail-audit` run (over-engineering only). Newest first.
Status: `applied` (fixed in that change), `open`, `wontfix` (with reason).

## 2026-11-24 · #61 Live Activity state

Scope: whole repo, mainly `PTPLiveActivity/PTPLiveActivityBundle.swift` and `PTPApp/LiveActivityController.swift`.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | Linking `PTPCore` into the widget extension to pass a typed state. | `applied`: not done. The activity carries the raw string. |
| `yagni` | A stale date and an "out of date" look for an old Alarm. | `open`: needs a freshness rule (ADR-0008); decide with the siren (2.2). |
| `delete` | `demoWatchState`, a debug-only launch argument that feeds a watch state for Simulator screenshots. | `open`: delete with `demoDistance` once fixtures or a paired Simulator can drive the UI. |

## 2026-11-24 · #59 watch state mirrored on the iPhone

Scope: whole repo, mainly `Shared/TokenExchange.swift`.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | Arm and Disarm buttons on the phone, sent to the watch as requests. | `applied`: not built. Comes with Event mode (2.1). |
| `yagni` | A separate sync service and a Codable snapshot type. | `applied`: one string key in the application context `TokenExchange` already publishes. |
| `stdlib` | Hand-written strings for the stored arm mode and latched state. | `applied`: `String` raw values on `PTPState` and `ArmMode`. |
| `shrink` | `TokenExchange` now carries tokens, the heartbeat ID, logs and state; the architecture doc calls it `PairingService`. | `open`: rename when the phone starts sending requests. |

## 2026-11-24 · #57 ranging restart loop

Scope: whole repo, mainly `Shared/Ranging.swift`.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | Exponential backoff with a retry cap for restarting ranging. | `applied`: not built. One fixed delay from `DetectionConfig`; add backoff only if a device log shows the 2 s retry still costs too much. |
| `shrink` | Ranging still retries every 2 s for as long as the watch app is in the background, where it can't range. | `open`: pause the retry until the app is active again, once a device log shows which error repeats. |

## 2026-11-24 · #51 watch session after suspension and relaunch

Scope: whole repo, mainly `PTPWatch/WatchSession.swift`, `PTPWatch/KeepAlive.swift` and `PTPStateMachine.swift`.

| Tag | Finding | Status |
|---|---|---|
| `shrink` | A stored flag for "not protected", kept in step with the keep-alive by hand. | `applied`: a computed property over `KeepAlive.mode`. |
| `yagni` | Retry timers or backoff for restarting the keep-alive. | `applied`: not built. One restart when a running session ends, one more each time the app becomes active. |
| `yagni` | A general "restore any state" initialiser on the state machine. | `applied`: `restoreLatched` takes Alarm or Lost only. |
| `shrink` | Suspension is detected from the gap between calls, in the app target, where it can't be unit-tested. | `open`: replace with a lifecycle signal if the #51 device drill shows late ticks. |

## 2026-11-24 · #50 watch screens

Scope: whole repo, mainly `PTPWatch/StateScreens.swift`, `PTPWatch/WatchSession.swift` and `PTPWatch/ContentView.swift`.

| Tag | Finding | Status |
|---|---|---|
| `shrink` | The issue planned one file per screen in `PTPWatch/Screens/`. | `applied`: five small views in one file, `StateScreens.swift`. Split when a screen grows. |
| `native` | A custom threshold bar. | `applied`: `ProgressView(value:)`. |
| `yagni` | A custom alarm tone with its own audio session. | `applied`: not built. System haptics only; a louder tone belongs with the phone siren (2.2). |
| `shrink` | The setup screen carried manual keep-alive buttons next to Arm (open from #49). | `applied`: moved to Diagnostics, reachable only while Disarmed. Delete with the reading log after Gate 0. |
| `delete` | `demoDistance`, a debug-only launch argument that feeds a fixed distance for Simulator screenshots. | `open`: delete once trace fixtures can drive the UI. |

## 2026-11-24 · #49 watch session and watchdog

Scope: whole repo, mainly `PTPWatch/WatchSession.swift` and `PTPWatch/ContentView.swift`.

| Tag | Finding | Status |
|---|---|---|
| `delete` | The architecture named a separate `Watchdog` type. | `applied`: not built. The watchdog is `WatchSession` ticking `PTPStateMachine`; its signal-loss rule already does the job. |
| `yagni` | A keep-alive mode setting (runtime or workout). | `applied`: one call to `startRuntime()`. Change the line when Gate 0 picks the mode. |
| `yagni` | A stored, user-set threshold on the watch. | `applied`: only the arm mode is stored; distances come from `DetectionConfig`. Add a stored value with Settings (2.3). |
| `yagni` | A separate "waiting for link" state after arming. | `applied`: one flag in `PTPStateMachine` and one delay in `DetectionConfig` (ADR-0007 decision 5). |
| `shrink` | The setup screen still carries the manual keep-alive buttons next to Arm, and they can stop the keep-alive while armed. | `open`: they go behind a Diagnostics link in #50 and leave with the reading log after Gate 0. |

## 2026-11-24 · #47 state machine

Scope: whole repo, mainly `PTPCore/PTPStateMachine.swift` and `DetectionConfig`.

| Tag | Finding | Status |
|---|---|---|
| `delete` | The architecture names a `DetectionEngine` type between the smoother and the state machine. | `applied`: not built. The state machine owns the smoother; ARCHITECTURE.md says so. |
| `yagni` | No hysteresis around the alert distance. | `open`: add it only if real traces show Armed and Warning flapping (ADR-0007). |
| `yagni` | `ArmMode` has two cases chosen by the caller, not a free threshold. | `applied`: the two distances stay in `DetectionConfig`. A user-set alert distance (Phase 2.3 settings) will need a third route. |
| `shrink` | `PTPStateMachine` isn't wired into `Ranging` or any screen. | `open`: tasks 1.2 and 1.3. |

## 2026-11-24 · #45 moving-median smoothing

Scope: whole repo, mainly `PTPCore/MedianSmoother.swift` and `DetectionConfig`.

| Tag | Finding | Status |
|---|---|---|
| `shrink` | The smoother sorts its window on every sample. | `wontfix`: the window holds about ten readings at UWB rates. Marked with a `ponytail:` comment; switch to an ordered insert only if profiling on the watch says so. |
| `yagni` | `MedianSmoother` has no user yet. | `open`: `PTPStateMachine` (next task) reads its output. |
| `yagni` | A reading that arrives out of time order is judged against the newest time seen. | `applied`: one `max`, no reordering buffer. |

## 2026-11-23 · #43 DistanceSample

Scope: whole repo, mainly `PTPCore/DistanceSample.swift`.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | `DistanceSample` has no user yet. | `open`: the next two plan tasks (smoothing, `PTPStateMachine`) consume it. Delete it if they end up not needing it. |
| `shrink` | `ReadingRow` and `DistanceSample` both carry a distance, a source and a time. | `open`: when `ReadingLog` is folded into "Export diagnostics", build the row from a sample instead of separate fields. |
| `delete` | A separate source enum for samples. | `applied`: reused `ReadingSource` and moved it next to `DistanceSample`. |
## 2026-11-23 · #41 Gate 0 runbook

Scope: whole repo. Docs only.

| Tag | Finding | Status |
|---|---|---|
| `shrink` | The log is read with two `awk` commands in the runbook, not a script or a Swift tool. | `applied`: Gate 0 is run a handful of times. Write a tool only if Phase 3's weekly log reviews need one. |
| `delete` | HANDOVER.md keeps a short list of the device checks next to the runbook. | `open`: delete the list once Gate 0 is logged in `docs/drills/`. |

## 2026-11-23 · #39 CSV reading log

Scope: whole repo, mainly `Shared/ReadingLog.swift`, `PTPCore/ReadingRow.swift` and the watch-to-phone file transfer in `TokenExchange`.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | The reading log, its "Log: N rows" lines, the "Send logs to phone" button and the two Files-app keys in `PTPApp/Info.plist` exist only to measure Gate 0 and record traces. | `open`: delete them (or fold them into Phase 2's "Export diagnostics") before the beta. PRIVACY.md says the log goes before public release. |
| `shrink` | The phone's `didReceive file` handler replaced a file with `replaceItemAt` and failed the whole save if setting attributes failed. | `applied`: remove, move, then best-effort backup exclusion. |
| `shrink` | Log files are never deleted, and every launch starts a new one. | `open`: fine for the spike (a 4-hour session is a few MB). The owner deletes them in Files. |
| `yagni` | `ReadingLog` is a singleton and writes on the main actor on every reading. | `wontfix`: one log per app is the truth, and a write per reading keeps rows if the app is killed. Revisit only if device logs show dropped readings. |

## 2026-11-23 · #37 Bluetooth heartbeat

Scope: whole repo, mainly `HeartbeatSender`, `HeartbeatReceiver`, `Shared/Heartbeat.swift` and the new `DetectionConfig`.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | `DetectionConfig` holds only `heartbeatInterval` for now. | `applied`: the smallest version that keeps hard rule 4. Phase 1.1 adds the thresholds to the same struct. |
| `shrink` | A beat is skipped when the transmit queue is full (`updateValue` returns false), with no `peripheralManagerIsReady` retry. | `open`: fine for the spike. Add the retry if device logs show missed beats. |

## 2026-11-23 · #35 watch keep-alive spike

Scope: whole repo, mainly `PTPWatch/KeepAlive.swift` (about 190 lines) and the watch's `Info.plist` and entitlements.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | Both keep-alive modes and their buttons exist only to measure Gate 0. | `open`: once the Gate 0 numbers are in, keep the winning mode (plus an ADR if it's the workout route), and delete the other mode and the spike buttons. |

## 2026-11-23 · #32 handover document

Scope: whole repo. Docs only.

| Tag | Finding | Status |
|---|---|---|
| `delete` | The XcodeGen spec was kept outside the repo (#10), so a new agent couldn't regenerate the project. | `applied`: a copy is in `docs/HANDOVER.md`. `PTP.xcodeproj` stays the source of truth. |
## 2026-11-23 · #30 SQLite instead of SwiftData

Scope: whole repo. Docs only: ADR-0005 plus one-line updates in the plan, architecture, privacy and ADR index.

| Tag | Finding | Status |
|---|---|---|
| `native` | ADR-0005 uses the system `SQLite3` library rather than a third-party wrapper (for example GRDB). | `applied`: no new dependency. The thin wrapper gets written in Phase 1.3, when the first store needs it. |
## 2026-11-23 · #29 Live Activity

Scope: whole repo, mainly `ActivityShared/`, `PTPApp/LiveActivityController.swift`, the widget bundle and `Ranging.setReading`.

| Tag | Finding | Status |
|---|---|---|
| `delete` | Placeholder widget (open since #10). | `applied`: the real `ActivityConfiguration` replaces it. |
| `shrink` | `Ranging` set `state` and `distanceMeters` in eight places. | `applied` (Codex): one `setReading` funnel, which also drives `onChange` for the Live Activity. |

## 2026-11-23 · #27 live distance (NISession)

Scope: whole repo, mainly the new `Shared/Ranging.swift` (about 110 lines) and the `TokenExchange` refactor.

| Tag | Finding | Status |
|---|---|---|
| `delete` | `TokenExchange` owned an `NISession` only to get a token. | `applied`: `Ranging` now owns the session, and `TokenExchange` is WatchConnectivity only (`publish(_:)`, `onPeerToken`). That's one owner per framework. |
| `yagni` | `tokenStatus` is still computed but no longer shown on screen. | `open`: show it again if device testing needs it, otherwise delete it when the Phase 1 screens replace the spike lines. |

## 2026-11-23 · #25 discovery-token exchange

Scope: whole repo, mainly `Shared/TokenExchange.swift` (about 120 lines) and two `ContentView` lines.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | The link and token status lines on both screens are spike diagnostics, not product UI. | `open`: replace them with the Phase 1 armed screens (task 1.2), and keep the status only where the owner needs it. |

Lean otherwise. The shared folder is the smallest way to give both app targets one WatchConnectivity and Nearby Interaction glue file without breaking `PTPCore` purity.
## 2026-11-23 · #23 CI workflow

Scope: whole repo, mainly `.github/workflows/ci.yml` (one job, 6 steps).

| Tag | Finding | Status |
|---|---|---|
| `shrink` | A push to a branch with an open PR ran CI twice, once for `push` and once for `pull_request`, because their refs fall in different concurrency groups. | `applied`: twice the doubled demand left the `pull_request` job without a macOS arm64 runner (GitHub capacity notice). `push` is now limited to `develop`/`main`. Every change still gets CI through its PR, and every merge through its `develop` push. |

## 2026-11-23 · #21 minimum versions

Scope: whole repo. Change is one checkbox: the versions were already set by #10 and #15.

No findings. Lean already.

## 2026-11-23 · #19 capabilities and Info.plist keys

Scope: whole repo. Change is a 1-key `PTPApp/Info.plist` and build-setting keys for the two app targets.

| Tag | Finding | Status |
|---|---|---|
| `native` | `PTPApp/Info.plist` exists only for `UIBackgroundModes`. Xcode's `INFOPLIST_KEY_*` settings can't hold an array. | `applied`: kept the file to that single key, and every other key stays a generated build setting. |
| `yagni` | The `location` background mode is declared before any location code exists (it arrives in Phase 2). | `open`: the plan lists it in task 0.1. Remove it if Phase 2 changes course, because App Review rejects background modes that aren't used. |

## 2026-11-23 · #17 App Group

Scope: whole repo. Change is two `.entitlements` files, two `CODE_SIGN_ENTITLEMENTS` settings and one README line.

No findings. Lean already. (The group ID appears in both `.entitlements` files and the README, with no shared constant; none is needed until code reads the container in task 0.2.)

## 2026-11-23 · #15 PTPCore package

Scope: whole repo, mainly `Packages/PTPCore` and the two `ContentView` files.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | `PTPCore.version` exists only to prove the package links and runs in both apps. | `open`: delete it, and its use in the `ContentView` subtitles, once Phase 1 adds real `PTPCore` types for the apps to use. |

## 2026-11-23 · #11 branch-flow docs

Scope: whole repo. Change is two lines in `phase-status/SKILL.md` and `IMPLEMENTATION_PLAN.md`.

No findings. Lean already.

## 2026-11-23 · #2 guard_bash force-push false positive

Scope: whole repo, mainly `.claude/hooks/guard_bash.py`.

| Tag | Finding | Status |
|---|---|---|
| `shrink` | After the Codex cloud review (round 3), the hook grew from 34 to 120 lines. Most of it is `shell_source()`, a small heredoc and comment stripper that runs before `shlex`. | `wontfix`: a regex that only checks the start of a command missed every shell prefix (`command`, `sudo`, `then`, ...), and stdlib `shlex` can't skip heredoc bodies. 51 cases in `test_guard_bash.py` cover it, and a `ponytail:` comment names what remains (`eval`, aliases, variables). |

## 2026-11-23 · #10 Xcode project

Scope: whole repo, mainly the new `PTP.xcodeproj` and three placeholder targets.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | The widget's `PlaceholderProvider`, entry and static widget exist only so the extension builds. | `applied` in #29: replaced by the `ActivityConfiguration`, and the placeholder is deleted. |
| `delete` | XcodeGen spec. | `applied`: generated the project once and kept the spec out of the repo, so there's one source of truth (`PTP.xcodeproj`). |

## 2026-11-23 · #8 model roles

Scope: whole repo. Docs only: `docs/MODEL_ROLES.md` and summaries in AGENTS.md and CLAUDE.md.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | Considered adding `.claude/agents/implementer.md` and `reviewer.md` subagent files. | `wontfix` for now: the Agent tool's `model` parameter and `opusplan` already cover the roles. Add the files if the same prompts get retyped often. |

## 2026-11-23 · #6 ignore graphify-out

Scope: whole repo. Change is one `.gitignore` rule.

No findings. Lean already.

## 2026-11-23 · #4 apple-skills plugin

Scope: whole repo. Change is 11 lines of settings plus a CLAUDE.md section.

| Tag | Finding | Status |
|---|---|---|
| `native` | Considered copying the skills into `.claude/skills/`. | `applied`: used the plugin's own marketplace through `extraKnownMarketplaces` instead. That keeps 400+ third-party files out of the repo and lets it update upstream. |

Lean otherwise.

## 2026-11-23 · #1 workflow rules and git hooks

Scope: whole repo (docs, `.claude/hooks/`, `.githooks/`). No Swift code yet.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | `guard_bash.py` and `.githooks/pre-push` both block pushes to `main`/`develop`. | `wontfix`: the git hook only runs where `core.hooksPath` is set; the Claude hook covers agent sessions in checkouts without it. |

Lean otherwise. Correctness bugs are out of this audit's scope and go to their own issue
(guard_bash ` +x` false positive: #2).
