# Directive: Nanoprobe Orchestrator

*Filed: 2026-05-07 — Tier P0 — Estimated: 1 session*
*Replaces: docs/plans/severed/2026-05-03-agentic-orchestrator.md*

## Why this exists

The diagnosis from the v1 directive is still right: the orchestrator session should spawn, monitor,
and synthesize — never edit project files inline. The v1 implementation plan is wrong. It proposed
a hand-rolled brief template, a bespoke `agents.json` registry, and a `borg spawn` CLI as the
primary path. Claude Code already ships every primitive that work was reaching for: subagent YAML
frontmatter (the brief), `isolation: worktree` (parallel-safe project edits), `background: true`
(non-blocking spawn), persistent transcripts at `~/.claude/projects/.../subagents/`, and
`SubagentStop` lifecycle hooks. Cortex Code reads the same `~/.claude/agents/` directory, so a
single agent file gets parity for free. The architectural review at
`docs/plans/reviews/2026-05-07-agentic-orchestrator-review.md` walks through which v1 phases are
redundant, which are partial, and which are worth keeping.

This directive ships the keep-pile only. One agent definition file, one lifecycle hook, two thin
CLI subcommands, one paragraph appended to the orchestrator's system prompt. ~3-4 hours of work.
Total custom code is the gap between native subagents and "give me a cross-session view of what
borg has spawned across all my projects" — about 70 lines.

The terminology shift is intentional. **Drones** are persistent devcontainers (long-lived, one
per project). **Nanoprobes** are ephemeral subagents — single-purpose units injected by the
orchestrator (or by a drone) to perform a discrete assimilation. The Borg framing maps cleanly
onto Claude Code's drone/subagent split and keeps the two concepts from blurring in conversation
and command names.

## Deliverables

### 1. `agents/borg-nanoprobe.md`

Lives in the repo at `agents/borg-nanoprobe.md`; `install.sh` symlinks (or copies) it to
`~/.claude/agents/borg-nanoprobe.md`. That path is shared between Claude Code and Cortex Code,
so both CLIs discover the same file with no extra plumbing.

Frontmatter:

```yaml
---
name: borg-nanoprobe
description: Single-task project worker. The orchestrator delegates here instead of editing inline.
tools: Bash, Read, Edit, Write, Grep, Glob
model: sonnet
isolation: worktree
background: true
permissionMode: acceptEdits
---
```

Note the conservative `tools:` — no `Agent` (no recursive nanoprobe spawning), no `WebFetch`/
`WebSearch` (out of scope for project edits). System prompt is the brief skeleton from v1,
trimmed to what subagent frontmatter doesn't already cover:

- Project name, repo path, working branch (filled by the orchestrator's invocation prompt).
- "Read first" list — `PROJECT_PLAN.md`, recent files in `.borg/checkpoints/`, any active
  directives in `docs/plans/directives/`.
- "Do NOT touch" list — pulled from project conventions (e.g. lockfiles, generated artifacts).
- Verify command — typically `drone exec <project> -- pytest` or the project's lint command.
- Completion signal — commit on the worktree branch, then exit.
- **Devcontainer clause:** "If the project has `.devcontainer/`, run all commands via
  `drone exec <project> -- <cmd>`. Your worktree path is not the registry path; `cd` to the
  registry path before invoking `drone exec`."

### 2. `hooks/borg-nanoprobe-log.sh`

Registered as a `SubagentStop` hook in `config/claude/settings.base.json` (so `install.sh`
propagates it to `~/.claude/settings.json` like every other borg hook). Reads stdin JSON,
extracts `subagent_type`, `session_id`, `agent_id`, `started_at`, `finished_at`, `exit reason`,
and a one-line result summary. Appends a single JSONL record to `~/.config/borg/agents.jsonl`:

```json
{"id": "...", "project": "...", "agent_type": "borg-nanoprobe", "task": "...",
 "started_at": "...", "finished_at": "...", "status": "completed|stopped|error",
 "summary": "...", "transcript_path": "~/.claude/projects/.../subagents/agent-<id>.jsonl"}
```

Strict-mode bash, atomic append, exit 0 on any failure (don't break sessions on log writes).

### 3. `borg nanoprobes` and `borg nanoprobe-log <id>` subcommands

`borg nanoprobes` (alias `borg np`) — list recent entries from `agents.jsonl`, newest first:

```
<id>  <project>  <task>  <status>  <duration>
```

`jq`-driven, ~20 lines of zsh in `borg.zsh`.

`borg nanoprobe-log <id>` — `cat` the persistent transcript at the path stored in the JSONL
entry, falling back to printing the JSONL record itself if the transcript is gone (retention
expired). ~10 lines.

Implementation budget: ~30 lines of zsh total in `borg.zsh`. No new lib file.

### 4. Orchestrator CLAUDE.md addendum

One paragraph merged into `cmd_init`'s appended system prompt in `borg.zsh` (currently the
appended-prompt block lives around line 1635 — confirm the actual line when editing):

> When the developer asks for project work, spawn the `borg-nanoprobe` agent via the Agent
> tool with `isolation: worktree` and `background: true`. Never edit project files from this
> orchestrator session — your role is to spawn / monitor / synthesize. Use `borg nanoprobes`
> to see what's running and `borg nanoprobe-log <id>` to read transcripts.

## Acceptance criteria

- [ ] `agents/borg-nanoprobe.md` exists in the repo with the frontmatter and system prompt
      above; `install.sh` copies or symlinks it into `~/.claude/agents/borg-nanoprobe.md`
- [ ] `hooks/borg-nanoprobe-log.sh` exists, is registered as a `SubagentStop` hook in
      `config/claude/settings.base.json`, and appends one JSONL line per completion
- [ ] Verified by spawning a test nanoprobe end-to-end and observing the JSONL line in
      `~/.config/borg/agents.jsonl`
- [ ] `borg nanoprobes` lists recent entries; `borg np` works as alias
- [ ] `borg nanoprobe-log <id>` prints the transcript when present, the JSONL entry otherwise
- [ ] Orchestrator system prompt addendum landed in `borg.zsh cmd_init`
- [ ] `README.md` includes a drone-vs-nanoprobe vocabulary table
- [ ] `CLAUDE.md` (project handoff) gains a Nanoprobe Orchestrator architecture note alongside
      the existing `drone scaffold` / borg-hooks sections
- [ ] Borg version bump and release

## Out of scope (deferred)

- **`borg spawn <project> "<task>"` CLI.** Use the Agent tool from the orchestrator session,
  or `claude --agent borg-nanoprobe` directly, until a workflow demand emerges. The CLI
  command is a convenience wrapper, not a missing capability.
- **`borg mcp serve`.** Exposing borg's registry and spawn surface as an MCP server is the
  right long-term move and makes the orchestrator's spawn calls native tool invocations
  rather than shell-outs. Premature now; revisit after this directive ships and the
  nanoprobe pattern proves its keep.
- **Project-type-aware spawn routing** (Snowflake → cortex, web → claude). Defer until
  there's a Snowflake project in the registry. Adds a `type:` field on registry entries and
  a one-line dispatcher in `cmd_spawn` when it lands.
- **`agents/borg-snowflake-nanoprobe.md`** — Cortex-specialized variant with `skills: [cortex-rules]`
  and Snowflake tool restrictions. Defer until a Snowflake project exists. Because both CLIs
  read from `~/.claude/agents/`, parity is automatic until the variant lands.
- **Cairn integration.** Tracked separately in `2026-05-07-cairn-restoration.md` over in the
  cairn repo. Don't gate this directive on it. Native `~/.claude/agent-memory/` covers
  agent-scoped memory in the meantime.
- **`lib/agent-brief-template.md`.** Replaced by `agents/borg-nanoprobe.md` — the agent file
  *is* the brief.

## Risks

- **`SubagentStop` payload shape needs verification.** The review cites it as the right hook,
  but the JSON contract has not been directly tested in this codebase. If the payload doesn't
  carry enough metadata (especially `task` text and a result summary), the log line may need
  to be assembled from a `Stop` hook running inside the nanoprobe itself. Confirm this in the
  first hour of implementation before writing the rest of the hook.
- **Worktree path vs. registry path.** `isolation: worktree` puts the nanoprobe in a Git
  worktree at a path that is not the registry's project directory. Any `drone exec <project>`
  invocation resolves the project by name from the registry, but the nanoprobe's `cwd` won't
  match. The system prompt instructs the nanoprobe to `cd` to the registry path before calling
  `drone exec` — verify this works in practice. May need a helper or env var.
- **`~/.claude/agents/` precedence.** If a project ships its own `.claude/agents/borg-nanoprobe.md`,
  Claude Code's resolution order needs to be documented. Decision to record once verified:
  prefer project-local override (so projects can specialize) but log a warning in the
  nanoprobe summary when the override fires, so the orchestrator knows the global behavior was
  bypassed.
- **`SubagentStop` and Cortex Code parity.** The review's strong implication is that Cortex
  fires this hook with the same JSON contract; not directly tested. If Cortex diverges, the
  log-hook may need a CLI-detection branch. Not a blocker for shipping the Claude Code path.

## References

- Architectural review: `docs/plans/reviews/2026-05-07-agentic-orchestrator-review.md`
- Severed v1: `docs/plans/severed/2026-05-03-agentic-orchestrator.md`
- Claude Code subagents: <https://code.claude.com/docs/en/sub-agents>
- Claude Code hooks: <https://code.claude.com/docs/en/hooks>
- Cortex Code extensibility: <https://docs.snowflake.com/en/user-guide/cortex-code/extensibility>
