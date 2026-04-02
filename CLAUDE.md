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
- Core borg CLI: init, claude, next, ls, switch, status, brief, search, scan, add, rm, help
- CoCo (Cortex Code CLI) integration: session discovery, `[X]` badge in `borg ls`, cairn records
- `drone` CLI: up, down, claude, sh, restart, fix, status
- Hooks: borg-start.sh (status=active + debrief/cairn context injection),
  borg-stop.sh (status=idle + async Sonnet debrief + cairn commit), borg-notify.sh
- Skills: adhd-guardrails, checkpoint-enhanced, borg-plan, borg-review, borg-assimilate, borg-debrief
- Work/life boundary checks on switch
- Capacity warnings
- tmux hotkey (Ctrl+Space >)
- Registry-based project tracking with atomic writes
- LLM-powered session debriefs (claude-sonnet-4-6, async, ~$0.10/session)
- Session context loaded at start from debrief + cairn (if available)
- `borg init` orchestrator: morning briefing from registry + debriefs + cairn
- Cairn integration: session commits on stop, knowledge search on start and via `borg search`

### Commands

```
borg init                Launch orchestrator: morning briefing + Claude session
borg / borg next         What needs attention? Switch to it.
borg claude              Launch/resume orchestrator Claude session
borg ls [--all]          Dashboard sorted by urgency
borg switch [query]      fzf picker → tmux window switch
borg status [project]    Detailed project status
borg brief [project]     Project briefing from cairn
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
    borg-start.sh           SessionStart → status=active
    borg-stop.sh            Stop → status=idle + debrief
    borg-notify.sh          Notification → status=waiting + waiting_reason
skills/
    adhd-guardrails/        Cognitive load guardrails (always active)
    borg-plan/              Project planning Q/A (Claude proposes, you validate)
    borg-assimilate/        Shipping checklist + execution (merge PR, archive plan)
    borg-review/            Mid-session diagnostic + loop detection
    borg-debrief/           Structured session analysis
    checkpoint-enhanced/    Manual session checkpoint
install.sh                  Installer: deps, symlinks, hooks, skills, tmux keybinding
docs/
    boris-workflow.md       ELI5 guide to the workflow (start here)
    ...
```

## Key Patterns

- **CLI structure mirrors dev.sh**: `set -e`, case dispatch, colored output, `cmd_*` naming
- **Registry writes are atomic**: write to tmp file, `mv` to final path
- **Skills do the thinking**: Claude proposes, developer validates. Minimum cognitive load.
- **Debriefs replace summaries**: LLM analysis at session stop, not regex extraction
- **Boundaries are speed bumps**: one-keystroke confirmations, not hard blocks
- **Cairn is optional**: borg works without it (registry + file debriefs), cairn adds persistence

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
