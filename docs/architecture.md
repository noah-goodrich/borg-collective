# Architecture Guide

How every component of Borg fits together.

---

## System Overview

Borg is an AI development orchestration framework with two layers:

1. **`borg` (orchestration)** — Runs on the host. Manages a JSON registry of projects, scores
   priorities, enforces work/life boundaries, launches an orchestrator Claude session for morning
   briefings, and provides the `borg next` / `Ctrl+Space >` hotkey for instant context switching.

2. **`drone` (project lifecycle)** — Runs on the host. Manages Docker Compose containers, tmux
   windows, and pane layouts. Launches Claude Code sessions inside project containers. Forked
   from `dev.sh`.

Knowledge persistence is file-based: user-authored session checkpoints are stored per-project at
`<project>/.borg/checkpoints/`. (Borg previously integrated with cairn, a separate
PostgreSQL+pgvector knowledge graph service, for cross-project semantic recall; cairn was
decommissioned 2026-08-08 and its corpus exported to per-project `.borg/knowledge/` markdown,
which is grep-reachable directly — no service required.)

### Data Flow

```
Session lifecycle:

  drone up project          → Container starts, tmux window created
  drone claude project      → Claude Code session begins
  borg-link-down.sh fires   → Registry: status=active
                            → Injects additionalContext: latest checkpoint
                            ↓
  [developer works]         → Claude uses skills, reads checkpoint from last session
                            ↓
  Claude needs input        → borg-notify.sh fires → Registry: status=waiting + reason
                            ↓
  Developer runs /borg-link-up before stopping:
                            → Skill writes structured checkpoint to
                              <project>/.borg/checkpoints/<YYYY-MM-DD-HHMM>.md
                            ↓
  Session ends              → borg-link-up.sh fires:
                               1. Registry: status=idle
                               2. Warn if uncommitted changes remain
                               3. Nudge if no recent checkpoint exists
```

### Registry Writes

All registry updates are atomic: write to `registry.json.tmp.$$`, then `mv` to `registry.json`.
This prevents corruption from concurrent hook executions.

---

## File System Layout

### Repository

The repo has grown past a size where a full file listing stays accurate for long — run
`ls hooks/ lib/ skills/ agents/ launchd/ bin/` for the current, complete inventory. As of this
writing: **12 hooks**, **~14 lib files**, **16 skills**, **6 agents** (5 specialists + `ROUTING.md`),
**4 launchd plists**, plus `bin/` pollers (`borg-usage-watch`, `borg-cortex-watch`,
`borg-vinculum-watch`, `borg-notifyd`, `run-in`).

```
~/dev/borg-collective/
    borg.zsh                    Main orchestration CLI
    drone.zsh                   Project lifecycle CLI
    lib/
        registry.zsh            Registry CRUD
        tmux.zsh                tmux window listing + switching
        claude.zsh              Session discovery from ~/.claude/projects/
        coco.zsh                Session discovery from ~/.snowflake/cortex/projects/
        desktop.zsh             Claude Desktop session reader
        recon/adapters/         Recon source adapters (recon-adapter-<source>)
        borg-hooks.sh           Shared bash helpers used by hooks (not sourced by borg.zsh)
        borg-sync.zsh           Skill/hook sync helpers
        drone-hooks.zsh         Project-side pre-up/post-down hook runner
        reaper.sh               Stale-worktree reaping (portable sh core for `borg reap-worktrees`)
        colors.zsh, secrets.zsh Output styling + secret handling helpers
    borg_core/                  Python core; the zsh CLI dispatches into it via `_borg_py`
        paths.py                Config-path resolution + defaults
        registry/               Registry read/write core, shell adapter, CLI entry
        recon/                  Recon fan-out engine (ported from the deleted lib/recon.sh)
        manifest/               Reader for <project>/.borg/programs/*.json program manifests
        link/                   `borg link` document build + renderer
    hooks/
        borg-link-down.sh       SessionStart → status=active + checkpoint injection
        borg-link-up.sh         Stop → status=idle + uncommitted warning + checkpoint nudge
        borg-notify.sh          Notification → status=waiting + reason
        borg-plan-promote.sh    PreToolUse (Edit/Write/NotebookEdit) → auto-promote ExitPlanMode plan
        borg-dispatch-guard.sh  PreToolUse → >=92% usage dispatch veto (Usage Guardian)
        borg-nanoprobe-log.sh   SubagentStop → append nanoprobe completion to agents.jsonl
        bash-guard.sh, borg-supabase-guard.sh, notify.sh,
        pre-commit-remind.sh, tool-count-nudge.sh  Smaller guardrail/reminder hooks
    skills/
        adhd-guardrails/        Cognitive load guardrails (always active)
        borg-plan/              Project planning + Collective review
        borg-assimilate/        Shipping checklist + Collective review + execution
        borg-collective-review/ Adversarial multi-persona review (The Collective)
        borg-review/            Mid-session diagnostic + loop detection
        borg-link/              Consolidated project intelligence (overview + deep dive)
        borg-link-up/           Flush session state to a per-project checkpoint file
        borg-recon/             Synthesize cross-source recon fan-out into an ELI10 briefing
        borg-next/, borg-resume/, borg-switch/, borg-verify/, break-glass/,
        simplify/, fable-reviewer/, no-unnecessary-read-perms/   Remaining user-invocable skills
    agents/
        borg-grunt.md            Haiku — fully-specified mechanical execution
        borg-scout.md            Haiku — read-only locate/search
        borg-nanoprobe.md        Sonnet — single-task judgment work (implement/fix/refactor)
        borg-researcher.md       Sonnet — from-zero web research, one track
        borg-reviewer.md         Sonnet/high — blind adversarial review
        ROUTING.md               Model/effort routing matrix for all of the above
    bin/
        borg-usage-watch         Usage Guardian poller (see below)
    launchd/
        com.stillpoint-labs.borg.notifyd.plist       fswatch presence daemon
        com.stillpoint-labs.borg.cortex-wake.plist    30s Cortex Code session watcher
        com.stillpoint-labs.borg.reap.plist           Hourly `borg reap-worktrees`
        com.stillpoint-labs.borg.usage-watch.plist    Usage Guardian poller schedule
    install.sh                  Installer
    docs/                       Documentation
```

### Runtime State

```
~/.config/borg/
    config.zsh                  User configuration (work hours, limits)
    registry.json               Project registry (auto-managed by hooks)

<project>/.borg/
    checkpoints/                User-authored session checkpoints (written by /borg-link-up)
        2026-04-23-1114.md
        2026-04-22-1730.md

~/.claude/
    hooks/
        borg-link-down.sh       Symlink → repo
        borg-link-up.sh         Symlink → repo
        borg-notify.sh          Symlink → repo
        borg-plan-promote.sh    Symlink → repo
    skills/
        adhd-guardrails/        Symlink → repo
        borg-plan/              Symlink → repo
        borg-assimilate/        Symlink → repo
        borg-collective-review/ Symlink → repo
        borg-review/            Symlink → repo
        borg-link/              Symlink → repo
        borg-link-up/           Symlink → repo

~/.local/bin/
    borg                        Symlink → borg.zsh
    drone                       Symlink → drone.zsh
```

---

## Registry Schema

```json
{
  "projects": {
    "project-name": {
      "path": "/absolute/path/to/project",
      "source": "cli",
      "tmux_session": "borg",
      "tmux_window": "project-name",
      "claude_session_id": "uuid",
      "last_activity": "2026-03-30T14:30:00Z",
      "status": "active",
      "summary": "Short description from latest checkpoint or plan",
      "pinned": false,
      "waiting_reason": "Claude needs permission to use Bash",
      "goal": "Optional: project objective from /borg-plan",
      "done_when": "Optional: acceptance criteria from /borg-plan"
    }
  }
}
```

**Status values**: `active`, `waiting`, `idle`, `archived`, `unknown`

**Source values**: `cli` (Claude Code), `desktop` (Claude Desktop), `coco` (Cortex Code CLI)

---

## CLI Architecture

### borg.zsh

Follows `dev.sh` conventions: `set -e`, case-statement dispatch, `cmd_*` functions, colored output
via `info`/`warn`/`die`.

```
borg.zsh
  ├── PATH setup + hash -r (non-interactive zsh fix)
  ├── Source lib/*.zsh
  ├── Load config.zsh (boundaries, limits)
  ├── Helpers (_borg_relative_time, _borg_boundary_check, _borg_active_count,
  │           _borg_orchestrator_context)
  ├── Commands
  │   ├── cmd_init        Build briefing context → claude --append-system-prompt
  │   ├── cmd_claude      claude --continue from BORG_ORCHESTRATOR_ROOT (resume orchestrator)
  │   ├── cmd_next        Priority scoring → recommendation → switch
  │   ├── cmd_ls          Dashboard with sorting, markers, capacity warning
  │   ├── cmd_switch      fzf picker or direct switch
  │   ├── cmd_status      Detailed single-project view
  │   ├── cmd_hail        Full briefing (no arg) or project status (falls back to cmd_status)
  │   ├── cmd_scan        Auto-discover from session history
  │   ├── cmd_add/rm      Manual registration
  │   └── cmd_help        Command reference
  └── Dispatch (case statement)
```

### drone.zsh

Forked from `~/dev/dev.sh`. Same conventions. Manages:
- Docker Compose container lifecycle
- tmux window creation (side-by-side 2-pane layout by default)
- Container shell access
- Claude Code session launching inside containers

---

## Hook Architecture

Hooks are bash scripts that read JSON from stdin. They run inside the same environment as the Claude
Code session (which may be inside a container).

```bash
INPUT=$(cat /dev/stdin 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
```

**Design rules:**
- Always exit 0 (failures must not block Claude)
- Registry writes are atomic (tmp + mv)
- Graceful degradation (if registry is missing, skip)
- Fast path only — no LLM calls in hooks; the expensive work (authoring checkpoints) is user-driven

### Link-up / Link-down Semantics

The hook names reflect a collective metaphor: at session start, the drone **links down** from the
host — it pulls state (the latest checkpoint) into the session. At session end, the
drone **links up** — it flushes state back (status update, uncommitted-changes warning, checkpoint
nudge). The user-invoked `/borg-link-up` skill is the explicit flush: it writes the checkpoint that
the next session's `borg-link-down.sh` will read.

### Hook Registration

Hooks are registered in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/borg-link-down.sh"}]}],
    "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/borg-link-up.sh"}]}],
    "Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/borg-notify.sh"}]}],
    "PreToolUse": [
      {"matcher": "", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/borg-plan-promote.sh"}]},
      {"matcher": "", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/bash-guard.sh"}]}
    ]
  }
}
```

`borg-plan-promote.sh` fires on `Edit`, `Write`, and `NotebookEdit` tool calls. It scans the
session JSONL for an `ExitPlanMode` tool call since the most recent real user message. If found,
and no `PROJECT_PLAN.md` already exists in the repo, it writes the plan to
`docs/plans/PROJECT_PLAN.md` (creating the directory if needed) and emits a one-line note to
stderr. Always exits 0 — it never blocks the edit. Project-mode only; orchestrator sessions are
excluded via `_borg_session_mode`.

---

## Skills Architecture

Skills use progressive disclosure:
- **Startup**: Claude reads descriptions (~100 tokens each). Low overhead.
- **Activation**: Full instructions load (~2,000-5,000 tokens). Rich context.

### Borg Skills Philosophy

**Claude does the thinking, developer validates.** Skills don't ask open-ended questions. They read
the codebase, form proposals, and present them for confirmation. This minimizes cognitive load.

| Skill | Trigger | Role |
|-------|---------|------|
| adhd-guardrails | Auto (always) | Prevent scope creep, suggest breaks, shame-free language |
| borg-plan | Manual | Propose + lock project objectives and acceptance criteria |
| borg-assimilate | Manual | Shipping checklist + Collective review + execution |
| borg-collective-review | Manual / invoked | Adversarial multi-persona review (The Collective) |
| borg-review | Manual | Mid-session diagnostic, loop detection, one recommendation |
| borg-link | Manual | Consolidated project intelligence (overview or per-project deep dive) |
| borg-link-up | Manual | Flush session state to `<project>/.borg/checkpoints/<ts>.md` |
| borg-recon | Manual | Synthesize `borg recon --json` output into a by-project, urgency-ranked briefing |
| borg-next / borg-resume / borg-switch / borg-verify | Manual | Skill-form CLI wrappers |
| break-glass | Manual | Explicit, logged override for a normally-blocked action |
| simplify / fable-reviewer / no-unnecessary-read-perms | Manual / auto | Code + permission hygiene guardrails |

The full, current roster (16 skills as of this writing) is always `ls skills/` — this table lists
role, not an exhaustive spec.

---

## Usage Guardian (default OFF)

A two-part safety net that prevents runaway agent fan-out from silently burning a usage window,
without ever hard-blocking work by default:

1. **`bin/borg-usage-watch`** — a launchd-scheduled poller (`launchd/com.stillpoint-labs.borg.usage-watch.plist`)
   that samples `claude -p "/usage"` on an interval and appends one JSONL row per poll to
   `~/.local/state/borg/usage-samples.jsonl` (schema: `ts`, `status` — `ok` / `idle` / `suspect` /
   `error` — plus `session_pct`, `week_pct`, `resets_at` when known). Silence in the samples file has
   exactly one meaning: the poller did not run.
2. **85% checkpoint sweep** — at 85% session usage, the poller nudges in-flight sessions toward
   writing a checkpoint (`/borg-link-up`) before the window resets, so work is resumable rather than
   lost mid-stream.
3. **`hooks/borg-dispatch-guard.sh`** — a `PreToolUse` hook that hard-vetoes *new* Agent/Workflow
   dispatch once session usage reaches `BORG_USAGE_HALT_PCT` (default **92%**). It does not touch
   already-running work — only new fan-out. Disable with `BORG_USAGE_HALT_ENABLED=0`.

**Default posture: OFF and fail-OPEN.** Neither the poller nor the guard is installed/enabled by
default; when enabled, any failure to read a usage sample (binary not found, parse failure, stale
data) fails open — it never blocks dispatch on its own error. This is opt-in cost protection, not a
default constraint.

---

## Recon Fan-Out

The recon fan-out is a source-agnostic sweep primitive that answers "what happened everywhere since
I last looked?" across every registered project.

**`recon` is not a human-facing verb.** It retired 2026-08-26 (AC1 of the one-front-door plan):
`borg link` folds the same fan-out into its own document, so a human never needs to run the sweep
directly. Running bare `borg recon` dies with a pointer at `borg link`. What survives is the
**machine surface** — `borg recon --json` (consumed by the `/borg-recon` skill and
`merge-tree/gather.py`) and `borg recon --adapters` — because the engine was never the thing AC1
asked to remove. The gate lives in `borg_core/recon/cli.py::main()`, guarding the `_run()` call on
`args.json_only or args.adapters` — the module that implements the command owns the invariant.
`borg.zsh`'s `recon)` arm is a pure pass-through, plus the two things `argparse` does not do
(the `--list` alias for `--adapters`, and dying on an unknown flag). `python3 -m borg_core.recon.cli`
with no flags is gated identically to `borg recon` bare. `core.render_digest` is unreachable through
either front door — no argv combination reaches `_run()` with `json_only=False, adapters=False` — but
it is not dead code: it is the engine's own digest capability, still exercised directly by
`test_run_digest_output` and the core suite. See
`docs/plans/assimilated/2026-08-26-recon-retirement-gate-altitude.md` for the measurements behind
the move.

- **Engine**: `borg_core/recon/{core,shell,cli}.py`. It resolves a `since` mark (explicit override >
  newest checkpoint mtime > last-run marker > 24h fallback), then fans out concurrently (bounded
  parallelism) over pluggable **adapters**. (`borg link`'s fold does NOT reuse that ladder — it cuts
  a fixed 90-day window so one ref cannot answer two ways in two scopes, and it never writes the
  last-run marker.)
- **Adapter contract**: any executable named `recon-adapter-<source>` found on
  `BORG_RECON_ADAPTER_PATH` registers a new source — no code change required. The config directory
  shadows the repo directory. This repo ships exactly one reference adapter,
  `lib/recon/adapters/recon-adapter-github` (via `gh`); Slack/Jira/Notion adapters are a separate,
  machine-specific injected layer, never hardcoded here.
- **Normalization**: every finding becomes an Item —
  `{project, source, ref, title, state, changed, owner, action_needed, urgency, one_line}` — merged
  by project across all adapters.
- **Contradiction reconciliation**: recon cross-checks each project's latest checkpoint against
  fresh source state and flags checkpoint-blocker-vs-resolved-source contradictions (e.g. a
  checkpoint says "blocked on review" but the PR merged since).
- **Output**: `borg recon --json` emits the reconciled document; `/borg-recon` synthesizes it into
  a by-project, most-urgent-first, ELI10 briefing plus Yours(human)-vs-Mine(agent) action lists and
  a bounded read-only kickoff batch.

---

## Agent Roster and Nanoprobe Delegation

The orchestrator session never edits project files directly — it briefs, spawns, monitors, and
synthesizes. Actual work is delegated to ephemeral subagents via the Agent tool, routed by model
tier per `agents/ROUTING.md`:

| Agent | Model | Role |
|-------|-------|------|
| borg-grunt | Haiku | Fully-specified mechanical execution: apply an edit, run tests, rote refactor |
| borg-scout | Haiku | Read-only locate/search — never writes |
| borg-nanoprobe | Sonnet | Single discrete task requiring judgment — implement, fix, refactor |
| borg-researcher | Sonnet | From-zero web research on one track, structured findings |
| borg-reviewer | Sonnet (high effort) | Blind adversarial review, arrives cold with no author context |

Nanoprobes (and any subagent doing multi-file work) manage their own git worktrees rather than
relying on harness-level isolation: `git -C <repo_path> worktree add
/Users/noah/.local/state/borg/worktrees/<repo>/<slug> -b <branch>`. All edits and commits happen
inside that worktree; on completion the subagent removes it. `borg reap-worktrees`
(`launchd/com.stillpoint-labs.borg.reap.plist`, hourly) is the safety net that auto-cleans any borg
worktree whose branch has merged or that has gone stale (`BORG_REAP_STALE_HOURS`, default 12h).
Nanoprobe lifecycle is logged by `hooks/borg-nanoprobe-log.sh` (`SubagentStop`) to
`~/.config/borg/agents.jsonl`; inspect with `borg nanoprobes` (alias `np`) and pull transcripts with
`borg nanoprobe-log <id-prefix>`.

---

## Cairn Integration (Decommissioned)

Borg previously integrated with cairn, a separate PostgreSQL+pgvector knowledge graph service, for
cross-project search, briefing enrichment, and cross-session presence tracking. Cairn was
decommissioned 2026-08-08 (its differentiating cross-project recall measured indistinguishable from
a null baseline), and every integration point — `borg search`, cairn-enriched briefings, and
presence publish/close — was removed along with it. The corpus was exported to per-project
`.borg/knowledge/*.md` markdown, which is grep-reachable directly and requires no service.
Knowledge persistence today is purely file-based: checkpoints in `<project>/.borg/checkpoints/`,
loaded on session start.

---

## Devcontainer Integration

Claude Code runs inside Docker Compose containers with `~/.claude/` bind-mounted from the host.
This propagates hooks, skills, and settings automatically.

Borg requires one additional mount for registry access:

```yaml
volumes:
  - ~/.claude:/home/vscode/.claude:cached
  - ~/.config/borg:/home/vscode/.config/borg:cached
```

### Path Resolution

Inside containers, CWD is typically `/workspaces/<project>`, not the host path. Hooks use
`basename($CWD)` to identify the project, which works when docker-compose project names match
directory names.

---

## Dependencies

| Tool | Required | Purpose |
|------|----------|---------|
| jq | Yes | Registry JSON CRUD |
| fzf | Yes | Fuzzy picker for `borg switch` |
| tmux | Yes | Session multiplexing |
| claude | Optional | Orchestrator session, `borg link --brief` narrative briefing |
| Docker | Optional | Devcontainer support |
