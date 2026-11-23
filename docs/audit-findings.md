# Audit findings

Results of each `ponytail-audit` run (over-engineering only). Newest first.
Status: `applied` (fixed in that change), `open`, `wontfix` (with reason).

## 2026-11-23 · #1 workflow rules and git hooks

Scope: whole repo (docs, `.claude/hooks/`, `.githooks/`). No Swift code yet.

| Tag | Finding | Status |
|---|---|---|
| `yagni` | `guard_bash.py` and `.githooks/pre-push` both block pushes to `main`/`develop`. | `wontfix`: the git hook only runs where `core.hooksPath` is set; the Claude hook covers agent sessions in checkouts without it. |

Lean otherwise. Correctness bugs are out of this audit's scope and go to their own issue
(guard_bash ` +x` false positive: #2).
