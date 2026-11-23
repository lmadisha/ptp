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

### Hooks (`.claude/settings.json`)
These run automatically. Don't work around them. If one blocks you, fix the cause or ask.

| Hook | What it does |
|---|---|
| `protect_files.py` (before Edit/Write) | Blocks writing secrets or diagnostics, network APIs in Swift, private lock APIs, and UI/device imports in `PTPCore` |
| `guard_bash.py` (before Bash) | Blocks pushing to `main`, force-pushing, and `--no-verify` |
| `after_edit.py` (after Edit/Write) | Formats Swift if `swift-format` is installed; reminds you to replay traces after detection changes |
| `core_tests_on_stop.py` (on Stop) | If `PTPCore` changed, runs its tests before you finish; failures must be fixed |

### Working style
- Use plan mode for detection changes and anything in Phase 0's feasibility spike.
- Start a session with `/phase-status`. Keep each change to one plan task.
- When device testing is needed, write the steps for the human to run and wait for the results. Don't guess.
