# AGENTS.md

Instructions for AI coding agents working in this repo (Claude Code, Codex, Cursor and others). Humans: see [CONTRIBUTING.md](CONTRIBUTING.md).

## Project
PTP (Phone Theft Prevention) is an open-source iPhone + Apple Watch app.
- It measures the distance between the phone and the watch.
- It warns, then alarms on the watch when they separate.
- It takes the owner to Find My's Mark as Lost in one tap.
- It arms only for occasions: Event mode, unfamiliar places, and risky places the owner marks.

**Current phase:** see the unchecked tasks in [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md). Work on the current phase only.

## Commands
| Task | Command |
|---|---|
| Core unit tests + trace replay | `swift test --package-path Packages/PTPCore` |
| Build iOS app | `xcodebuild -scheme PTPApp -destination 'generic/platform=iOS' build` |
| Build watch app | `xcodebuild -scheme PTPWatch -destination 'generic/platform=watchOS' build` |
| Format | `swift-format format -i -r PTPApp PTPWatch PTPLiveActivity Packages` |

Nearby Interaction does not run in the Simulator. Don't claim a ranging change works unless it was tested on devices. Say what you could not verify.

## Layout
```
PTPApp/              iOS app (SwiftUI)
PTPWatch/            watchOS app
PTPLiveActivity/     Live Activity widget extension
Packages/PTPCore/    Pure Swift logic: models, DetectionEngine, PTPStateMachine, DetectionConfig
  Tests/Fixtures/    Recorded distance traces (CSV), anonymised
docs/                Plan, architecture, ADRs, privacy, testing
```

## Hard rules
Never break these. If a task seems to need it, stop and ask.
1. **No network calls.** No `URLSession`, `URLRequest`, `NWConnection`, analytics or crash SDKs, or third-party networking packages. All data stays on the device (ADR-0002).
2. **No private APIs.** Never use `GraphicsServices`, `GSEventLockDevice` or any other private API to lock the phone. PTP does not lock the phone (ADR-0001).
3. **`PTPCore` stays pure.** No imports of `SwiftUI`, `UIKit`, `WatchKit`, `NearbyInteraction`, `CoreLocation` or `WatchConnectivity` in `Packages/PTPCore`. Inject clocks and inputs.
4. **No hard-coded timings or distances.** Every threshold and delay lives in `DetectionConfig`.
5. **The watch must alarm without the phone.** Never make the watch's alarm depend on a message from the phone.
6. **No real location data in the repo.**
   - Fixtures must be anonymised: distances and timestamps only, no coordinates.
   - Never commit raw diagnostics exports.
7. **Never commit secrets:** `.p8`, `.p12`, provisioning profiles, `.env`.

## How to work
- **Detection changes** (`DetectionEngine`, `PTPStateMachine`, `DetectionConfig`):
  - Run the trace replay.
  - Report each trace's expected vs actual result in the PR.
  - A new false alarm becomes a new fixture.
- **New stored data:** update [docs/PRIVACY.md](docs/PRIVACY.md) in the same change.
- **Decisions that change architecture, data or detection:** add an ADR (see [docs/adr/README.md](docs/adr/README.md)).
- **Swift:** Swift 6 with strict concurrency, SwiftUI, small views, logic in `PTPCore`.
- **Tests:** test the state machine with an injected clock. No `sleep`, no `Date()` in tests.
- **Git:** branch `phase-<n>/<topic>`, Conventional Commits, PRs into `main`. Never push to `main` or force-push.

## Definition of done
- [ ] `PTPCore` tests pass, trace replay included.
- [ ] Both app targets build.
- [ ] Hard rules respected.
- [ ] Docs updated (privacy, ADR, changelog) where relevant.
- [ ] Implementation-plan checkbox ticked.

## Key docs
- [Architecture](docs/ARCHITECTURE.md): components, state machine, design rules
- [Testing](docs/TESTING.md): traces, expected outcomes, field drills
- [Privacy](docs/PRIVACY.md): what is stored, where, for how long
- [ADRs](docs/adr/README.md): why things are the way they are
