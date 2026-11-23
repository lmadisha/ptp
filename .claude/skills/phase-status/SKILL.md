---
name: phase-status
description: Report progress through docs/IMPLEMENTATION_PLAN.md — the current phase, done vs open tasks, gate status, and the single next task to work on. Use at the start of a session or when asked what to do next.
allowed-tools: Bash(git log:*) Bash(git branch:*)
---

# Phase status

1. Read `docs/IMPLEMENTATION_PLAN.md`.
   - Count `- [x]` and `- [ ]` per phase and sub-section.
   - The **current phase** is the first one with unchecked tasks.
2. Read the gate table for the current phase.
   - Look for evidence that each check passed: drill logs in `docs/drills/` and trace results in recent commits (`git log --oneline -20`).
   - Mark each check: passed (with evidence), not yet run, or failed.
3. Report:
   - **Current phase:** name, weeks, tasks done / total
   - **Open tasks** in this phase (max 10, in plan order)
   - **Gate:** each check with its status
   - **Next task:** exactly one, the first unchecked task whose prerequisites are done. Find or create its GitHub issue, then suggest a branch `<type>/<issue-number>-<short-slug>` from `develop`. Use `feat`, `fix`, `chore`, or `docs`.
4. If a later phase has checked tasks while an earlier gate hasn't passed, flag it. The plan says no phase starts until the previous gate passes.

Do not tick checkboxes yourself. Only tick a task when the human confirms it is done, or when its tests and checks have clearly passed in this session.
