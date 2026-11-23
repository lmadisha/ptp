---
name: log-field-drill
description: Create a field-drill log in docs/drills/ from results the human reports after running device drills, and compare them with the pass criteria in docs/TESTING.md. Use after on-device testing sessions.
argument-hint: "[date YYYY-MM-DD]"
---

# Log a field drill

1. Ask the human for anything missing:
   - iPhone model and iOS version
   - Watch model and watchOS version
   - PTP commit or build
   - Results for each drill they ran
   Never invent results.
2. Create `docs/drills/<YYYY-MM-DD>.md`, using the argument date or today's date. If that file exists, add a suffix: `-2`, `-3`.
3. Use this layout:

   ```markdown
   # Field drill — YYYY-MM-DD

   - **iPhone:** … (iOS …)
   - **Watch:** … (watchOS …)
   - **Build:** <commit sha>
   - **Mode / config:** e.g. Event mode, 4 m

   | Drill | Runs | Result | Pass criterion | Pass? |
   |---|---|---|---|---|

   ## Notes
   ## Follow-ups
   ```
4. Take the pass criteria from the table in `docs/TESTING.md` §3, word for word.
5. Under Follow-ups:
   - Every false or missed alarm gets a line: "Record as fixture `<name>.csv`".
   - Every failed criterion gets a line naming the gate it blocks.
6. **Privacy:** never write coordinates, street names or venue names. Use "venue A", "route B".

Finish by saying which phase gate checks these results satisfy, if any.
