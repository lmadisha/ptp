# Contributing

## Branches
- `main` is always buildable. Never commit to it directly.
- Branch names: `phase-<n>/<short-topic>`, e.g. `phase-1/state-machine`, or `fix/<topic>`.

## Commits
Use Conventional Commits:
- `feat:` new behaviour
- `fix:` a bug fix
- `test:` tests or fixtures
- `docs:` documentation
- `chore:` tooling, config

Example: `feat(core): add warning-to-alarm timeout`

## Pull requests
- One issue per pull request. Link it: `Closes #12`.
- CI must be green: both targets build, and `PTPCore` tests pass.
- Detection changes must state which traces were run and the result.
- Big design changes need a new ADR in `docs/adr/`, numbered next in sequence.

## Code style
- Swift 6, strict concurrency on.
- SwiftUI for all UI.
- Keep logic in `PTPCore`. Views stay thin.
- No hard-coded timings. Use `DetectionConfig`.
- No network calls (see ADR-0002).

## Secrets
Never commit signing certificates, provisioning profiles, `.p8` keys or `.env` files. `.gitignore` covers the common ones; check `git status` before committing.
