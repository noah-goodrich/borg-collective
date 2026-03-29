# Architecture Guide

This document describes how every component of The Borg Collective fits together. No prior context is assumed.

---

## System Overview

The Borg Collective is a thin coordination layer that sits between three categories of tools:

1. **AI Coding Agents** — Claude Code CLI and Cortex Code CLI (CoCo). These run inside tmux windows, often inside Docker Compose devcontainers. Each session has its own context, JSONL transcript, and lifecycle events.

2. **Session Intelligence Tools** — `claude-code-monitor` (real-time status detection, Ghostty focus switching) and `@tradchenko/claude-sessions` (AI-powered session summaries, TUI picker). These understand sessions but not projects, tmux windows, or each other.

3. **The Developer's Terminal** — tmux with a session named `dev`, one window per project. The developer switches between windows to move between projects.

Borg adds what none of these provide: a unified project registry that maps sessions to tmux windows, tracks status across session boundaries, enforces work/life time constraints, manages cognitive load, and answers "what should I do next?"

```
                        borg CLI (host)
                     borg ls | switch | next
                            |
              +-------------+-------------+
              |             |             |
         registry.json  tmux "dev"   ~/.claude/
         (project state) (windows)   (sessions)
              |             |             |
              +------+------+      +------+------+
                     |             |             |
               config.zsh    claude-code     claude-code
              (boundaries)   (container A)   (container B)
                             via hooks ->    via hooks ->
                             update          update
                             registry        registry
```

---

## Data Flow

### Session Lifecycle

When a Claude Code session starts, runs, and ends, borg tracks the lifecycle through three hooks:

```
Session Start
    -> hooks/borg-start.sh fires (SessionStart event)
    -> Reads JSON from stdin: {session_id, cwd}
    -> Extracts project name from basename(cwd)
    -> Updates registry: status=active, last_activity=now, claude_session_id

Claude Processes (no hook)
    -> Status remains "active"

Claude Finishes Turn, Needs Input
    -> hooks/borg-notify.sh fires (Notification event)
    -> Reads JSON from stdin: {session_id, cwd}
    -> Updates registry: status=waiting, last_activity=now

Session Ends
    -> hooks/borg-stop.sh fires (Stop event)
    -> Reads JSON from stdin: {session_id, cwd, transcript_path}
    -> Runs: python3 summarize.py <transcript_path>
    -> Updates registry: status=idle, summary=<output>, last_activity=now
```

### Registry Updates

All registry writes are atomic: the hook writes to a temporary file (`$$.tmp`) and then `mv`s it to the final path. This prevents partial writes from corrupting the registry. Multiple hooks can fire simultaneously (e.g., from different containers) without data loss, though the last writer wins on concurrent updates to the same project.

```
Hook Process:
    jq '.projects[$project] += $updates' registry.json > /tmp/borg.$$.tmp
    mv /tmp/borg.$$.tmp registry.json
```

### Summary Extraction

`summarize.py` reads the last 200 lines of a JSONL transcript and extracts three pieces of information without making any LLM calls:

1. **Goal** — The first user message in the conversation (truncated to 300 characters)
2. **Modified files** — File paths from `Edit` and `Write` tool_use blocks (up to 4 shown, then "and N more")
3. **Last request** — The most recent user message

Output format: `Goal: <goal> | Modified: <files> | Last request: <request>`

This runs in under one second on any transcript, making it suitable for Stop hooks.

---

## File System Layout

### Repository (checked into git)

```
~/dev/borg-collective/
    borg.zsh                    Main CLI entry point (~400 lines)
    lib/
        registry.zsh            Registry CRUD for ~/.config/borg/registry.json
        tmux.zsh                tmux window listing + switching (SESSION="dev")
        claude.zsh              Session discovery from ~/.claude/projects/ JSONL
        desktop.zsh             Claude Desktop session reader
    summarize.py                JSONL transcript -> summary (pure extraction)
    hooks/
        borg-start.sh           SessionStart hook -> status=active
        borg-stop.sh            Stop hook -> status=idle, extract summary
        borg-notify.sh          Notification hook -> status=waiting
    desktop/
        borg-project-instructions.md   Claude Desktop integration instructions
    install.sh                  Installer: deps, symlinks, hooks, skills
    docs/
        six-pager.md            Formal narrative document
        quickstart.md           Getting started guide
        cheatsheet.md           Single-page reference
        architecture.md         This file
        research.md             ADHD research citations
        skills-guide.md         Skills installation and usage
        devcontainer-coco.md    Devcontainer + CoCo compatibility
    README.md                   Open source documentation
    CLAUDE.md                   Internal handoff (for Claude Code sessions)
```

### Runtime State (not in git)

```
~/.config/borg/
    registry.json               Central project registry
    config.zsh                  Boundary configuration (work hours, limits)
    desktop/                    Desktop session reports (JSON, from MCP)

~/.claude/
    hooks/
        borg-start.sh           Symlink -> ~/dev/borg-collective/hooks/
        borg-stop.sh            Symlink -> ~/dev/borg-collective/hooks/
        borg-notify.sh          Symlink -> ~/dev/borg-collective/hooks/
    skills/
        adhd-guardrails/
            SKILL.md            Compassionate constraints skill
        checkpoint-enhanced/
            SKILL.md            Session checkpoint with entry point
    settings.json               Hook registration (Stop, Notification, SessionStart)
    session-log.md              Session history (read by borg scan)
    projects/
        -Users-noah-dev-cairn/  Per-project JSONL transcripts
        -Users-noah-dev-borg-collective/
        ...
```

### Symlink Structure

The installer creates symlinks so updates to the git repo are immediately live:

```
~/.local/bin/borg           -> ~/dev/borg-collective/borg.zsh
~/.claude/hooks/borg-start.sh  -> ~/dev/borg-collective/hooks/borg-start.sh
~/.claude/hooks/borg-stop.sh   -> ~/dev/borg-collective/hooks/borg-stop.sh
~/.claude/hooks/borg-notify.sh -> ~/dev/borg-collective/hooks/borg-notify.sh
```

---

## Registry Schema

The registry is a single JSON file at `~/.config/borg/registry.json`:

```json
{
  "projects": {
    "<project-name>": {
      "path": "/absolute/path/to/project",
      "source": "cli | coco | desktop",
      "tmux_session": "dev",
      "tmux_window": "<window-name>",
      "claude_session_id": "<uuid>",
      "last_activity": "<ISO-8601>",
      "status": "active | waiting | idle | archived | unknown",
      "summary": "<2-3 sentence extractive summary>",
      "pinned": false,
      "goal": "<optional: project objective>",
      "done_when": "<optional: acceptance criteria>"
    }
  }
}
```

**Field semantics:**

| Field | Type | Set By | Purpose |
|-------|------|--------|---------|
| `path` | string | `borg scan`, `borg add` | Absolute path on host filesystem |
| `source` | string | `borg scan`, hooks | Origin: `"cli"` (Claude Code), `"coco"` (Cortex Code), `"desktop"` (Claude Desktop) |
| `tmux_session` | string | `borg add`, auto-detect | tmux session name (default: `"dev"`) |
| `tmux_window` | string | `borg add`, auto-detect | tmux window name for switching |
| `claude_session_id` | string | hooks | Most recent Claude Code session UUID |
| `last_activity` | string | hooks | ISO 8601 timestamp of last status change |
| `status` | string | hooks, `borg tidy` | Current lifecycle state |
| `summary` | string | hooks (`summarize.py`), `borg refresh` | Extractive summary from transcript |
| `pinned` | boolean | `borg pin`/`unpin` | Priority flag for sorting and recommendations |
| `goal` | string | manual | Project objective (optional) |
| `done_when` | string | manual | Acceptance criteria (optional) |

---

## CLI Architecture

`borg.zsh` follows the `dev.sh` pattern exactly:

1. `set -e` for fail-fast behavior
2. Resolve `BORG_ROOT` from the script's own path
3. Source `lib/*.zsh` files for modular functionality
4. Source `~/.config/borg/config.zsh` for boundary settings
5. Define helper functions: `info()`, `warn()`, `die()`, `dbg()`
6. Define ANSI color codes: `GREEN`, `YELLOW`, `RED`, `CYAN`, `BOLD`, `DIM`
7. Case-statement dispatch on `$1` to `cmd_*` functions

Each command is a function:

| Function | Command | Purpose |
|----------|---------|---------|
| `cmd_ls` | `borg ls` | List projects with status, boundaries, staleness |
| `cmd_switch` | `borg switch` | fzf picker or direct tmux switch |
| `cmd_next` | `borg next` | Single recommendation |
| `cmd_status` | `borg status` | Detailed project view |
| `cmd_scan` | `borg scan` | Discover from session-log.md |
| `cmd_add` | `borg add` | Manual registration |
| `cmd_rm` | `borg rm` | Unregistration |
| `cmd_refresh` | `borg refresh` | Regenerate summaries |
| `cmd_pin` | `borg pin` | Set priority flag |
| `cmd_unpin` | `borg unpin` | Clear priority flag |
| `cmd_tidy` | `borg tidy` | Interactive stale cleanup |
| `cmd_help` | `borg help` | Usage information |

---

## Hook Architecture

Hooks are bash scripts (not zsh) that read JSON from stdin, extract fields with `jq`, and update the registry. They follow the pattern established by `~/.config/dotfiles/claude/code/hooks/session-log.sh`.

**Registration** in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/borg-start.sh" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/borg-stop.sh" }] }
    ],
    "Notification": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/borg-notify.sh" }] }
    ]
  }
}
```

**Execution context:** Hooks fire in the environment where Claude Code is running. If Claude is inside a devcontainer, hooks fire inside that container. The registry path (`~/.config/borg/registry.json`) must be accessible from inside the container for updates to persist.

**Exit codes:** All hooks exit 0 regardless of success. A failing hook should not block Claude Code operation.

---

## Skills Architecture

Skills are the portable unit of discipline. They work identically in Claude Code and Cortex Code CLI.

### Skill Loading

1. At session start, Claude reads skill descriptions (~100 tokens each)
2. Claude decides whether each skill is relevant to the current task
3. When invoked (automatically or via `/skill-name`), full instructions are loaded (~5k tokens)
4. Skills can restrict their own tool access, run in isolated subagents, and include supporting files

### Skill File Format

```
~/.claude/skills/<skill-name>/
    SKILL.md            Main instructions (YAML frontmatter + markdown body)
    REFERENCE.md        Detailed docs (loaded on demand, optional)
    scripts/            Executable scripts (optional)
```

### Installed Skills

| Skill | Source | Auto-invoke | Purpose |
|-------|--------|-------------|---------|
| `adhd-guardrails` | Custom | Yes (always loaded) | Compassionate constraints, scope flagging, break suggestions |
| `checkpoint-enhanced` | Custom | No (invoke with `/checkpoint-enhanced`) | Session summary with next-session entry point |
| Boris's 57 tips | `alirezarezvani/claude-skills` | Contextual | Complete Claude Code framework |
| Engineering skills | `alirezarezvani/claude-skills` | Contextual | Architecture, QA, DevOps patterns |
| Scope Guard | `alirezarezvani/claude-skills` | Contextual | Scope creep prevention |

### Portability

Skills installed in `~/.claude/skills/` propagate to:
- All Claude Code sessions on the host
- All Claude Code sessions in devcontainers (via `~/.claude` bind mount)
- Cortex Code CLI (reads the same SKILL.md format from `~/.snowflake/cortex/skills/` or symlinked)

---

## Devcontainer Integration

Noah runs Claude Code inside Docker Compose devcontainers. The integration works through bind mounts:

```
Host                          Container
~/.claude/          ->        /home/vscode/.claude/
    hooks/                        hooks/              (borg hooks fire here)
    skills/                       skills/             (skills available here)
    settings.json                 settings.json       (hook registration)
    session-log.md                session-log.md      (shared session history)
    projects/                     projects/           (shared transcripts)

~/.config/borg/     ->        /home/vscode/.config/borg/
    registry.json                 registry.json       (hooks write here)
    config.zsh                    config.zsh          (boundaries)
```

**Important:** The `~/.config/borg/` mount must be added manually to each project's `docker-compose.yml`. Without it, hooks fire inside the container but their registry updates are lost when the container stops.

**Path resolution:** Inside a container, `$CWD` may be `/workspace` or `/development` instead of `/Users/noah/dev/cairn`. The hooks use `basename($CWD)` to derive the project name, which resolves correctly in both contexts (e.g., `cairn` in both cases).

---

## Cortex Code CLI (CoCo) Compatibility

CoCo is a separate Snowflake-native product. It uses Podman (not Docker) for sandboxing and stores its config in `~/.snowflake/cortex/` (not `~/.claude/`). However, skills are 100% portable between the two tools.

Borg's architecture is forward-compatible with CoCo:

- The registry `source` field is a free-form string, not an enum. Adding `"coco"` requires no schema change.
- Session discovery in `lib/claude.zsh` uses variables for directory paths, not hardcoded strings. A future `lib/coco.zsh` follows the identical pattern.
- Hooks follow the same event-driven architecture in both tools. A future `hooks/borg-stop-coco.sh` adapts the Stop hook for CoCo's stdin format.

Docker (for devcontainers) and Podman (for CoCo) coexist on macOS without conflict. They use different socket and connection mechanisms.

See `docs/devcontainer-coco.md` for complete compatibility details.

---

## Dependencies

| Dependency | Role | Required By |
|------------|------|-------------|
| zsh | Shell (CLI implementation) | borg.zsh, lib/*.zsh |
| jq | JSON manipulation | Registry CRUD, hooks |
| fzf | Fuzzy picker | `borg switch` |
| python3 | Script runtime | summarize.py |
| tmux | Terminal multiplexer | `borg switch`, window detection |
| node >= 18 | npm package runtime | ccm, cs |
| claude-code-monitor (`ccm`) | Status detection, Ghostty focus | Optional: `borg focus` delegation |
| @tradchenko/claude-sessions (`cs`) | AI session summaries, TUI picker | Optional: standalone session picker |
| brew | Package manager | install.sh (for missing deps) |

---

## Security Considerations

- The registry contains project paths and session UUIDs. It does not contain credentials, API keys, or conversation content.
- Hooks read transcript paths from Claude Code's stdin but do not store transcript content in the registry. Only the extractive summary (2-3 sentences) is stored.
- The `~/.config/borg/` directory should have standard user permissions (0700 for directory, 0600 for files).
- When bind-mounted into containers, the registry is writable by the container user. Ensure container users are trusted.
