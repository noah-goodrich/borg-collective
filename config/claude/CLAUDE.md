## Permissions
- **Never accept project-level permission prompts.** When Claude Code offers "Yes, and allow X", always choose plain "Yes" instead. All permissions are managed globally in `~/.claude/settings.json`. Project-level `settings.local.json` files should have empty allow lists. Do not add permissions to project-level settings.

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
- **No temp scripts.** Don't `cat > /tmp/foo.sh && bash foo.sh`. Inline the logic as a
  `for`/`while` loop or use built-in tools (Glob, Grep, Read).
- **Always use absolute paths, never `~`.** Permission prefix matching is literal —
  `find ~/dev` doesn't match `Bash(find:*)` the same way `find /Users/noah/dev` does.
- **Never use `$()` command substitution in Bash tool calls.** The shell parser flags it as
  dangerous and triggers approval prompts. Instead:
  - `$(basename "$x")` → pipe to `basename` or use `${x##*/}` parameter expansion
  - `$(dirname "$x")` → use `${x%/*}` parameter expansion
  - `$(wc -l < file)` → pipe: `cat file | wc -l`
  - `$(command)` in echo → break into separate tool calls or use a variable set earlier in
    the pipeline
  - If substitution is truly unavoidable, use a `for` loop with the variable set via pipe:
    `... | while read -r val; do echo "$val"; done`

## Subagent Rules
When spawning subagents via the Agent tool, ALWAYS include these rules in the prompt:
- Use `bash -c '...'` for pipelines and compound commands (`|`, `&&`, `;`)
- Use `run-in /path command` instead of `cd /path && command`
- Use absolute paths, never `~` (e.g. `/Users/noah/dev` not `~/dev`)
- No `$()` command substitution in Bash tool calls — use parameter expansion or pipes
- No inline `#` comments in one-liner bash commands
- Prefer built-in tools (Grep, Glob, Read) over Bash equivalents (grep, find, cat)
