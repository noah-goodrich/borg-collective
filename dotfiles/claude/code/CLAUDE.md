# Personal Preferences

## Communication
- Show me the command I need to run, don't just describe it.
- Chain commands with && or ; so I can copy-paste one block.

## Code Style
- 4-space indentation everywhere except YAML/Lua (2-space)

## Bash Tool Rules

### Permission Pattern Gotchas
Claude Code's `*` wildcard does NOT match shell operators (`|`, `&&`, `;`).
A rule like `Bash(ls:*)` will NOT match `ls -la | grep foo`.

Use these patterns to avoid permission prompts:

| Instead of                    | Use                                          |
|-------------------------------|----------------------------------------------|
| `cd /path && command args`    | `run-in /path command args`                  |
| `cd /path && git ...`        | `git -C /path ...`                           |
| `command1 \| command2`        | `bash -c 'command1 \| command2'`             |
| `VAR=val command args`        | `bash -c 'VAR=val command args'`             |
| `cmd1 && cmd2 && cmd3`        | `bash -c 'cmd1 && cmd2 && cmd3'`             |

- `run-in` is at `~/.claude/bin/run-in` (installed by `borg setup`).
- `bash -c` is in the global allowlist. Use it for pipelines and compound commands.
- Prefer built-in tools (Grep, Glob, Read) over Bash when they can do the job.

### Other Rules
- **No inline `#` comments in one-liner bash commands.** Quotes inside comments confuse the
  shell parser and trigger approval prompts.
- **Always use absolute paths, never `~`.** Permission prefix matching is literal.
- **Never use `$()` command substitution in Bash tool calls.** Use parameter expansion or pipes.

## Environment
- TODO: Fill in your environment details
- Terminal: ___
- Editor: Neovim
- Multiplexer: tmux (Ctrl+Space prefix)
- Shell: zsh with powerlevel10k
- Devcontainers for project isolation (Docker Compose)

## Dotfiles
- Repo: ~/.config/dotfiles (symlinked to standard locations)
- Dev CLI: ~/dev/dev.sh (aliased as `dev`)

## Session Continuity
If a previous session was compacted, context is at @~/.claude/handovers/latest.md
