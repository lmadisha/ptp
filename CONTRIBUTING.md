# Contributing

## Branches
- `main` (production) and `develop` (integration) are protected. Never commit or push to them directly.
- Every change starts from a GitHub issue. Branch from `develop` as `<type>/<issue-number>-<short-slug>`, e.g. `feat/12-state-machine`. Types: `feat`, `fix`, `chore`, `docs`.
- PRs go into `develop`. Releases are a PR from `develop` into `main`. Hotfixes branch from `main`, PR into `main`, then sync back into `develop` by PR.
- Install the git hooks once: `git config core.hooksPath .githooks`.

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
