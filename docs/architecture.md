# Architecture Guide

How every component of Borg fits together.

---

## System Overview

Borg is an AI development orchestration framework with three layers:

1. **`borg` (orchestration)** — Runs on the host. Manages a JSON registry of projects, scores
   priorities, enforces work/life boundaries, launches an orchestrator Claude session for morning
   briefings, and provides the `borg next` / `Ctrl+Space >` hotkey for instant context switching.

2. **`drone` (project lifecycle)** — Runs on the host. Manages Docker Compose containers, tmux
   windows, and pane layouts. Launches Claude Code sessions inside project containers. Forked
   from `dev.sh`.

3. **cairn (knowledge persistence, optional)** — Runs in a container with PostgreSQL + pgvector.
   Stores decisions, patterns, and observations with vector embeddings. Enables `borg search` for
   cross-project knowledge retrieval. Borg works without it — user-authored session checkpoints
   are stored per-project as files.

### Data Flow

```
Session lifecycle:

  drone up project          → Container starts, tmux window created
  drone claude project      → Claude Code session begins
  borg-link-down.sh fires   → Registry: status=active
                            → Injects additionalContext: latest checkpoint + cairn knowledge
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
                               4. If cairn reachable: optional session record
```

### Registry Writes

All registry updates are atomic: write to `registry.json.tmp.$$`, then `mv` to `registry.json`.
This prevents corruption from concurrent hook executions.

---

## File System Layout

### Repository

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
    hooks/
        borg-link-down.sh       SessionStart → status=active + latest-checkpoint injection
        borg-link-up.sh         Stop → status=idle + uncommitted warning + checkpoint nudge
        borg-notify.sh          Notification → status=waiting + reason
    skills/
        adhd-guardrails/        Cognitive load guardrails (always active)
        borg-plan/              Project planning + Collective review
        borg-assimilate/        Shipping checklist + Collective review + execution
        borg-collective-review/ Adversarial multi-persona review (The Collective)
        borg-review/            Mid-session diagnostic + loop detection
        borg-link/              Consolidated project intelligence (overview + deep dive)
        borg-link-up/           Flush session state to a per-project checkpoint file
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
  │   ├── cmd_claude      claude --continue from BORG_ROOT (resume orchestrator)
  │   ├── cmd_next        Priority scoring → recommendation → switch
  │   ├── cmd_ls          Dashboard with sorting, markers, capacity warning
  │   ├── cmd_switch      fzf picker or direct switch
  │   ├── cmd_status      Detailed single-project view
  │   ├── cmd_hail        cairn search for project (falls back to cmd_status)
  │   ├── cmd_search      cairn search with optional --project filter
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
- Graceful degradation (if cairn is unreachable, skip; if registry is missing, skip)
- Fast path only — no LLM calls in hooks; the expensive work (authoring checkpoints) is user-driven

### Link-up / Link-down Semantics

The hook names reflect a collective metaphor: at session start, the drone **links down** from the
host — it pulls state (the latest checkpoint, cairn context) into the session. At session end, the
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
    "Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/borg-notify.sh"}]}]
  }
}
```

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

---

## Cairn Integration (Optional)

Cairn is a separate project — a knowledge graph backed by PostgreSQL + pgvector. Borg integrates
with it when available:

| Borg Action | Cairn Integration |
|-------------|-------------------|
| `borg-link-up.sh` | Optionally commits session record if cairn is reachable |
| `borg-link-down.sh` | Fetches cairn briefing for project context |
| `borg search` | Wraps `cairn search` for cross-project knowledge |
| `borg init` | Includes cairn knowledge in orchestrator briefing |

When cairn is unavailable, borg degrades gracefully: checkpoints live in each project's
`.borg/checkpoints/` directory and are loaded on session start. `borg search` is unavailable.

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
| cairn | Optional | Knowledge persistence |
| Docker | Optional | Devcontainer support |
