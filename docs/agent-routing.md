# Agent Routing Guide

> Lives in `docs/`, not `agents/`: a file in `agents/` registers as a spawnable agent type and is never injected into context. The short card is injected at SessionStart by `hooks/borg-link-down.sh`. Two PreToolUse hooks enforce the policy below: `hooks/borg-agent-model-guard.sh` (`Agent`/`Task` tool) and `hooks/borg-workflow-model-guard.sh` (`Workflow` tool).

## Policy

**Orchestrator and drone sessions run Opus at xhigh. Every subagent they spawn must be BELOW that tier: Sonnet or Haiku, effort at most `high`.** The single exception is research-tools.

- **Session tier.** The orchestrator and drone session tier (Opus at xhigh or max effort) comes from the user's own launch or settings; the `borg` and `drone` launchers start a plain `claude` and do not pin it. `/effort max` is a per-session choice.
- **Why a guard, not a convention.** An unpinned subagent inherits the session model AND effort, so it would run Opus xhigh. `CLAUDE_CODE_SUBAGENT_MODEL` does not reach `Agent`-tool forks or Workflow `agent()` calls. Effort matters as much as model: cache reads cost the same on Opus and Sonnet, so a high-effort Sonnet agent can still be expensive.
- **Deny-by-default allowlist** of `subagent_type` (Agent tool) / `agentType` (Workflow `agent()`):
  - `borg-collective:borg-scout`, `borg-collective:borg-grunt`, `borg-collective:borg-nanoprobe`, `borg-collective:borg-researcher`, `borg-collective:borg-reviewer`, `borg-collective:borg-verifier`
  - `claude-code-guide`
  - `research-tools:*`, only in a session where a research-tools skill was invoked (below)
- **Denied:** no type at all (a fork), `general-purpose`, `Explore`, `Plan`, `fork`, `claude`, `borg-collective:ROUTING`, un-namespaced specialist names, and any unlisted type. Each deny message names what to use instead (for example, `Explore` becomes `borg-collective:borg-scout` for read-only search).
- **Caps on allowed types.** A per-call `model` must be absent or `sonnet` / `haiku` (or a `claude-sonnet-*` / `claude-haiku-*` id). A per-call `effort` must be absent or `low` / `medium` / `high`. `opus`, `fable`, `inherit`, `xhigh`, `max` are denied. The specialists carry their own cheap `model:` / `effort:` frontmatter, so the default is already compliant.
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
- **borg-verifier**: verification of a deliverable against its acceptance criteria.
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

- The options argument must be an inline object literal; `agentType`, `model` and `effort` must be string literals (a `const` holding a literal is resolved). Variables, spreads, computed keys and expressions are denied.
- `agent` referenced without being called (alias, `.map(agent)`, destructuring) is denied.
- A script that cannot be parsed, a `scriptPath` that cannot be read, and a saved-workflow `name` that cannot be found in `.claude/workflows` (project, then parents) or `~/.claude/workflows` are denied. Saved workflows and `scriptPath` files are checked like inline scripts.
- There is no inline escape hatch (the old inherit-on-purpose comment is gone).
- Prose that merely contains `agent(` (template-literal prompts, strings, comments, regex literals) is not a call and is not flagged.

Stage guidance:

- Read-only locate/inventory: `agentType: 'borg-collective:borg-scout'`
- Mechanical edits, test runs: `agentType: 'borg-collective:borg-grunt'`
- Analysis, synthesis, drafting: `agentType: 'borg-collective:borg-nanoprobe'`
- From-zero web research: `agentType: 'borg-collective:borg-researcher'`
- Blind review or merge gate: `agentType: 'borg-collective:borg-reviewer'`
- Ad hoc, no specialist fits: `model: 'sonnet', effort: 'medium'`

- **Compose with the specialists.** A specialist brings both its cheap model and its system prompt; prefer it over a bare `model` pin.
- **The gate stage is worth Sonnet-high, not Opus.** Independence and rigor come from the blind setup and the high effort, not from the top tier.

## Practical tips

- **Grunt before nanoprobe.** If the orchestrator has already written a precise spec, dispatch a grunt. If the spec still needs refinement, write the spec first.
- **Scout before reading.** When you need to locate something before editing, send a scout rather than reading files in the main loop.
- **Parallelize grunts and scouts freely.** They are cheap and stateless.
- **One nanoprobe per concern.** Split unrelated files or systems across nanoprobes.
- **Reviewer always arrives cold.**
- **Opus stays in the main loop.** Hard open-ended reasoning belongs to the orchestrator or drone session itself, not a delegated agent.
