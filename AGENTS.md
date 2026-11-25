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
| Store unit tests | `swift test --package-path Packages/PTPStore` |
| Build iOS app | `xcodebuild -scheme PTPApp -destination 'generic/platform=iOS Simulator' build` |
| Build watch app | `xcodebuild -scheme PTPWatch -destination 'generic/platform=watchOS Simulator' build` |
| Device compile check (no team needed) | add `-destination 'generic/platform=iOS'` (or `watchOS`) and `CODE_SIGNING_ALLOWED=NO` |
| Format | `swift-format format -i -r PTPApp PTPWatch PTPWatchWidget PTPLiveActivity Packages` |

No Apple development team is set in the project yet, so signed device builds fail until one is added (needed before device testing). Nearby Interaction does not run in the Simulator. Don't claim a ranging change works unless it was tested on devices. Say what you could not verify.

## Layout
```
PTPApp/              iOS app (SwiftUI)
PTPWatch/            watchOS app
PTPWatchWidget/      Quick-arm complication (watch widget extension)
PTPLiveActivity/     Live Activity widget extension
Packages/PTPCore/    Pure Swift logic: models, DetectionEngine, PTPStateMachine, DetectionConfig
  Tests/Fixtures/    Recorded distance traces (CSV), anonymised
Packages/PTPStore/   SQLite stores (system SQLite3 only): AlarmLog. Retention lives in StoreConfig
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
- **Git:** follow the issue, branch and PR workflow below. Conventional Commits. Never push to `main` or `develop`, never force-push.

## Model roles
A strong model plans and reviews; a cheaper model implements. Full table, IDs and hand-off: [docs/MODEL_ROLES.md](docs/MODEL_ROLES.md).

| Role | Claude Code | Codex |
|---|---|---|
| Orchestrator, planner, architect | Opus 5.5 or Fable 5.2 | GPT-6.2 Astra |
| Implementer | Sonnet 5.5 (Opus 5.5 for hard changes) | GPT-6.2 Sol (Astra for hard changes) |
| Reviewer | Opus 5.5 or Fable 5.2, fresh context | GPT-6.2 Astra |
| Test runner, evidence | Haiku 5.5 | GPT-6 Luna |
| Device testing | The human | The human |

- The planner writes the plan on the GitHub issue, so either tool can pick it up.
- The reviewer is never the run that implemented the change. Prefer cross-vendor review.
- Detection changes are planned and reviewed by the top tier, trace replay included.
- If the implementer fails the same check twice, hand back to the planner.

## GitHub issue, backlog, branch, and PR workflow

Every implementation must be tied to a GitHub issue and follow this
sequence. These steps are mandatory and do not require separate
permission once the user has approved the implementation task. Never
mention an agent as co-author.

### Protected branches and branch topology

- `main` and `develop` are protected. Never commit or push directly to
  either branch; they may change only through pull-request merges.
- Normal work branches start from an up-to-date `develop` and merge back
  into `develop` through a PR.
- Production promotion is `main <- develop`: open a PR from `develop`
  into `main`. Never merge into `main` by another route.
- A branch may be based only on `main` or `develop`. Use `main` only for
  an explicitly requested hotfix or other exceptional work that must be
  isolated from current development. A hotfix PR targets `main`, then
  its result must be synchronized back into `develop` through a PR.
- Linked Git worktrees are allowed for issue branches (for example when
  the main checkout is busy). The same branch, protected-branch and PR
  rules apply inside a worktree.

### Sequence

1. **Find or create the issue before coding.** Search this repository's
   open GitHub issues for an existing issue that matches the requested
   work. If none fits, create one with the problem, scope, acceptance
   criteria, and intended verification. Never invent an issue number.
2. **Put the issue in Backlog.** Add the issue to the GitHub Project used
   by this repository and set its status to `Backlog` before creating a
   branch. If no project is attached, more than one project could apply,
   or GitHub access is unavailable, stop and ask the user instead of
   silently skipping this step.
3. **Create an issue-specific branch.** In the existing checkout, start
   from an up-to-date `develop` by default, or `main` only for an
   explicitly requested exceptional flow described above. Use
   `<type>/<issue-number>-<short-slug>`, for example
   `feat/12-state-machine` or `fix/34-warning-timeout`. Valid types are
   `feat`, `fix`, `chore`, and `docs`. Never implement directly on a
   protected branch. Once work starts, move the issue from `Backlog` to
   `In Progress` when that status exists.
4. **Implement only the ticketed scope.** Keep unrelated fixes out of the
   branch. Create a separate issue and put it in Backlog for newly found
   bugs or technical debt rather than widening the current change.
5. **Review, audit and verify before committing.** Review the complete
   diff and run the checks relevant to the changed area (see Commands
   and Definition of done: `PTPCore` tests with trace replay, `PTPStore`
   tests when the stores changed, both app
   builds). Then run the `ponytail-audit` skill and record every finding
   in `docs/audit-findings.md` (apply the trivial ones in the same
   change; log the rest with a status). Apply the documentation rules
   in How to work before the commit. Capture the PR's required evidence
   under **PR screenshot evidence** below. Do not describe work as
   passing when a required check was not run.
6. **Commit and push the issue branch.** Immediately before each commit
   batch, run `git branch --show-current` and confirm it is the expected
   issue branch. Use a conventional commit that references the issue,
   for example `feat: add warning-to-alarm timeout (#12)`. Never add an
   agent as co-author. Push the issue branch to `origin`; never push
   directly to `main` or `develop` and never force-push a shared branch.
7. **Create the pull request.** After pushing, open a PR from a normal
   issue branch to `develop`. An explicitly requested hotfix branch may
   target `main`; production promotion is a separate `develop` to
   `main` PR. The title must include the issue number. The body must
   explain what changed, why, verification performed and results, plus
   `Closes #<issue-number>`. Every PR also carries, copied from the
   issue it closes so that the two never disagree:
   - **Assignee** `lmadisha`, always.
   - **The issue's labels.** Never invent one: if a label does not
     exist in this repository, create it deliberately with
     `gh label create` or leave it off, and say which you did.
   - **The issue's milestone**, or none when the issue has none.

   Set all three in the `gh pr create` call rather than patching them
   on afterwards:

   ```bash
   gh pr create --base develop --assignee lmadisha \
     --label core --label detection \
     --milestone "Phase 1 — Core logic" \
     --title "feat: ... (#12)" --body "..."
   ```

   Then move the issue to `In Review` when that status exists and add
   the PR link to the issue/project. Wait for the required CI check
   (`.github/workflows/ci.yml`, once it exists). Never merge, or
   describe as ready, a PR whose check is red or pending. Until CI
   exists, run the Definition-of-done commands locally and report their
   results in the PR. This is a rule here until branch protection is on
   for `main` and `develop`.
8. **Close on merge, by hand.** PRs target `develop`, which is not the
   default branch, so `Closes #N` does not auto-close. After the user
   merges, close the issue with a comment naming the PR and move the
   issue and PR to `Done` on the project.

### PR screenshot evidence

- Every PR must have an `Evidence` section in its description or a
  clearly captioned evidence comment containing at least one real
  screenshot of the running app, captured from the iOS or watchOS
  Simulator (for example `xcrun simctl io booted screenshot <file>`).
  Never use generated mockups or screenshots of an unrelated screen.
- Delegate simulator setup, interaction and screenshot capture to a
  lower-cost model when subagents are available: use `gpt-6-luna` in
  Codex by default, or the lowest-cost available Claude model (for
  example, Haiku) in Claude. Keep the task limited to local simulator QA
  and evidence capture; the primary agent remains responsible for
  reviewing the screenshots and publishing them to the PR.
- For user-interface changes, show every materially changed screen or
  state: an iPhone capture for phone UI, a watch capture for watch UI,
  and the Live Activity when it changed. Use synthetic data only; never
  expose credentials, private URLs, real locations or personal
  information. Captions must say what each image demonstrates.
- For changes without a directly visible UI result, capture the closest
  relevant real app state and explain in the caption what it can and
  cannot demonstrate. If no meaningful app state exists (for example a
  `PTPCore`-only change), say so in the Evidence section and attach the
  closest truthful view, such as the test or trace-replay output; never
  invent an interface. Nearby Interaction does not run in the Simulator,
  so never claim a screenshot proves ranging or physical-device
  behaviour.
- Attach screenshots to the PR as GitHub attachments with
  `gh pr edit <pr> --attach '<file>#<caption>'` (or `gh pr comment`).
  Capture to a scratch folder, not the repository.
- Only if attaching fails, commit the screenshots and a short README to
  `docs/evidence/<issue-number>/` on the issue branch and link them from
  the PR at the commit SHA. Never upload them to public image hosts.
- After adding the evidence, open the PR page and verify every image
  renders with its caption. If a screenshot commit starts a new CI run,
  wait for the required check on the new head before calling the PR
  ready.

Use the available GitHub integration or `gh` CLI for issue, project, and
PR operations. If neither is authenticated or capable of completing a
required step, report the exact blocker and stop; do not fabricate a
successful issue, Backlog update, push, or PR. Creating the issue,
updating its project status, committing, pushing, and opening the PR are
pre-authorized for an approved implementation task. Merging, approving,
closing, or deleting issues or PRs still requires explicit user
authorization.

### Post-merge Graphify refresh

After every successful merge, invoke `/graphify . --update` before
starting new work. Verify that `graphify-out/graph.json`,
`graphify-out/graph.html`, and `graphify-out/GRAPH_REPORT.md` were
updated. If Graphify fails, report the exact failure and do not silently
continue with a stale graph.

## Git hooks

Committed hooks live in `.githooks/`. Install them once per checkout
with `git config core.hooksPath .githooks` (worktrees share the setting).

- `pre-commit` blocks commits on `main` and `develop`, in any checkout
  or worktree.
- `pre-push` blocks every direct push whose remote destination is
  `main` or `develop`.
- Never bypass the hooks with `--no-verify`. If a hook blocks the
  requested action, fix the branch or checkout instead.

## Definition of done
- [ ] `PTPCore` tests pass, trace replay included. `PTPStore` tests pass when the stores changed.
- [ ] Both app targets build.
- [ ] Hard rules respected.
- [ ] Docs updated (privacy, ADR, changelog) where relevant.
- [ ] Implementation-plan checkbox ticked.

## Key docs
- [Architecture](docs/ARCHITECTURE.md): components, state machine, design rules
- [Testing](docs/TESTING.md): traces, expected outcomes, field drills
- [Gate 0 runbook](docs/GATE0_RUNBOOK.md): exact device steps for the owner
- [Privacy](docs/PRIVACY.md): what is stored, where, for how long
- [ADRs](docs/adr/README.md): why things are the way they are
- [Model roles](docs/MODEL_ROLES.md): which model plans, implements, reviews and tests
- [Handover](docs/HANDOVER.md): current state, next tasks, and tooling gotchas for a new agent
