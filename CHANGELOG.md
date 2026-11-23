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

### Changed
- On-device stores (places, alarm log) will use SQLite through the system `SQLite3` library in a `PTPStore` package, not SwiftData (ADR-0005, #30).

### Fixed
- `guard_bash.py` no longer blocks commands that only mention a push (`chmod +x`, `rm -f`, heredocs), and now checks every unquoted push in a command, so it also catches `git -C … push -f`, `-fu`, and pushes behind `command`, `sudo`, `then`, `xargs`, subshells, `env` or `bash -c` (#2).
