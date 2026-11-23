---
name: replay-traces
description: Run PTPCore tests and replay recorded distance traces, then report each trace's expected vs actual outcome. Use after any change to DetectionEngine, PTPStateMachine or DetectionConfig, and before opening a PR that touches detection.
allowed-tools: Bash(swift test:*) Bash(git diff:*)
---

# Replay traces

1. Show what changed in detection:
   `git diff HEAD -- Packages/PTPCore/Sources`
   Note any changed `DetectionConfig` values (old → new).
2. Run the tests:
   `swift test --package-path Packages/PTPCore`
3. Find the expected outcome of each fixture in `Packages/PTPCore/Tests/Fixtures/` in the table in `docs/TESTING.md` §2. A fixture missing from that table is a gap: say so.
4. Report in this format, ready to paste into the PR:

   | Trace | Expected | Result | Time to alert |
   |---|---|---|---|
   | snatch-run.csv | Alarm ≤ 5 s | ✅ Alarm | 3.4 s |

5. If any trace fails:
   - Do **not** change the fixture or its expected outcome to make it pass.
   - Explain which config value or transition caused it, propose a fix, and rerun.
6. A change that reduces false alarms but slows the time to alert on `snatch-run.csv` is a trade-off. State it explicitly and let the human decide.

If `Packages/PTPCore` doesn't exist yet, say so and stop.
