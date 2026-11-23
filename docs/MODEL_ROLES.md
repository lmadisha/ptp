# Model roles

Which model does which job in PTP. A strong model plans, decides and reviews. A cheaper, faster model writes the code. The cheapest models do mechanical QA. The human runs anything that needs a real iPhone and Apple Watch.

Models change often. **Last checked: 2026-11-23.** Re-check the sources at the bottom before relying on an ID, and update this file in its own PR when the lineup changes.

## Roles

| Role | What it does | Claude Code | Codex |
|---|---|---|---|
| **Orchestrator / planner** | Reads the issue, writes the plan (files, steps, tests, acceptance criteria) and splits the work | Claude Opus 5.5 (`opus`), effort `high`. Hardest problems: Claude Fable 5.2 (`fable`), effort `high` | GPT-6.2 Astra (`gpt-6.2-astra`) |
| **Architect** | Detection design, state machine, `DetectionConfig`, ADRs, anything touching a hard rule | Claude Fable 5.2 (`fable`), effort `high`; or Opus 5.5 at `xhigh` | GPT-6.2 Astra |
| **Implementer** | Writes the code and its unit tests on the issue branch, following the plan | Claude Sonnet 5.5 (`sonnet`), effort `medium` | GPT-6.2 Sol (`gpt-6.2-sol`), effort Medium |
| **Implementer, hard change** | Large refactor, or a change across many files in existing code | Claude Opus 5.5 (`opus`) | GPT-6.2 Astra. OpenAI says it is better at implementing and testing complex changes in existing codebases |
| **Reviewer** | Reviews the full diff against the plan and the hard rules before the PR is marked ready | Claude Opus 5.5 or Fable 5.2, in a fresh context | GPT-6.2 Astra |
| **Test author** | Writes `PTPCore` tests and new trace fixtures | The implementer, as part of the change (TDD) | The implementer |
| **Test runner / evidence** | Runs `swift test` and the builds, captures Simulator screenshots, collects output | Claude Haiku 5.5 (`haiku`), effort `low` | GPT-6 Luna (`gpt-6-luna`) |
| **Device tester** | Nearby Interaction ranging, field drills from `docs/TESTING.md` | The human. Agents write the steps and wait for the results | The human |

### Rules
1. **The planner and the reviewer must be a top-tier model:** Claude Fable or Opus, or GPT-6.2 Astra.
2. **The reviewer must not be the run that implemented the change.** Use a fresh context. Prefer the other vendor: Claude reviews Codex work, and Codex (Astra) may review Claude work.
3. **Detection changes** (`DetectionEngine`, `PTPStateMachine`, `DetectionConfig`):
   - the architect plans them;
   - the reviewer checks the trace-replay results;
   - a cheaper model never signs one off on its own.
4. **No model claims device behaviour.** Simulator output proves nothing about ranging (see AGENTS.md).
5. **Escalate, don't grind.** If the implementer fails the same check twice, or the plan turns out wrong, hand back to the planner. Don't keep retrying on the cheaper model.
6. **Cost:** start each role at the effort listed above. Raise effort only where a gain is measured, and don't move a role up a tier by default.

## Hand-off
1. **Plan.** The planner writes the plan as a comment on the GitHub issue: files, steps, tests and acceptance criteria. Both tools can read it, so the plan doesn't depend on one chat.
2. **Implement.** The implementer works on the `<type>/<issue>-<slug>` branch, following the plan, and commits per the workflow in AGENTS.md.
3. **Test.** The test runner runs the checks and captures evidence. The implementer fixes any failures.
4. **Review.** The reviewer reads the whole diff, the plan and the check output, then either approves or sends back a list of fixes.
5. **PR.** The planner/orchestrator opens the PR and owns what it claims.

## Running it

### Claude Code
- **Model aliases:** `opus` is Opus 5.5, `sonnet` is Sonnet 5.5, `haiku` is Haiku 5.5 and `fable` is Fable 5.2, on the Anthropic API.
- **`opusplan`:** Opus in plan mode, then Sonnet once the plan is approved. Use it for single-session work.
- **Subagents:** set the model in the subagent's `model:` frontmatter, or in the Agent tool's `model` parameter.
  - Subagents inherit the main model unless you set one.
  - Implementation subagents get `sonnet`, review subagents get `opus`, QA and evidence subagents get `haiku`.
- **Effort:** `/effort`, `--effort`, or `effort:` in subagent frontmatter. Opus 5.5, Sonnet 5.5, Haiku 5.5 and Fable 5.2 default to `medium`, so set `high` for planning and review.

### Codex
- **Choosing a model:** `codex -m gpt-6.2-sol`, `/model` in a session, or `model = "gpt-6.2-sol"` in `~/.codex/config.toml`.
- **Reasoning effort:** Low, Medium, High, Extra High or Max, set from `/model`. Ultra mode (parallel subagents) is not available on Luna.
- **Instructions:** Codex reads `AGENTS.md`, so the hard rules and the workflow apply to it unchanged.
- **Not installed on the maintainer's machine yet.** Install it before giving work to Codex.

## Current lineup (checked 2026-11-23)

### Anthropic

| Model | ID | Price $/1M in / out | Positioning |
|---|---|---|---|
| Claude Fable 5.2 | `claude-fable-5-2` | 8 / 40 | Most capable widely released model; demanding reasoning and long agentic work. Thinking is always on |
| Claude Opus 5.5 | `claude-opus-5-5` | 4 / 20 | Current Opus, complex reasoning; default model on the Claude API |
| Claude Sonnet 5.5 | `claude-sonnet-5-5` | 2 / 10 | Speed and capability for everyday coding and agent work |
| Claude Haiku 5.5 | `claude-haiku-5-5` | 0.10 / 0.50 | Fast and cheap; simple tasks and subagents (prompts up to 100K tokens) |

All four have a 1M-token context window and the effort levels `low`, `medium`, `high`, `xhigh` and `max`.

### OpenAI (Codex)

| Model | ID | Price $/1M in / out | Positioning (OpenAI) |
|---|---|---|---|
| GPT-6.2 Astra | `gpt-6.2-astra` | 8 / 40 | Frontier model for the hardest, multi-step projects |
| GPT-6.2 Sol | `gpt-6.2-sol` | 2 / 10 | Efficient model for everyday work and multistep agentic workflows |
| GPT-6 Luna | `gpt-6-luna` | 0.10 / 0.50 | Most efficient; high-volume, focused tasks |

Older models still in the Codex picker: `gpt-6-astra`, `gpt-6.1-sol`, `gpt-6.1-terra`. GPT-6.2 launched on 2026-11-17, and there is no GPT-6.2 Luna yet.

**Pricing note:** OpenAI's announcement gives the GPT-6.2 prices. The Luna price comes from a third-party list and is not confirmed by OpenAI.

**Benchmarks:** neither vendor publishes like-for-like coding results for these exact models, and third-party guides disagree. This doc therefore ranks by each vendor's own positioning, not by a benchmark number.

## Sources
- Anthropic model table and effort defaults: Claude API reference (models cached 2026-11-03), [Claude Code model configuration](https://code.claude.com/docs/en/model-config)
- [Introducing GPT-6.2 Astra and Sol](https://openai.com/index/introducing-gpt-6-2-astra-sol/) (OpenAI, 2026-11-17)
- [Codex models](https://learn.chatgpt.com/docs/models?surface=cli) (OpenAI)
- [Introducing GPT-6 Sol and Luna](https://openai.com/index/introducing-gpt-6-sol-and-luna/) (OpenAI)
