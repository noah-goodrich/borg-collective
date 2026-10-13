## Permissions
- **Never accept project-level permission prompts.** When Claude Code offers "Yes, and allow X", always choose plain "Yes" instead. All permissions are managed globally in `~/.claude/settings.json`. Project-level `settings.local.json` files should have empty allow lists. Do not add permissions to project-level settings.

## Bash Tool Rules

### Plain commands by default
Allow rules are matched per subcommand, so a pipe, `;`, `&&` or `||` chain is checked one part at a time and needs no wrapper (https://code.claude.com/docs/en/permissions.md). Write these directly:
- Single commands, pipes (`cmd1 | cmd2`), `;` and `&&` chains.
- Leading env assignment: `env VAR=val cmd` or `VAR=val cmd | cmd2`.
- `awk` filters and other one-line text tools.

Avoid these shapes, which cannot be checked before they run (top-level prompt, flat denial in subagents):
- Loops, `$(...)` and heredocs piped into an interpreter. Split them into separate plain calls, use a named `borg` command, or use the Read and Grep tools.

| Instead of                    | Use                                          |
|-------------------------------|----------------------------------------------|
| `cd /path && command args`    | `run-in /path command args`                  |
| `cd /path && git ...`         | `git -C /path ...`                           |
| `cat file \| grep x`           | the Grep or Read tool                        |
| `jq ... file \| head -5`       | a `jq` slice such as `.[:5]`                 |

- `run-in` is at `~/.claude/bin/run-in` (installed by `borg setup`).
- Use `bash -c` only for genuine control flow (loops, conditionals) that cannot be a plain command or a tool call. Keep such a script free of brace text and `$` inside nested quotes. `bash -c` stays in the global allowlist.
- If the removal check denies a command, restructure it as a plain command or use a tool. Never respell, split or script a command to get past the check.
- Genuine deletions use literal paths, never variable targets, so the check can judge them. Do not obfuscate or respell the removal word for any reason.
- Long data heredocs (code or docs) belong in the Write tool, followed by a short command on the file.
- Prefer built-in tools (Grep, Glob, Read) over Bash when they can do the job.

### Other Rules
- **No inline `#` comments in one-liner bash commands.** Quotes inside comments confuse the
  shell parser and trigger approval prompts.
- **No temp scripts.** Don't `cat > /tmp/foo.sh && bash foo.sh`. Use plain commands, a named
  `borg` command, or built-in tools (Glob, Grep, Read); a short `bash -c` loop only for genuine control flow.
- **Always use absolute paths, never `~`.** Permission prefix matching is literal —
  `find ~/dev` doesn't match `Bash(find:*)` the same way `find /Users/noah/dev` does.
- **Never use `$()` command substitution in Bash tool calls.** The shell parser flags it as
  dangerous and triggers approval prompts. Instead:
  - `$(basename "$x")` → pipe to `basename` or use `${x##*/}` parameter expansion
  - `$(dirname "$x")` → use `${x%/*}` parameter expansion
  - `$(wc -l < file)` → `wc -l file` as its own call
  - `$(command)` in echo → break into separate tool calls or use a variable set earlier in
    the pipeline
  - If substitution is truly unavoidable, use separate plain calls; a `bash -c` loop only as a last resort.

## Subagent Rules
When spawning subagents via the Agent tool, ALWAYS include these rules in the prompt:
- Write pipes and `;`/`&&` chains as plain commands (matched per subcommand); `bash -c` only for genuine control flow
- Use `run-in /path command` instead of `cd /path && command`
- Use absolute paths, never `~` (e.g. `/Users/noah/dev` not `~/dev`)
- No `$()` command substitution in Bash tool calls — use parameter expansion or pipes
- Genuine deletions use literal paths; never respell the removal word or script around the check
- No inline `#` comments in one-liner bash commands
- Prefer built-in tools (Grep, Glob, Read) over Bash equivalents (grep, find, cat)
- Never put backticks or `$(` inside an unquoted heredoc or a double-quoted string; for PR/commit bodies
  use `<<'EOF'` or `--body-file`.
