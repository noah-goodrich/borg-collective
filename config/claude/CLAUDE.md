## Permissions
- **Never accept project-level permission prompts.** When Claude Code offers "Yes, and allow X", always choose plain "Yes" instead. All permissions are managed globally in `~/.claude/settings.json`. Project-level `settings.local.json` files should have empty allow lists. Do not add permissions to project-level settings.

## Bash Tool Rules

### Plain commands by default
Allow rules are matched per subcommand, so a pipe, `;`, `&&` or `||` chain is checked one part at a time and needs no wrapper (https://code.claude.com/docs/en/permissions.md). Write these directly:
- Single commands, pipes (`cmd1 | cmd2`) and `;` chains. `&&` chains follow the same per-subcommand rule but were not exercised; prefer `;` or separate calls.
- Leading env assignment: `VAR=val cmd | cmd2`.
- `awk` filters and other one-line text tools.

Avoid these shapes, which cannot be checked before they run (top-level prompt, flat denial in subagents):
- Loops, `$(...)` and heredocs piped into an interpreter. Use separate plain calls, a named `borg` command where one exists, or Read and a search (Grep where the session has it, else `grep` through Bash). A lone loop is the one case that runs only as `bash -c`.

| Instead of                    | Use                                          |
|-------------------------------|----------------------------------------------|
| `cd /path && command args`    | `run-in /path command args`                  |
| `cd /path && git ...`         | `git -C /path ...`                           |
| `cat file \| grep x`           | Read, or `grep x file` (Grep if present)     |
| `jq ... file \| head -5`       | a `jq` slice such as `.[:5]`                 |

- `run-in` is at `~/.claude/bin/run-in` (installed by `borg setup`).
- Use `bash -c` only for genuine control flow (loops, conditionals) that cannot be a plain command or a tool call. `bash -c` stays in the global allowlist.
- If the removal check denies a command, restructure it as a plain command or use a tool. Never reshape, respell or script a command only to get past the removal check.
- Genuine deletions use literal paths, never variable targets, so the check can judge them. Do not obfuscate or respell the removal word for any reason.
- Long data heredocs (code or docs) belong in the Write tool, followed by a short command on the file.
- Read files with Read. Search with Grep and Glob where the session has them. Main sessions on macOS, Linux and WSL do not by default (Claude Code leaves them out; `find` and `grep` run through Bash as embedded `bfs` and `ugrep`; naming Grep or Glob in `--tools` restores them), so there use `grep`, `rg` or `find` through Bash under the same narrowness rules: tight patterns, a named path, `head` limits, never `find /`.

### Other Rules
- **No inline `#` comments in one-liner bash commands.** Quotes inside comments confuse the
  shell parser and trigger approval prompts.
- **No temp scripts.** Don't `cat > /tmp/foo.sh && bash foo.sh`. Use plain commands, a named
  `borg` command where one exists, or Read, Glob and Grep where present; a short `bash -c` loop only for genuine control flow.
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
- Read files with Read; search with Grep and Glob where your tool list has them, else `grep`/`find` through Bash with tight patterns and a named path
- Never put backticks or `$(` inside an unquoted heredoc or a double-quoted string; for PR/commit bodies
  use `<<'EOF'` or `--body-file`.
