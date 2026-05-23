---
addendum_to: analysis.md
source: /Users/noah/dev/borg-collective/docs/plans/reviews/2026-05-07-agentic-orchestrator-review.md
date: 2026-05-22
note: Captured AFTER the initial positioning-refresh research pass. The nanoprobe's
  Phase 2 source list scanned docs/research/ and docs/plans/directives/ but missed
  docs/plans/reviews/. This addendum incorporates findings the original analysis
  didn't see.
---

# Addendum — Findings from the 2026-05-07 Agentic Orchestrator Review

The May 7 multi-reviewer review (Anthropic Core Engineer + Snowflake Data Superhero +
Pragmatic Maintainer personas) is the most tactically concrete document in the
borg-collective strategic corpus. It significantly sharpens the positioning-refresh
recommendations and was not surfaced in the initial research pass.

## How this changes the original analysis

The original analysis identified three layers (Philosophy / Skills + Hooks / CLI
plumbing) and recommended freezing CLI plumbing investment. **This review answers the
"what specifically to cut" question with concrete code-level guidance.**

### What's actually redundant (60–70% of CLI plumbing)

| Borg-collective capability | Native Claude Code facility (post-directive) |
|---|---|
| `lib/agent-brief-template.md` | Subagent YAML frontmatter at `~/.claude/agents/*.md` |
| Bespoke `agents.json` schema | `SubagentStop` hook + transcript at `subagents/agent-*.jsonl` |
| `borg spawn <project> "<task>"` | `claude --agent borg-worker --append-system-prompt "..."` |
| "One agent per project at a time" | `isolation: worktree` makes the constraint unnecessary |
| Agent-scoped memory | `memory: user|project|local` frontmatter at `~/.claude/agent-memory/` |
| `/agents` interactive UI | Native UI ships with Claude Code |

### What's genuinely missing (legit borg territory)

- **Cross-session agent registry.** Subagent transcripts are session-scoped; borg can
  aggregate across sessions/projects with ~40 lines of `SubagentStop` hook.
- **MCP server exposing the registry.** `borg mcp serve` so the orchestrator session
  calls `mcp__borg__spawn(project, task)` as a *native tool* instead of shelling out.
  This is the actual agentic-orchestrator pattern.
- **Project-type-aware spawn routing.** Snowflake projects spawn Cortex workers;
  web/CLI projects spawn Claude workers. Single registry field, single dispatch
  function.
- **Cairn-style cross-project semantic search.** Not in the critical path; subagent
  `memory:` + `agents.jsonl` cover 90% of common queries.

### Cortex Code parity is free (this is huge)

Cortex Code reads from `.claude/agents/`, `.claude/skills/`, `.claude/hooks/` — the
shared paths. Skills format is identical. Hook JSON contracts are identical. Subagent
frontmatter is identical. **Two CLIs are intentionally designed for shared
configuration.**

Implication for the positioning analysis: the "submit `adhd-guardrails` + `borg-plan` +
`borg-assimilate` to the Anthropic marketplace" recommendation (Move 1 in the original
analysis) gets **double distribution for the same work** — the marketplace plugin is
discoverable by both Claude Code and Cortex Code users. The Snowflake-heavy
practitioner segment opens up at zero extra effort.

### MCP server changes the moat shape

The original analysis said borg's CLI plumbing layer has a 12–24 month half-life.
A `borg mcp serve` rewrite is a different bet: instead of competing on CLI orchestration
(crowded), borg becomes a **registry + spawn-routing service** that any AI dev tool can
call via MCP. That's a more defensible position than the current CLI surface.

## Revised tactical recommendations (replacing original Move 3)

Original Move 3 was "stop investing in CLI plumbing growth." The review provides the
concrete refactor path. Updated as:

### Move 3a: Quick-win refactor (~3–4 hours)

1. Define `agents/borg-worker.md` as a versioned subagent file in this repo. Install
   to `~/.claude/agents/borg-worker.md` via `install.sh`. Cortex Code picks it up via
   shared discovery, no extra work.
2. Add `hooks/borg-agent-log.sh` registered on `SubagentStop`. Appends `{id, project,
   task, started_at, ended_at, status, transcript_path}` to `~/.config/borg/agents.jsonl`.
3. Add `borg agents` (list) and `borg agent-log <id>` (cat transcript) as ~30-line
   `jq`/`cat` wrappers around the JSONL.
4. Append one paragraph to the orchestrator's system prompt
   (`borg.zsh:cmd_init` ~line 1635): "Delegate via the `borg-worker` agent with
   `isolation: worktree`. Never edit project files from this session."
5. Drop the "one agent per project at a time" scope boundary entirely.

### Move 3b: MCP server (defer 1–2 sessions out)

Expose registry + scan tooling + checkpoint reading + `spawn(project, task)` as MCP
tools via `borg mcp serve`. Orchestrator calls become native tool invocations. This is
the "right way" agentic orchestrator architecture and makes much of the remaining CLI
surface obsolete in a good way.

### Move 3c: What to cut from the existing directive

- `lib/agent-brief-template.md` — replaced by `~/.claude/agents/borg-worker.md`
- Bespoke `~/.config/borg/agents.json` schema — replaced by JSONL appended from a hook
- `borg spawn` as a phase deliverable — replaced by `claude --agent` wrapper, then later by MCP server
- "One agent per project at a time" boundary — `isolation: worktree` removes it
- Cairn dependency in critical path — Phase 4 of the original directive is decoupled

## Verdict update

The original analysis was directionally right but lacked code-level specificity. With
this review's input, the borg-collective positioning + tactical plan converges on:

- **Position:** "the cognitive-load layer for parallel AI coding" (unchanged)
- **Brand structure:** sister brand with light Stillpoint heritage attribution (unchanged)
- **Distribution:** ship the three skills to Anthropic's marketplace (unchanged, but now: ships to Cortex Code users for free via shared discovery)
- **CLI plumbing:** *Refactor down to* `agents/borg-worker.md` + `SubagentStop` hook + `jq`/`cat` wrappers, plus a deferred MCP server bet. *Cut* the agent-brief-template, bespoke registry, spawn CLI as primary path, and parallelism boundary.

## Source

Full review at: `/Users/noah/dev/borg-collective/docs/plans/reviews/2026-05-07-agentic-orchestrator-review.md`

The review documents its grounding in Claude Code subagents docs, hooks reference,
worktrees guide, agent-teams guide, and Cortex Code extensibility docs.
