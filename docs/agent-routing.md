# Agent Routing Guide

> Lives in `docs/`, not `agents/`: a file in `agents/` registers as a spawnable agent type and is never injected into context. The short card is injected at SessionStart by `hooks/borg-link-down.sh`. Two PreToolUse hooks enforce the policy below: `hooks/borg-agent-model-guard.sh` (`Agent`/`Task` tool) and `hooks/borg-workflow-model-guard.sh` (`Workflow` tool).

## Policy

**Queen and drone sessions run Opus at xhigh. Every subagent they spawn must be BELOW that tier: Sonnet or Haiku, effort at most `high`.** The single exception is research-tools.

- **Session tier.** The Queen and drone session tier (Opus at xhigh or max effort) comes from the user's own launch or settings; the `borg` and `drone` launchers start a plain `claude` and do not pin it. `/effort max` is a per-session choice.
- **Why a guard, not a convention.** An unpinned subagent inherits the session model AND effort, so it would run Opus xhigh. `CLAUDE_CODE_SUBAGENT_MODEL` does not reach `Agent`-tool forks or Workflow `agent()` calls. Effort matters as much as model: cache reads cost the same on Opus and Sonnet, so a high-effort Sonnet agent can still be expensive.
- **Deny-by-default allowlist** of `subagent_type` (Agent tool) / `agentType` (Workflow `agent()`):
  - `borg-collective:borg-scout`, `borg-collective:borg-grunt`, `borg-collective:borg-nanoprobe`, `borg-collective:borg-researcher`, `borg-collective:borg-reviewer`, `borg-collective:borg-verifier`
  - `claude-code-guide`
  - `research-tools:*`, only in a session where a research-tools skill was invoked (below)
- **Denied:** no type at all (a fork), `general-purpose`, `Explore`, `Plan`, `fork`, `claude`, `borg-collective:ROUTING`, un-namespaced specialist names, and any unlisted type. Each deny message names what to use instead (for example, `Explore` becomes `borg-collective:borg-scout` for read-only search).
- **Caps on allowed types.** A per-call `model` must be absent or `sonnet` / `haiku` (or a `claude-sonnet-*` / `claude-haiku-*` id). A per-call `effort` must be absent or `low` / `medium` / `high`. `opus`, `fable`, `inherit`, `xhigh`, `max` are denied. The specialists carry their own cheap `model:` / `effort:` frontmatter, so the default is already compliant. The one exception is `claude-code-guide`, which has no effort in its definition: a call without `effort` is denied (no model is required). It is a built-in (Haiku) that pins no effort, so it would inherit the session's xhigh; the guards REQUIRE an explicit `effort` of `low` / `medium` / `high` on it. Preferred call: `Agent {subagent_type:"claude-code-guide", effort:"low"}`; in a Workflow, `agent(p, {agentType: "claude-code-guide", effort: "low"})`.
- **research-tools exception.** `research-tools:*` types may run Opus at any effort, because research quality is worth the spend. They are allowed only when the session transcript shows a research-tools skill invoked (a `Skill` tool call whose skill starts with `research-tools:`) or a research slash command (`/research-tools:research`, `/deep-research`, `/brainstorm`, including the bare forms). Without that, they are denied.

Kill switches (debugging only): `BORG_AGENT_MODEL_GUARD=0`, `BORG_WORKFLOW_MODEL_GUARD=0`.

---

## Routing matrix

Pick the cheapest tier that fits.

| Agent | Model | Effort |
|-------|-------|--------|
| borg-grunt | Haiku | low |
| borg-scout | Haiku | low |
| borg-nanoprobe | Sonnet | medium |
| borg-researcher | Sonnet | medium |
| borg-reviewer | Sonnet | high |
| borg-verifier | Sonnet | per its definition |

- **borg-grunt**: execute a fully-specified change (apply an edit, run tests, rote refactor). One task, zero judgment. If the spec is ambiguous or may expand, use nanoprobe.
- **borg-scout**: read-only locate/search ("where is X?", "does Y exist?"). Replaces `Explore`. Strictly read-only.
- **borg-nanoprobe**: one discrete task that needs judgment (implement, fix, write a test). Split multi-concern work first. Also the replacement for `general-purpose` and `Plan`.
- **borg-researcher**: from-zero web research on ONE track. Do not use it for facts already in the repo.
- **borg-reviewer**: independent blind adversarial review. It arrives cold; do not prime it with the author's reasoning.
- **borg-verifier**: verification of a deliverable against its acceptance criteria. Read-only by enforcement: `hooks/borg-verifier-guard.sh` (PreToolUse, Bash) lets it run any verification command but holds git and gh to a read-only allowlist and denies constructs it cannot see through. It is a no-op for every other caller.
- **claude-code-guide**: questions about Claude Code itself.
- **borg-scout has read-only file tools only (no Bash).** Route git and GitHub lookups ("state of PR X?", "what changed in commit Y?") to an agent that has Bash: borg-grunt for a fully-specified command, borg-nanoprobe when judgment is needed. A scoped read-only shell for the scout is tracked in `docs/plans/directives/2026-10-10-scout-shell-allowlist.md`.

## Decision tree

```
Is the task fully specified (no judgment calls)?
+-- YES: can a read-only search answer it?
|        +-- YES: borg-scout
|        +-- NO:  borg-grunt
+-- NO:  does it need web research from zero?
         +-- YES: borg-researcher (research-tools:* if a
         |        research-tools skill was invoked)
         +-- NO:  is it a blind adversarial review?
                  +-- YES: borg-reviewer
                  +-- NO:  borg-nanoprobe
```

There is no "Opus last resort" branch: if no specialist fits, the task is under-specified. Write the brief, then use borg-nanoprobe, or do it in the main session.

## Cost reference

Prices go stale with every model generation, so none are listed here. Check current rates before quoting one. The durable facts: Haiku is the cheap mechanical tier, Sonnet the judgment tier, Opus the orchestrator tier. Effort is a cost cap as important as model, and cache reads of the growing orchestrator context usually dominate a long session, so keep the main loop lean (delegate verbose reads; do not pull large tool output into the orchestrator).

---

## Model routing inside Workflow scripts

The `Agent`-tool matrix does not apply automatically inside a `Workflow` script: `agent(prompt, opts)` spawns a generic worker that inherits the session model and effort unless `opts` pins it. A 30-agent fan-out with no pin is 30 Opus xhigh agents.

**Rule: every `agent()` call sets an allowlisted `agentType` (for example `'borg-collective:borg-scout'`), OR an explicit `model` (`'sonnet'` / `'haiku'`) AND `effort` (`'low'` / `'medium'` / `'high'`).** A `model` or `effort` given alongside an `agentType` must meet the same caps. `research-tools:*` types are exempt, under the transcript condition above.

`hooks/borg-workflow-model-guard.sh` checks this by tokenizing the script, and it **fails closed**:

- The options argument must be an inline object literal; `agentType`, `model` and `effort` must be string literals (a `const` holding a literal is resolved, unless the same name is bound again anywhere, as a parameter, loop variable or destructuring target; `let`/`var` are never resolved). Variables, spreads, computed keys, getters and expressions are denied.
- `agent` referenced without being called (alias, `.map(agent)`, destructuring) is denied. A local binding named `agent` (a `const`/`let`, an arrow or function parameter, a `for (const agent of ...)` head, a `catch (agent)`) is not the Workflow `agent()` and is allowed inside its scope; `var agent` is not, because it can redeclare the injected parameter.
- Every other route to `agent()` is denied wherever it appears: backslash escapes in identifiers, `eval`, `Function`, `.constructor`, `import`/`require`, and the global object (`globalThis`, `global`, `self`, `window`, `this`, `arguments`).
- A script that cannot be parsed, a `scriptPath` that cannot be read, and a saved-workflow `name` that cannot be found in `.claude/workflows` (project, then parents) or `~/.claude/workflows` are denied. Saved workflows and `scriptPath` files are checked like inline scripts.
- There is no inline escape hatch (the old inherit-on-purpose comment is gone).
- Prose that merely contains `agent(` (template-literal prompts, strings, comments, regex literals) is not a call and is not flagged.

Stage guidance:

- Read-only locate/inventory: `agentType: 'borg-collective:borg-scout'`
- Mechanical edits, test runs: `agentType: 'borg-collective:borg-grunt'`
- Analysis, synthesis, drafting: `agentType: 'borg-collective:borg-nanoprobe'`
- From-zero web research: `agentType: 'borg-collective:borg-researcher'`
- Blind review or merge gate: `agentType: 'borg-collective:borg-reviewer'`
- Claude Code questions: `agentType: "claude-code-guide", effort: "low"` (effort is required; it pins none and would inherit xhigh)
- Ad hoc, no specialist fits: `model: 'sonnet', effort: 'medium'`

- **Read-only lenses use borg-researcher or borg-scout, never borg-nanoprobe.** A lens is a Workflow agent that writes nothing (transcript forensics, log reads, reviews that produce no commits). Use `agentType: 'borg-collective:borg-researcher'` or `'borg-collective:borg-scout'` for it. The nanoprobe type is for agents that write: the SubagentStop hook (`hooks/borg-nanoprobe-log.sh`) marks a nanoprobe that wrote nothing with `zero_commit: true`, and `borg nanoprobes` then shows a ZERO-WRITE flag that means nothing for a lens.
- **Compose with the specialists.** A specialist brings both its cheap model and its system prompt; prefer it over a bare `model` pin.
- **The gate stage is worth Sonnet-high, not Opus.** Independence and rigor come from the blind setup and the high effort, not from the top tier.

### Verification of the agent-type checks (2026-10-14)

Evidence gathered on 2026-10-14 with `jq -c -s` over the local SubagentStop log (`agents.jsonl`), counting rows whose `finished_at` is after 2026-10-12T22:24:00Z:

- 328 rows finished in that window; all 328 (100%) carry a non-empty `agent_type`.
- Distinct values: `borg-collective:borg-verifier` 131, `borg-collective:borg-nanoprobe` 119, `borg-collective:borg-researcher` 39, `borg-collective:borg-reviewer` 28, `borg-collective:borg-grunt` 8, `claude-code-guide` 2, `borg-collective:borg-scout` 1. Every value is on the allowlist; no empty, `general-purpose` or untyped row appears.

What the two guard hooks do, read from the files:

- `hooks/borg-agent-model-guard.sh` is a PreToolUse hook whose logic returns early unless `tool_name` is `Agent` or `Task`. It judges `tool_input.subagent_type`, `model` and `effort` directly: deny-by-default allowlist, model absent or sonnet/haiku, effort absent or low/medium/high.
- `hooks/borg-workflow-model-guard.sh` is a PreToolUse hook that returns early unless `tool_name` is `Workflow`. It carries the same policy block (byte-identical, diffed by a bats test), but its input is the script text (`script`, `scriptPath`, saved `name`). It tokenizes the script and checks the options of every `agent()` call, because there is no per-call tool input to inspect.
- Consequence: the Agent-tool guard only sees calls made through the Agent or Task tool. A workflow-internal `agent()` is not such a call, so the policy is enforced by reading the script before it runs. This design is consistent with the files; the logs here cannot prove that no PreToolUse event fires for an individual `agent()` spawn, since they record only SubagentStop.
- The data confirms the other half: SubagentStop rows for agents spawned from Workflow scripts do carry `agent_type`, so the type is observable after the fact for both spawn routes. The log does not record which route spawned a row, so the 328 are not split by route.

## Cortex Code

borg's agents, the Agent-tool guard and the run logger also run in Cortex Code CLI. Measured on Cortex 1.2.24 with `evals/cortex-agents/live.sh` (2026-10-30), and read from the 1.2.18 and 1.2.24 binaries:

- **One name in both CLIs.** Cortex registers an agent under its exact `name:` and has no plugin namespace, so `borg setup` installs each `agents/*.md` into `~/.snowflake/cortex/agents/` with its name rewritten to `borg-collective:<name>` (`_borg_install_cortex_agents`). The skills, the SessionStart card and this guide then use one name everywhere, `borg-collective:borg-verifier` included; a bare `borg-scout` is denied and pointed at it.
- **Models.** Cortex honors a full model id (`claude-sonnet-5-5`), in an agent's `model:` and as a per-call `model`, and silently ignores an alias (`sonnet`, `haiku`): the call runs the session's model. So under Cortex the guard requires the full id.
- **Effort.** Cortex has no per-agent effort. Its agent parser reads no effort key, and every subagent runs at the session's level: `env.CORTEX_THINKING_EFFORT` in `~/.snowflake/cortex/settings.json` (default `medium`), `--effort`, or `/effort`. The agents' `effort:` pins apply in Claude Code only, so a `max` session runs even the Haiku scout at `max`. `borg setup` warns when the setting is `xhigh` or `max`; `high` is the suggested default, with `/effort max` for the session that needs it.
- **The guard.** `hooks/borg-agent-model-guard.sh` is registered in Cortex's `hooks.json` on `Agent|Task` (Cortex's task tool reaches hooks as `Task`). It applies the same allowlist and caps plus two Cortex-only rules: a per-call model must be a full `claude-sonnet-*` / `claude-haiku-*` id, and Cortex's own Snowflake agents (`snowflake-object-discovery`, `semantic-view-transform`, `dbt-verify`, `sql-verify`, `feedback`), which pin no model and have no borg equivalent, are allowed only with such a pin, for example `model: "claude-sonnet-5-5"`. `Explore`, `Plan` and `general-purpose` stay denied in favor of the borg agents. Like the plugin hook in Claude Code it applies to every session on the machine; the kill switch is the same.
- **Run log.** Cortex hands SubagentStop the conversation snapshot `<id>.json`, which holds no turns. `hooks/borg-nanoprobe-log.sh` and `borg nanoprobes` read `<id>.history.jsonl` beside it for the model, the effort and the writes (lowercase tool names, `status: "error"` for a failed call).
- **Not enforced in Cortex.** The verifier and nanoprobe write guards key on the `agent_type` of a tool call, which Cortex's PreToolUse payload does not carry, so they are not registered there. The research-tools exception reads Claude transcripts only. Team-mode `spawn_teammate` calls do not reach the `Task` matcher.
- **Model choice.** The agents pin the same Claude models in both CLIs: Sonnet 5.5 for the nanoprobe, researcher, reviewer and verifier, Haiku 5.5 (public preview in Cortex as of 2026-10-30) for the scout and grunt. Cortex offers many more (OpenAI, Gemini, Grok, Mistral and others), but borg's prompts and handback contracts are tuned on Claude, and in Cortex the spend was in `max` effort and in built-in agents running the session's Opus, which the effort setting and the guard address. Change a pin for Cortex only with eval evidence, and then as one install-time rewrite in `_borg_install_cortex_agents`, never a second set of agent files.
- **Tests.** `evals/cortex-agents/live.sh` drives headless Cortex (stream-json; `--print` is refused on trial and subscription accounts) through three scripted sessions in a throwaway repository and grades what Cortex did: name resolution, pins, effort, aliases, the guard's live decisions and the logger's rows. `--record` writes a sanitized copy to `evals/cortex-agents/recorded/`, which `evals/cortex-agents/run.sh` (offline, run by CI's `eval-changed`) re-grades, replays through this checkout's guard and logger, and checks against known-bad variants. Re-run `live.sh --record` after a Cortex update.

## Practical tips

- **Grunt before nanoprobe.** If the orchestrator has already written a precise spec, dispatch a grunt. If the spec still needs refinement, write the spec first.
- **Scout before reading.** When you need to locate something before editing, send a scout rather than reading files in the main loop.
- **Parallelize grunts and scouts freely.** They are cheap and stateless.
- **One nanoprobe per concern.** Split unrelated files or systems across nanoprobes.
- **Reviewer always arrives cold.**
- **Opus stays in the main loop.** Hard open-ended reasoning belongs to the Queen or drone session itself, not a delegated agent.
