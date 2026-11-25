# Cortex skill-trigger probe (AC5 of #480), 2026-11-25

**Finding: a skill invocation IS detectable in Cortex, in two independent places, with an exact match on the skill name.**

Cortex Code v1.2.45, model claude-sonnet-5-5, headless stream-json (`--input-format stream-json --output-format stream-json --bypass --no-mcp`), personal account only. Tracking issue: noah-goodrich/borg-collective#480.

## Account and approval

- Personal Cortex account: billed account, no trial end date (Noah, 2026-11-01, at lock). The trial-end lockout in the plan's Risks no longer applies.
- Employer account: not approved. No employer-account run and no passive prompt capture happened; only the personal account was used.

## Method

- A scratch git repository with a project-level `.cortex/settings.local.json` registering a recorder on PreToolUse and PostToolUse (matcher `.*`) that writes each payload verbatim. XDG_* pointed at scratch directories.
- Skills under test were the ones already registered in `~/.snowflake/cortex/skills.json` (borg's `pane` and `borg-next`).
- Probe 1, should-fire: "Split my tmux pane to the right." Probe 2, should-not-fire: "What is the capital of France? Answer in one word."
- Then `evals/cortex-skill-trigger/live.sh` ran the four cases in `evals/cortex-skill-trigger/cases.json` (a fire and a no-fire case for each of `pane` and `borg-next`) end to end.

## Evidence

Stream (should-fire run): an `assistant` event carries a `tool_use` block named `skill`, input `{"command":"pane"}`. Recorded in `evals/cortex-skill-trigger/recorded/stream-fire.jsonl`.

Hook payloads (should-fire run): PreToolUse and PostToolUse both fire with `tool_name` `skill` and `tool_input` `{"command":"pane"}`. The PostToolUse `tool_response` carries "Launching skill: pane" and the SKILL.md body. Recorded in `evals/cortex-skill-trigger/recorded/payloads/skill-hooks.jsonl`.

Should-not-fire run: one assistant text block, "Paris.", no `skill` tool_use, no `skill` hook payload (`evals/cortex-skill-trigger/recorded/stream-nofire.jsonl`).

Live check, 4 cases: 4 of 4 graded as expected (`pane` fired and did not fire, `borg-next` fired and did not fire).

## Caveats

- The model sometimes acts before it loads the skill. In the first probe it ran a plain `tmux split-window -h` before calling the `pane` skill. That split a real pane in the default tmux server, because `env -u TMUX` does not hide the server. The stray pane was closed by id. `live.sh` now sets `TMUX_TMPDIR` to an empty directory so a case cannot reach a real tmux server.
- The skill is detected when the model calls the `skill` tool. A skill whose text is injected some other way (a slash command typed by the user) is not covered.
- n is 4 cases, one run each. This answers "is it detectable", not "what is the trigger rate".

## Cost

Cortex reports tokens in the stream result (`modelUsage`), not credits, and `total_cost_usd` is null. Actual use:

- Probe 1 (should-fire) and probe 2 (should-not-fire): about 0.35M tokens combined (cache reads and creation included).
- `live.sh` smoke run of the four cases: 870,765 tokens (190k, 95k, 490k, 95k).
- Total: roughly 1.2M tokens on the billed personal account.

## Consequence

The Cortex trigger check is built at `evals/cortex-skill-trigger/`: `check.py` (grader over the stream and the hooks), `cases.json`, `live.sh` (per-run ceiling in tokens, default 1,500,000, stops before a case once reached) and `run.sh` (offline replay of the recording with known-bad mutations, in `make eval`). The live half is advisory: it is not in `make eval` or CI and stays advisory until it passes at the Claude-side suite's case count. It uses its own case shape (`id`, `skill`, `should_fire`, `query`) and rebases on the step 4 `evals/triggers/<skill>.json` format once that lands on main.
