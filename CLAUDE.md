@AGENTS.md

## Claude Code

The shared rules above apply. This section covers what is specific to Claude Code.

### Skills (`.claude/skills/`)
| Skill | Use when |
|---|---|
| `/replay-traces` | After any change to `DetectionEngine`, `PTPStateMachine` or `DetectionConfig`, and before opening a PR |
| `/new-adr` | A change affects architecture, stored data, detection or a hard rule |
| `/privacy-review` | Before committing anything that stores, logs or exports data, or touches location |
| `/phase-status` | At the start of a session, to find the next unchecked task |
| `/log-field-drill` | After running device drills from `docs/TESTING.md` |

### Plugin: `apple-skills`
`.claude/settings.json` enables `apple-skills@indie-apple-stack` ([rshankras/claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills), MIT). It adds 165 Apple-platform skills: SwiftUI, watchOS, Live Activities, concurrency, testing, App Store and more. Claude Code offers to install it when you trust this folder.

The hard rules in AGENTS.md win over any plugin skill. Don't use skills or templates that break them:
- **Network, analytics or cloud** (hard rule 1): `analytics-setup`, `error-monitoring`, `networking-layer`, `http-cache`, `image-loading`, `cloudkit-sync`, `offline-queue`, `push-notifications`, `auth-flow`, `feature-flags`, `force-update`, `referral-system`.
- **App Store Connect API** (`_shared/asc-api/asc.py`): it needs an API `.p8` key (hard rule 7). The human runs it, not you.
- **Location**: skills that store or log coordinates must follow `docs/PRIVACY.md` and hard rule 6.

### Hooks (`.claude/settings.json`)
These run automatically. Don't work around them. If one blocks you, fix the cause or ask.

| Hook | What it does |
|---|---|
| `protect_files.py` (before Edit/Write) | Blocks writing secrets or diagnostics, network APIs in Swift, private lock APIs, and UI/device imports in `PTPCore` |
| `guard_bash.py` (before Bash) | Blocks pushing to `main` or `develop`, force-pushing, and `--no-verify` |
| `after_edit.py` (after Edit/Write) | Formats Swift if `swift-format` is installed; reminds you to replay traces after detection changes |
| `core_tests_on_stop.py` (on Stop) | If `PTPCore` changed, runs its tests before you finish; failures must be fixed |

### Working style
- Use plan mode for detection changes and anything in Phase 0's feasibility spike.
- Start a session with `/phase-status`. Keep each change to one plan task and one GitHub issue.
- When device testing is needed, write the steps for the human to run and wait for the results. Don't guess.

### Model roles (Claude Code specifics)
See the Model roles section in AGENTS.md and [docs/MODEL_ROLES.md](docs/MODEL_ROLES.md).
- **Main session:** run it on `opus` (or `fable` for detection and architecture work) as the orchestrator. `opusplan` (Opus plans, Sonnet executes) suits a single-session task.
- **Delegation:** hand implementation to a subagent with `model: sonnet`, review to a fresh subagent with `model: opus`, and test runs and Simulator evidence to `model: haiku`. Subagents inherit the main model unless you set one.
- **Effort:** set `high` for planning and review, because current models default to `medium`. Implementation stays at `medium`, QA at `low`.
- **Cross-vendor review:** when Codex implemented the change, review it here on Opus or Fable before the PR is marked ready.

### GitHub workflow (Claude Code specifics)
The full issue, backlog, branch, PR, evidence, Graphify and git-hook rules are in AGENTS.md above and apply to Claude Code unchanged. In particular:
- Every implementation follows the issue → Backlog → `<type>/<issue>-<slug>` branch from `develop` → PR into `develop` sequence.
- `main` and `develop` are protected: never commit or push to them directly. `develop` → `main` is production promotion, by PR only.
- PRs: assignee `lmadisha`, the issue's labels and milestone, `Closes #<n>`, an Evidence section. Never add Claude as co-author.
- Evidence: delegate simulator capture to a `haiku` subagent; you review the images and attach them with `gh pr edit --attach`.
- After every merge, run `/graphify . --update` and check `graphify-out/` was updated.
- Merging, approving, closing or deleting issues or PRs needs the user's explicit OK.
