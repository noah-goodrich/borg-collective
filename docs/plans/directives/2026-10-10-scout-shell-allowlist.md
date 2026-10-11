# Directive: Give borg-scout read-only git/gh through an allowlist
*Filed: 2026-10-10 · Status: Proposed · Owner: Noah*

**tl;dr** — PR #284 first gave `borg-scout` a Bash grant guarded by a denylist-style parser, and three independent reviews each found a new way past it, so the grant was split out and the scout went back to read-only file tools. This directive files the retry: the scout gets read-only `git` and `gh` only through an ALLOWLIST (an explicit command-and-subcommand table, a strict safe charset for every token, fail closed), shipped with a test for every bypass class the reviews found and a parse check under macOS `/bin/bash` 3.2.

## Problem

- **The scout cannot answer git or GitHub questions.** "What is the state of PR X?" and "what changed in commit Y?" are the commonest lookups an orchestrator wants from a cheap agent, and `agents/borg-scout.md` has read-only file tools and no Bash. `docs/agent-routing.md` therefore routes those lookups to agents that do have Bash, which costs a more expensive tier for a read.
- **A denylist cannot close this surface.** The guard in #284 tried to recognise dangerous options and subcommands, and each review round found another spelling of the same escape. The classes, described generically:
  - **Abbreviated long options.** `git` and `gh` accept unambiguous prefixes, so `--outpu=` reaches `--output=` and writes a file.
  - **Bundled or attached short options.** `-nOtouch` is `-n -O touch`: a short option with its value attached, hidden inside a cluster the guard looked at only by token start.
  - **ANSI-C quoting.** `$'\x2d\x2doutput=...'` expands to a long option after the guard has read it as an inert word.
  - **Brace expansion.** `--out{put=...,}` and `{-n,-Ox}` produce option tokens that never appear in the text the guard inspected.
  - **Reads outside the repo.** `--no-index`, `-f file`, `gh api` with an absolute URL or `--hostname`, and `-H` overriding the HTTP method each turn a "read the repo" command into a read of arbitrary files or hosts, or a write.
- **The hook itself was fragile.** A heredoc nested in command substitution with a backtick parsed on bash 5 and exited 2 on macOS `/bin/bash` 3.2, so a PreToolUse hook blocked every call instead of failing open. `tests/hook_bash32_parse.bats` now pins parsing of every hook; the scout hook must be covered by it.

## Solution

One new PreToolUse(Bash) hook, active only when the caller is the scout, built as an allowlist from the first line.

1. **Command-and-subcommand table.** An explicit table of permitted `git` and `gh` invocations, for example `git log|show|diff|status|blame|ls-files|rev-parse`, `gh pr view|list|diff|checks`, `gh issue view|list`, `gh run view|list`, `gh repo view`. Anything absent from the table is denied; there is no "everything except".
2. **Per-token charset.** Every token must match a strict safe set (ASCII letters, digits, and a short list of punctuation such as `.`, `_`, `-`, `/`, `=`, `:`, `@`, `,`). A token outside it denies the whole command.
3. **Reject the expansion and control characters outright.** Any command containing `$`, a backtick, a quote, a backslash, a brace, a bracket, a glob character, a redirect, a separator (`;`, `&`, `|`, newline) or a non-ASCII byte is denied before any parsing. This is what closes ANSI-C quoting and brace expansion by construction, rather than by recognising them.
4. **Options come from a per-command list.** Each table row names the exact options it accepts, long form spelled in full. An unlisted option, an abbreviation, or a cluster of short options is denied, so abbreviation and bundling need no special handling.
5. **Read-outside-repo options are simply not on any row.** `--no-index`, `-f`, `--hostname`, `-H`, `--method`, `--input`, and `gh api` with a URL are absent, so they are denied. If `gh api` is wanted at all it is a separate row with a path-only argument that must start with `repos/`.
6. **Fail closed.** Any parse doubt, missing `jq`, or unexpected input shape denies when the caller is the scout. For every other caller the hook is a no-op that allows, so it cannot block ordinary Bash.
7. **Ship together.** The hook, its registration in `scripts/build-plugin.sh`, the Bash grant in `agents/borg-scout.md`, the `docs/agent-routing.md` text, and an agent-roster test pinning the scout and the guard to ship as a pair land in one PR, so the scout never has Bash without the guard.

## Non-Goals

- Not a general shell sandbox. The allowlist covers `git` and `gh` reads and nothing else; the scout gets no other commands.
- Not enforcing for agents other than the scout.
- Not parsing shell. The design avoids understanding quoting at all by rejecting every character that would need it.
- Not reviving the #284 denylist guard in any reduced form.

## Alternatives

- **A: Keep the denylist and keep patching.** Rejected: three reviews found three new classes; each fix widened the parser, which is the surface that kept failing.
- **B: Leave the scout without Bash and route git/gh to the grunt.** This is the state after the #284 split and is the fallback if this directive is not worth building. Cost: a Haiku grunt call per lookup and a spec-writing step for the orchestrator.
- **C: Give the scout the `gh` and `git` calls as dedicated tools or MCP read endpoints rather than Bash.** Removes the shell question entirely but needs a tool surface the plugin does not have today; worth a look before building the hook.

## Acceptance criteria

- [ ] Every command the table lists is allowed and every other `git`/`gh` command is denied.
  - Verify: `bats tests/scout_shell_allowlist.bats` passes, with one allow case per table row and a deny case for an unlisted subcommand.
- [ ] Every bypass class from the #284 reviews is a failing-to-bypass test.
  - Verify: the same suite contains a deny case for each of: abbreviated long option (`--outpu=`), bundled short option (`-nOtouch`), attached short option value, ANSI-C quoting (`$'\x2d\x2doutput=...'`), brace expansion (`--out{put=...,}` and `{-n,-Ox}`), `--no-index`, `-f file`, `gh api` with an absolute URL, `gh api --hostname`, and `-H` method override.
- [ ] The charset and rejection rules fail closed.
  - Verify: cases for `$`, backtick, each quote, backslash, brace, bracket, glob, redirect, each separator and a non-ASCII byte all deny; malformed JSON input and a missing `jq` deny for the scout and allow for any other caller.
- [ ] The hook parses under macOS `/bin/bash` 3.2.
  - Verify: `bats tests/hook_bash32_parse.bats` passes with the new hook in `hooks/`, and the allowlist suite runs the hook itself under `/bin/bash`, not only under a newer bash.
- [ ] The scout never ships with Bash and without the guard.
  - Verify: an agent-roster case fails when `agents/borg-scout.md` grants Bash and the guard is absent from `scripts/build-plugin.sh`, and the reverse.
- [ ] Docs match behaviour.
  - Verify: `rg -n "scout" docs/agent-routing.md` shows the git/gh text and the guard named, and `make lint && make test && make test-bats` pass.
