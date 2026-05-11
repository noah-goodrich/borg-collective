# Review: Agentic Orchestrator Directive

*Reviewed: 2026-05-07*
*Directive: [2026-05-03-agentic-orchestrator.md](../directives/2026-05-03-agentic-orchestrator.md)*
*Reviewers: The Anthropic Core Engineer, The Snowflake Data Superhero, The Pragmatic Maintainer*

## Reviewer's note on grounding

This review is grounded in Claude Code documentation as of May 2026 — primarily
[code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents),
[code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks), and
[docs.snowflake.com/en/user-guide/cortex-code/extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility).
Claims I could not verify in those sources are flagged inline. The directive predates several relevant Claude Code
features (TaskCreated/TaskCompleted hooks, `isolation: worktree`, the `/agents` interface, named background subagents,
`--agent` whole-session mode), which materially changes the build-vs-buy math.

---

## 1. The Anthropic Core Engineer reacts

> "I read the directive twice. The diagnosis is right — Claude-as-orchestrator should spawn, monitor, synthesize. The
> proposed implementation re-builds three things we already ship. Let me go phase-by-phase."

### Phase 1 — Structured Agent Briefs
**Verdict: 70% redundant.** A subagent's *system prompt* is its brief. We already provide a YAML frontmatter contract
that handles every field the directive enumerates, plus several it doesn't:

```yaml
---
name: project-worker
description: When to delegate to me
tools: Read, Edit, Bash, Grep, Glob   # off-limits handled by omission/disallowedTools
model: sonnet                          # or haiku for cheap workers
isolation: worktree                    # repo isolation, no manual branch dance
background: true                       # concurrent execution
permissionMode: acceptEdits            # pre-approved permissions
hooks: { ... }                          # per-agent lifecycle hooks
skills: [borg-link, simplify]          # full skill content injected at startup
---
You are a worker on the {project_name} repo.

Read first: PROJECT_PLAN.md, recent checkpoints in .borg/checkpoints/.
Do NOT touch: ...
Verify with: ...
```

Define this once at `~/.claude/agents/borg-worker.md`. The directive's `lib/agent-brief-template.md` then collapses
to a thin variable-substitution layer — fields like `{project_name}`, `{task_description}`, `{off_limits}` go in via
the *invocation prompt*, not the system prompt. **Don't reinvent the brief container; reinvent only the
project-specific fill-ins.**

What the directive adds that subagents don't: a written record of "we always ask for these fields." That's a half-page
of skill docs, not a `lib/` template.

### Phase 2 — Agent Spawn Registry
**Verdict: 60% redundant, but partially useful.** Three native facilities cover the majority of this:

1. **`/agents` interactive command** has a "Running" tab listing live subagents with open/stop controls.
2. **`claude agents`** lists all configured subagents from the CLI (grouped by source, not invocation history).
3. **Subagent transcripts** persist at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`. Every
   spawn is already recorded with full reasoning, tool calls, and result. The `cleanupPeriodDays` setting (default 30)
   handles retention.
4. **Hooks `SubagentStart` / `SubagentStop` / `TaskCreated` / `TaskCompleted`** fire on the lifecycle events the
   directive wants to track. They receive `agent_id`, `agent_type`, `result`, `task_id`, etc.

If you want a borg-flavored `agents.json`, the right shape is: a `SubagentStop` hook that appends one line to
`~/.config/borg/agents.jsonl` with `{id, project, task, started_at, ended_at, status, summary_path}`. ~40 lines of
bash. **Do not duplicate the transcript content** — store a pointer (`summary_path`). The `borg agents` command becomes
a `jq` over the JSONL, with `borg agent-log <id>` cat'ing the linked transcript.

What's still genuinely missing: a *cross-session* registry. Subagent transcripts are scoped to the parent session.
Borg legitimately wants to answer "what agents have I spawned across all projects this week?" That's a value-add over
native — and only ~20 lines of hook code.

### Phase 3 — `borg spawn <project> "<task>"` CLI
**Verdict: Probably skip.** Two native paths already do this:

1. **`claude --agents '{...}' --agent <name>`** launches a Claude session where the entire main thread *is* the agent
   — own system prompt, own tools, own model. A `borg spawn reveal "fix logo PNG"` becomes a 5-line shell wrapper:
   `cd $project && claude --agent borg-worker --append-system-prompt "Task: $task"`. We already have
   [borg.zsh:1653-1656](../../../borg.zsh) (`cmd_claude`) and [drone.zsh `drone claude`](../../../drone.zsh) doing
   90% of this — the gap is "pass the task as initial prompt."

2. **MCP server.** If you want the orchestrator session itself to spawn workers, expose borg's registry as an MCP
   server (`borg mcp serve`). Then the orchestrator reads `mcp__borg__list_projects`, `mcp__borg__spawn(project, task)`,
   `mcp__borg__agent_log(id)` as native tools. The orchestrator no longer shells out to `borg spawn`; it calls a tool.
   That's the *actual* "agentic" pattern, and it's the one I'd build if I had a week.

The CLI command is fine as a human-facing convenience. But the directive frames it as the orchestrator's primary spawn
path, which is the wrong layer. The orchestrator should call MCP tools, not shell commands.

### Phase 4 — Cairn fix
**No comment from me.** This is borg-domain plumbing, not a Claude Code feature. Note though: Claude Code now ships a
**persistent memory directory** for subagents (`memory: user|project|local` in frontmatter) at
`~/.claude/agent-memory/`. For *agent-scoped* learnings, that's now native. Cairn remains the right answer for
*cross-project, queryable* knowledge, but you're competing with a built-in for the simpler cases.

### What the directive misses entirely
- **`isolation: worktree`** — the directive says "one agent per project at a time" as a scope boundary. Worktree
  isolation makes that boundary unnecessary. Multiple parallel agents on the same project, each on its own branch, no
  conflicts. Auto-cleaned if no changes were made.
- **Forks** (`/fork`, `CLAUDE_CODE_FORK_SUBAGENT=1`) — for "spawn a worker that already knows everything I just told
  you," forks beat structured briefs. The fork inherits the parent's full conversation, system prompt, and prompt
  cache. *Cheaper* than a fresh subagent.
- **Plugin distribution.** If the orchestrator pattern is good, ship it as a plugin (`borg-orchestrator.plugin`) with
  `agents/borg-worker.md`, `skills/borg-spawn-rules/SKILL.md`, and an MCP server. Then anyone can install it without
  forking the repo.

---

## 2. The Snowflake Data Superhero reacts

> "Three things matter to me: (a) does this work in Cortex too, (b) does it respect Snowflake governance, (c) what's
> the maintenance cost of keeping the two CLIs in sync? Let me weigh in."

### Cortex Code parity (the hidden landmine)
This is the most important finding in the review and it's not in the directive at all.

Per
[docs.snowflake.com/en/user-guide/cortex-code/extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility),
**Cortex Code reads from `.claude/skills/`, `.claude/agents/`, `.claude/hooks/` in addition to its own
`~/.snowflake/cortex/...` paths.** Skills format is identical (Markdown + YAML frontmatter). Hook JSON contracts are
identical. Subagent frontmatter is identical. MCP `mcp.json` schema is identical. The two CLIs are *intentionally
designed for shared configuration*.

This means:
- **Subagents written for Phase 1-3 work in both CLIs for free** if we put them in `~/.claude/agents/`.
- **The agent registry hook (Phase 2)** works for both — `SubagentStop` fires identically in Cortex per the dev.to
  guide. We get Cortex coverage with zero extra code.
- **The `borg spawn` CLI** is the one place we'd diverge: `claude --agent` vs. presumably `cortex --agent` (I'm not
  certain Cortex has the `--agent` whole-session flag — *worth verifying with `cortex --help`*).

### Cortex-specific differences worth respecting
- Cortex has built-in **`[REQUIRED]` skills** that auto-load on Snowflake-domain questions. Borg's skills should not
  collide with these names (e.g. don't name a skill `data-engineering`).
- Cortex's MCP server expansion in 2026 means `mcp__cortex__snowflake_sql_execute` and similar tools are first-class.
  An orchestrator pattern that assumes "Claude does the work" needs to also handle "Cortex does the work" — a
  Snowflake-heavy project should spawn a Cortex agent, not a Claude agent.
- **ACCOUNT_USAGE timeouts** — already in `~/.config/dotfiles/claude/code/CORTEX_RULES.md`. If the orchestrator
  spawns Cortex workers for Snowflake projects, that ruleset must be injected as a skill or system-prompt addendum.
  Easy with `skills: [cortex-rules]` in the agent frontmatter.

### Sub-agent count constraint
Cortex docs reference parallel execution "up to 50 concurrent instances" per the dev.to write-up. Claude Code
practical ceiling is **4-8 concurrent worktrees per developer reliably** per the worktrees guide. Whichever ceiling
matters, the directive's "one agent per project at a time" is an artificial constraint. Drop it.

### My recommended factoring
- `~/.claude/agents/borg-worker.md` — single shared subagent file. Read by both Claude Code and Cortex Code.
- `~/.claude/agents/borg-snowflake-worker.md` — Snowflake-specialized variant with `skills: [cortex-rules]` and
  Snowflake-aware off-limits.
- `borg.zsh` `cmd_spawn()` decides which agent to invoke based on project type (registry has a `type: snowflake|web|cli`
  field? If not, add one). Calls `claude --agent borg-worker` OR `cortex --agent borg-snowflake-worker`.
- Single hook script at `~/.claude/hooks/borg-agent-log.sh` registered on `SubagentStop` for both CLIs.

**Two skill files, conditionally invoked. Not symlinks. Not CI parity checks. Different agents for different work.**
That's what the platform is built for.

### Open questions for me
- Does `cortex --agent <name>` exist as a flag? *Could not verify in Snowflake docs.*
- Does Cortex's `SubagentStop` hook fire identically to Claude Code's, with the same JSON contract? *Strong implication
  yes from the docs, but not directly tested.*
- Does Cortex Code support `isolation: worktree`? The dev.to guide says yes; Snowflake's official extensibility page
  doesn't enumerate the field.

---

## 3. The Pragmatic Maintainer synthesizes

You have an ADHD-friendly cognitive-load constraint. You have a 2,463-line `borg.zsh` that's already past the comfort
threshold for a side project. You have a directive that proposes adding a registry, a CLI command, a template file,
and a cairn dependency. **Most of that is duplicating native features.** Here's the call.

### Capability gap analysis (what's actually missing vs. what isn't)

| Directive want                    | Native facility                                                  | Real delta                                          |
| --------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------- |
| Standard agent brief              | Subagent YAML frontmatter + system prompt body                   | Borg-specific *task fill-ins* (~30 lines of skill)  |
| `lib/agent-brief-template.md`     | `~/.claude/agents/borg-worker.md`                                | None — use the native location                      |
| Track running agents              | `/agents` Running tab; `claude agents`; subagent transcripts     | Cross-session aggregation (~40 lines of hook)       |
| Track completed agents w/ summary | `SubagentStop` hook + transcript at `subagents/agent-*.jsonl`    | A pointer index in `agents.jsonl`                   |
| `borg agents` list                | `/agents` interactive UI                                         | Headless CLI access (~10 lines `jq` over jsonl)     |
| `borg agent-log <id>`             | `cat ~/.claude/projects/.../subagents/agent-<id>.jsonl`          | Convenience wrapper (~5 lines)                      |
| `borg spawn <project> "<task>"`   | `claude --agent borg-worker` + initial prompt; or MCP server     | Project-resolution + tmux placement (you have this) |
| Cairn for synthesis               | Subagent `memory: user`; agent_team shared task list             | True cross-project graph queries                    |
| Orchestrator-never-executes rule  | CLAUDE.md addendum + `borg-worker` agent's restricted toolset    | Documentation (~1 paragraph)                        |
| Parallelism control               | `isolation: worktree` + `background: true`                       | None — use it                                       |

### Quick wins (do this week, ROI: huge)

1. **Define `~/.claude/agents/borg-worker.md`** as a versioned subagent file in this repo, symlinked at install. ~30
   minutes. Replaces Phase 1 entirely. Works in Cortex Code via shared `.claude/agents/` discovery.

2. **Add a `SubagentStop` hook** at `hooks/borg-agent-log.sh` that appends `{id, project, task, started_at, ended_at,
   status, transcript_path}` to `~/.config/borg/agents.jsonl`. Register in [install.sh](../../../install.sh) alongside
   the existing hooks. ~40 lines. Replaces Phase 2's bespoke registry.

3. **Add `borg agents` (list) and `borg agent-log <id>` (cat transcript)** as ~30-line `jq`/`cat` wrappers around the
   jsonl. Replaces Phase 2's CLI surface.

4. **Update orchestrator's CLAUDE.md** ([borg.zsh cmd_init at ~1635](../../../borg.zsh)) with one paragraph: "When the
   developer asks for project work, spawn the `borg-worker` agent with `isolation: worktree`. Never edit project files
   from this session." Replaces the "never execute project work inline" acceptance criterion. ~5 lines of prompt.

5. **Add `isolation: worktree` to `borg-worker.md` frontmatter.** Drop the directive's "one agent per project at a
   time" scope boundary. Native isolation handles it.

**Total quick-win effort: ~3-4 hours. Replaces Phases 1, 2, and the rule-setting half of the directive.**

### Long-term projects (genuinely custom code, do later)

These do *not* have native equivalents and justify the work:

1. **`borg mcp serve`** — expose the registry, scan tooling, checkpoint reading, and `spawn(project, task)` as MCP
   tools. The orchestrator session calls these as native tool invocations, not shell commands. This is the *actual*
   agentic-orchestrator architecture and it makes Phase 3 obsolete in the right way. Effort: 1-2 sessions. ROI: high
   long-term, low short-term — defer until you've proven the workflow with the quick wins above.

2. **Project-type detection** for spawn routing (Claude vs. Cortex worker). Add `type: snowflake|web|cli|...` to
   registry entries during scan. `borg spawn` reads the type and chooses the CLI/agent. Effort: ~1 hour for the
   classifier, ~30 min to wire into spawn. Defer until you actually have a Snowflake project in the registry.

3. **Cairn fix (Phase 4)** — independent track. Don't gate the orchestrator work on it. Subagent `memory:` frontmatter
   covers per-agent learning, and the directive's `~/.config/borg/agents.jsonl` covers cross-session aggregation. Cairn
   adds: cross-project semantic search. That's still valuable, but it's not in the orchestrator critical path.

### What I'd cut from the directive

- ❌ `lib/agent-brief-template.md` — replaced by `~/.claude/agents/borg-worker.md`.
- ❌ Bespoke `~/.config/borg/agents.json` schema — replaced by JSONL appended from a hook.
- ❌ `borg spawn` as a phase deliverable — replaced by `claude --agent` wrapper + future MCP server.
- ❌ "One agent per project at a time" scope boundary — `isolation: worktree` removes the constraint.
- ❌ Cairn dependency in critical path — Phase 4 is unblocked-but-decoupled.

### Cortex/Claude parity strategy (concrete proposal)

Ship a single `~/.claude/agents/borg-worker.md` file. Both CLIs discover it via the shared `.claude/agents/` path. For
Snowflake work, ship a second `~/.claude/agents/borg-snowflake-worker.md` whose frontmatter declares
`skills: [cortex-rules]` and Snowflake-specific tool restrictions.

`borg.zsh` `cmd_spawn` chooses by project type; the agent file is the same on disk for both CLIs. **No symlinks, no
duplicated markdown, no CI parity check.** If a feature genuinely needs to differ (e.g. a Cortex-only `snowflake_sql_execute`
tool), it lives in `borg-snowflake-worker.md`'s `tools:` list and is a no-op in Claude Code.

The single thing that requires explicit divergence is the `borg spawn` CLI: it shells out to `claude --agent` or
`cortex --agent` based on type. That's already where divergence belongs — the spawning layer, not the agent definition.

---

## 4. Final recommendation

**Sever the directive as written. Replace it with a much smaller revised plan.**

The directive's diagnosis ("orchestrator should spawn-monitor-synthesize, not execute inline") is correct and worth
acting on. The proposed implementation predates several Claude Code features that subsume 60-70% of the proposed
custom code. Executing it as-is would produce a parallel system to one you already have access to, increase the
maintenance surface of `borg.zsh`, and create a Cortex-parity headache that's avoidable.

### Recommended replacement: "Agentic Orchestrator v2" directive

Three deliverables, ~one session of work:

1. **`agents/borg-worker.md`** in the repo, installed to `~/.claude/agents/borg-worker.md` by `install.sh`. Includes
   `isolation: worktree`, `background: true`, conservative tool list, system prompt with the brief structure the
   directive proposed.
2. **`hooks/borg-agent-log.sh`** registered on `SubagentStop`. Appends a JSONL line per agent completion.
3. **`borg agents` and `borg agent-log <id>`** subcommands in `borg.zsh` — `jq` over the JSONL, `cat` the transcript.

Plus: a one-paragraph addition to the orchestrator session's appended system prompt
([borg.zsh:1635](../../../borg.zsh)) instructing it to delegate via the `borg-worker` agent rather than executing
inline.

**Defer:** `borg spawn` CLI (use `claude --agent` directly until a workflow demand emerges), MCP server for borg, cairn
fix, project-type-aware spawn routing.

**Drop entirely:** `lib/agent-brief-template.md`, the `agents.json` schema design, "one agent per project" boundary.

This gets you 80% of the directive's value at 20% of the cost, ships in one session, costs you nothing in Cortex
parity, and leaves the door open for an MCP server later when you actually need one.

---

## Open questions for Noah (only you can answer)

1. **Do you actually use Cortex Code daily, or is the parity concern theoretical?** If Cortex isn't in your weekly
   rotation, the parity strategy is over-engineered — just build for Claude Code and revisit if/when Cortex usage
   grows. The whole "two skill files" framing collapses to "one file, who cares about Cortex right now."

2. **Is there a project in the registry today where the orchestrator-never-executes-inline rule would have
   prevented a real problem?** If yes, prioritize the CLAUDE.md addendum + `borg-worker` agent file (quick wins #1, #4).
   If you're hand-jamming this rule and it's working fine, the directive's urgency drops to "nice to have."

3. **What's actually broken about cairn, and is fixing it cheaper than replacing it with `~/.claude/agent-memory/`
   (subagent persistent memory) + `agents.jsonl`?** If cairn is "PATH issue + a few weekend hours," fix it. If it's
   "rebuild the indexer," consider whether subagent memory + jsonl covers 90% of what you'd query cairn for.

4. **Are you seeing the "background subagent" path in your current Claude Code sessions?** It changes the spawn
   ergonomics significantly (`Ctrl+B` to background, status appears in the prompt panel). If you've been using
   foreground spawns only, the directive's monitoring concerns are real; if you're already using `background: true`,
   they're partially solved by the prompt-panel UI.

5. **`drone scaffold` already wires up Supabase devcontainers. Do you want `borg-worker` to know about that
   (e.g., agent prompt mentions "if this is a Supabase project, run `supabase start` before tests"), or keep that as
   per-project CLAUDE.md content?** Affects whether the agent file stays generic or grows project-class branches.

---

## Sources

- [Claude Code subagents documentation](https://code.claude.com/docs/en/sub-agents)
- [Claude Code hooks reference](https://code.claude.com/docs/en/hooks)
- [Cortex Code extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility)
- [Claude Code worktrees guide](https://www.claudedirectory.org/blog/claude-code-worktrees-guide)
- [Claude Code agent teams](https://claudefa.st/blog/guide/agents/agent-teams)
- [Cortex Code: skills, subagents, hooks, MCP](https://dev.to/tsubasa_tech/supercharge-cortex-code-cli-a-practical-guide-to-skills-subagents-hooks-and-mcp-lc8)
- [Plan mode reference](https://www.claudedirectory.org/blog/claude-code-plan-mode-guide)
- [Claude Code MCP setup](https://code.claude.com/docs/en/mcp)
