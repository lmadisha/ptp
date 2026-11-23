# Audit findings

Results of each `ponytail-audit` run (over-engineering only). Newest first.
Status: `applied` (fixed in that change), `open`, `wontfix` (with reason).

## 2026-11-23 · #2 guard_bash force-push false positive

Scope: whole repo, mainly `.claude/hooks/guard_bash.py`.

| Tag | Finding | Status |
|---|---|---|
| `shrink` | After the Codex cloud review (round 3), the hook grew from 34 to 120 lines. Most of it is `shell_source()`, a small heredoc and comment stripper that runs before `shlex`. | `wontfix`: a regex that only checks the start of a command missed every shell prefix (`command`, `sudo`, `then`, ...), and stdlib `shlex` can't skip heredoc bodies. 51 cases in `test_guard_bash.py` cover it, and a `ponytail:` comment names what remains (`eval`, aliases, variables). |

## 2026-11-23 · #10 Xcode project

Scope: whole repo, mainly the new `PTP.xcodeproj` and three placeholder targets.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | The widget's `PlaceholderProvider`, entry and static widget exist only so the extension builds. | `open`: replace them with the real `ActivityConfiguration` in task 0.2 (Live Activity), then delete them. |
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
