# The Borg Collective — Handoff

## What This Is

CLI tool (`borg`) for managing multiple Claude Code + Claude Desktop sessions across projects. Compose-first approach: uses `claude-code-monitor` and `@tradchenko/claude-sessions` as dependencies, with a zsh glue layer that adds project registry, tmux window switching, fzf picker, and auto-tracking hooks.

## Full Plan

`~/.claude/plans/peaceful-purring-catmull.md` — complete architecture, research, and phased delivery.

## Current State

**All files are written.** Nothing works yet — needs debugging before first successful run.

### Files

```
borg.zsh                    # Main CLI entry point (~400 lines)
lib/
    registry.zsh            # Registry CRUD for ~/.config/borg/registry.json
    tmux.zsh                # tmux window listing + switching (SESSION="dev")
    claude.zsh              # Session discovery from ~/.claude/projects/ JSONL
    desktop.zsh             # Claude Desktop session reader from ~/.config/borg/desktop/
summarize.py                # JSONL transcript → 2-3 sentence summary (pure extraction, no LLM)
hooks/
    borg-stop.sh            # Claude Code Stop hook → update registry + generate summary
    borg-notify.sh          # Claude Code Notification hook → update registry + macOS alert
desktop/
    borg-project-instructions.md  # Instructions for Claude Desktop Project integration
install.sh                  # Installer: deps, symlinks, hook registration, bootstrap
README.md                   # Open source documentation
```

### Already Done

- [x] Git repo initialized at ~/dev/borg-collective/
- [x] npm deps installed globally: `claude-code-monitor` (`ccm`), `@tradchenko/claude-sessions` (`cs`)
- [x] `fzf` installed via brew
- [x] All source files written
- [x] Scripts chmod +x
- [x] Hooks symlinked to ~/.claude/hooks/
- [x] `borg` symlinked to ~/.local/bin/borg
- [x] Hook entries added to ~/.config/dotfiles/claude/code/settings.json (Stop + Notification events)

### Known Bugs — Must Fix Before First Run

1. **`borg scan` fails: `command not found: awk` / `sort`**
   - In `lib/claude.zsh`, `borg_claude_scan_session_log()` calls `awk` and `sort`
   - Works fine when sourced interactively (`source lib/claude.zsh && borg_claude_scan_session_log`) but fails when run as `zsh borg.zsh scan`
   - Likely a PATH issue in non-interactive zsh. Fix: use `/usr/bin/awk` and `/usr/bin/sort`, or rewrite using zsh builtins
   - This was confirmed via `zsh -x borg.zsh scan` trace — BORG_ROOT resolves correctly, libs source correctly, the function is called, but `awk`/`sort` aren't found in PATH

2. **`cmd_ls` and `cmd_refresh` not yet verified** — they were rewritten from pipe-to-while to process substitution (`< <(...)`) to avoid subshell issues, but haven't been tested

3. **`cmd_switch` fzf preview** — the preview command sources lib files inline which is fragile. May need a helper script or simpler preview

### Not Yet Done

- [ ] Fix the PATH/command-not-found bugs and get `borg scan` + `borg ls` working
- [ ] Run `borg scan` to bootstrap registry from ~/.claude/session-log.md
- [ ] Run `borg refresh --all` to generate initial summaries
- [ ] Test `borg switch` with fzf
- [ ] Test hooks fire correctly on session stop/notification
- [ ] Test `borg status <project>`
- [ ] Initial git commit
- [ ] Test Desktop integration end-to-end

## Key Patterns to Follow

- **CLI structure mirrors `~/.config/dotfiles/dev.sh`**: `set -e`, case-statement dispatch, colored output (`info`, `warn`, `die`, `dbg`), `get_*`/`cmd_*`/`ensure_*` naming
- **Hook pattern mirrors `~/.config/dotfiles/claude/code/hooks/session-log.sh`**: reads JSON from stdin, extracts fields with jq, exits 0
- **Summarizer pattern mirrors `~/.config/dotfiles/claude/code/hooks/pre-compact.py`**: parse JSONL, extract user/assistant messages + tool_use for file tracking
- **Registry writes are atomic**: write to tmp file, `mv` to final path

## Session Log Format

`~/.claude/session-log.md` lines look like:
```
- 2026-03-17 08:25 | /Users/noah/dev | session:c4496abf-110c-4b70-886a-e88d0467304e
```

## Claude Project Directory Encoding

`/Users/noah/dev/cairn` → `-Users-noah-dev-cairn` in `~/.claude/projects/`

Confirmed directories:
```
-Users-noah--config-dotfiles
-Users-noah-dev
-Users-noah-dev-cairn
-Users-noah-dev-wallpaper-kit
-Users-noah-dev-wayfinderai-waypoint
```

## External Dependencies

| Tool | Command | Purpose |
|------|---------|---------|
| claude-code-monitor | `ccm` | Status detection + Ghostty focus switching |
| claude-sessions | `cs` | AI-powered session summaries + TUI picker |
| jq | `jq` | Registry JSON CRUD |
| fzf | `fzf` | Fuzzy picker for `borg switch` |
| python3 | `python3` | `summarize.py` transcript extraction |

## Settings.json Hook Registration

Already added to `~/.config/dotfiles/claude/code/settings.json`:
- Stop event: `$HOME/.claude/hooks/borg-stop.sh` (timeout 30, runs alongside session-log.sh and notify.sh)
- Notification event: `$HOME/.claude/hooks/borg-notify.sh` (timeout 5)

## Noah's Preferences

- 4-space indentation, zsh functions over aliases for >1 line
- "Simple" = fewest moving parts
- CLI-first, show commands to run
- No project-level permission prompts — all permissions in global settings.json
- No `$()` substitution or inline `#` comments in Bash tool calls
- No temp scripts — inline logic or use built-in tools
