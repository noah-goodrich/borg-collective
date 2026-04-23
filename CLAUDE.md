# The Borg Collective — Project Handoff

## What This Is

AI development orchestration framework. Two CLIs — `borg` (orchestration) and `drone` (project
lifecycle) — that coordinate parallel Claude Code sessions across projects and containers. Uses cairn
(PostgreSQL + pgvector knowledge graph) as an optional persistence layer for cross-session knowledge.

## Architecture

```
borg (orchestrator)     drone (project lifecycle)     cairn (knowledge, optional)
  - Morning briefing      - Container up/down           - Decisions + reasoning
  - Priority scoring      - tmux window management      - Patterns + gotchas
  - Work/life boundaries  - Claude session launching    - Session debriefs
  - Knowledge search      - 3-pane dev layout           - Vector search
```

Three independent tools that compose:
- **borg** — Session coordination, recommendations, boundaries. Runs on host.
- **drone** — Container lifecycle, tmux windows, pane layouts. Forked from dev.sh. Runs on host.
- **cairn** — Knowledge graph. Runs in a container with PostgreSQL. Optional.

## Current State (v2)

### Implemented
- Core borg CLI: init, claude, next, ls, switch, status, hail, search, scan, add, rm, help
- CoCo (Cortex Code CLI) integration: session discovery, `[X]` badge in `borg ls`, cairn records
- `drone` CLI: up, down, claude, sh, restart, fix, status
- Hooks: borg-link-down.sh (status=active + latest-checkpoint injection + cairn context),
  borg-link-up.sh (status=idle + uncommitted-changes tracking + no-checkpoint nudge), borg-notify.sh
- Skills: adhd-guardrails, borg-link-up, borg-plan, borg-review, borg-assimilate
- Work/life boundary checks on switch
- Capacity warnings
- tmux hotkey (Ctrl+Space >)
- Registry-based project tracking with atomic writes
- User-authored session checkpoints at <project>/.borg/checkpoints/<ts>.md (via /borg-link-up)
- Session context loaded at start from latest checkpoint + cairn (if available)
- `borg init` orchestrator: morning briefing from registry + checkpoints + cairn
- Cairn integration: optional knowledge-graph persistence; knowledge search via `borg search`

### Commands

```
borg init                Launch orchestrator: morning briefing + Claude session
borg / borg next         What needs attention? Switch to it.
borg claude              Launch/resume orchestrator Claude session
borg link [project]      Overview (no arg) or deep dive (with project)
                           --brief   LLM narrative briefing
                           --refresh Regenerate summaries
                           --all     Include archived projects
borg switch [query]      fzf picker → tmux window switch
borg search "query"      Search cairn knowledge graph
borg scan                Auto-discover from session history
borg add [path]          Register a project
borg rm <project>        Unregister
borg help                Full command reference

drone up [project]       Start container + tmux window
drone down [project]     Stop container + remove window
drone claude [project]   Launch Claude in project context
drone sh [project]       Shell into container
drone restart [project]  Restart container
drone link               Deep dive on current project (alias for borg link)
drone status             Show all drones
```

### Hotkey

`Ctrl+Space >` — jump to most pressing project (runs `borg next --switch`)

### Files

```
borg.zsh                    Main CLI (~770 lines)
drone.zsh                   Project lifecycle (forked from dev.sh + drone claude)
lib/
    registry.zsh            Registry CRUD for ~/.config/borg/registry.json
    tmux.zsh                tmux window listing + switching
    claude.zsh              Session discovery from ~/.claude/projects/
    coco.zsh                Session discovery from ~/.snowflake/cortex/projects/
    desktop.zsh             Claude Desktop session reader
hooks/
    borg-link-down.sh       SessionStart → status=active + latest-checkpoint injection
    borg-link-up.sh         Stop → status=idle + uncommitted warning + checkpoint nudge
    borg-notify.sh          Notification → status=waiting + waiting_reason
skills/
    adhd-guardrails/        Cognitive load guardrails (always active)
    borg-plan/              Project planning + Collective review
    borg-assimilate/        Shipping checklist + Collective review + execution
    borg-collective-review/ Adversarial multi-persona review (The Collective)
    borg-review/            Mid-session diagnostic + loop detection
    borg-link/              Consolidated project intelligence (overview + deep dive)
    borg-link-up/           Flush session state to <project>/.borg/checkpoints/<ts>.md
install.sh                  Installer: deps, symlinks, hooks, skills, tmux keybinding
docs/
    boris-workflow.md       ELI5 guide to the workflow (start here)
    plans/assimilated/      Shipped plans for borg-collective itself (per-project convention)
    plans/directives/       Backlog for borg-collective itself; every project owns its own
    ...
```

## Key Patterns

- **CLI structure mirrors dev.sh**: `set -e`, case dispatch, colored output, `cmd_*` naming
- **Registry writes are atomic**: write to tmp file, `mv` to final path
- **Skills do the thinking**: Claude proposes, developer validates. Minimum cognitive load.
- **Debriefs replace summaries**: LLM analysis at session stop, not regex extraction
- **Boundaries are speed bumps**: one-keystroke confirmations, not hard blocks
- **Cairn is optional**: borg works without it (registry + file debriefs), cairn adds persistence
- **borg-hooks (host-side lifecycle)**: projects can ship executable `.devcontainer/borg-hooks/pre-up.sh`
  and `.devcontainer/borg-hooks/post-down.sh` scripts. `pre-up.sh` runs on the host before
  `docker compose up -d` (strict: non-zero aborts `drone up`); `post-down.sh` runs after
  `docker compose down` in `drone down` only (lenient: non-zero warns, drone exits 0). Hooks
  run with `cwd=$project_dir` and `BORG_PROJECT_NAME` exported. Transient downs during
  `drone restart`/`rebuild` do NOT fire `post-down.sh` — external stacks (e.g. Supabase)
  must persist across cycles. New Supabase projects scaffold via `drone scaffold --supabase <dir>`.
- **`drone scaffold --supabase <dir>`**: generate a devcontainer joined to the external
  `supabase_network_<project>` network plus standard borg-hooks that call `supabase start`
  on up and `supabase stop` on down.

## External Dependencies

| Tool | Command | Purpose |
|------|---------|---------|
| jq | `jq` | Registry JSON CRUD |
| fzf | `fzf` | Fuzzy picker for `borg switch` |
| claude | `claude` | LLM debriefs (Sonnet), orchestrator session |
| cortex | `cortex` | Cortex Code CLI (CoCo) — optional, detected at install |
| cairn | `cairn` | Knowledge persistence (optional) |

## Style Rules

- All markdown and text files must wrap at 120 characters. No line may exceed 120 chars.
- 4-space indentation (except YAML/Lua: 2-space)
- zsh functions over aliases for anything > 1 line
- No `$()` substitution in Bash tool calls
- No inline `#` comments in one-liner bash commands
- No temp scripts

## Learned

- **tmux zoom is a toggle**: `resize-pane -Z` toggles zoom on/off. If a helper zooms a pane and
  the caller also zooms it, the second call unzooms. Apply zoom in exactly one place — the final
  caller, not intermediate helpers.
- **Notifications must not steal focus**: macOS notifications should only activate the target app
  on click (`-activate`), never on fire. Unsolicited focus changes interrupt whatever the user is
  doing.
- **devcontainer postStartCommand vs postCreateCommand**: `drone` only runs `postStartCommand`.
  Symlinks and per-start setup (zshrc, CLAUDE.md, .claude.json) must live in `postStartCommand`.
  `postCreateCommand` is for one-time setup (pip install, chmod) and is never run by `drone`.
- **`claude plugin install` takes a marketplace name, not a file path**: the correct syntax is
  `claude plugin install <name>@<marketplace>`, not `claude plugin install <file>.plugin`. The
  local marketplace (`noah-local`) resolves from the plugins source directory, not `dist/`.
- **`borg.zsh` sources only `lib/*.zsh`, not `lib/*.sh`**: helpers intended for both the CLI and
  bash hook scripts must be defined in two places — `lib/borg-hooks.sh` (bash, sourced by hooks)
  and `lib/<name>.zsh` (zsh, picked up by the CLI glob). Check the source path before writing a
  shared helper.
- **Don't track copy success via mtime deltas**: if a helper function copies a file and you need
  to know whether it acted, return a status code or accept a callback — don't read before/after
  mtime from outside the helper. That's leaky and adds syscalls. Simplest: just log
  unconditionally or restructure so the caller does the condition check itself.
