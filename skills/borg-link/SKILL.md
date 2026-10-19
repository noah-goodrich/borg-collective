---
name: borg-link
description: >
  The front door to the collective. In the Queen session it is the cross-repository overview with
  directives and recent ships; in a repository or worktree, or for a named repository, it is a page
  on that one directory. Use when the user asks for status, overview, briefing, "what's going on",
  or repository details.
user-invocable: true
allowed-tools: Bash(borg link *) Bash(echo *)
---

# Borg Link — Neural Link to the Collective

Paint the CLI's page; do not rewrite it. `borg link` already built it, one screen wide and tall, the same way every run. The session's directory decides the page: the Queen page at `BORG_ORCHESTRATOR_ROOT`, a repository's page inside a repository. `$ARGUMENTS` rides along: a repository name, `--overview` or `--full`. In a drone the SessionStart hook already injected the latest checkpoint, so run this skill only when asked, never as a session-start ritual.

The page, expanded before you read it (the injected command cannot exit non-zero; on failure it prints `BORG-LINK-UNAVAILABLE`):

<<< PAGE
!`NO_COLOR=1 borg link $ARGUMENTS 2>&1 || echo BORG-LINK-UNAVAILABLE`
>>> PAGE

## Paint

The user asked to see the board, so show it:

1. Copy the page between the markers byte for byte into ONE fenced block (a fence longer than any backtick run inside the page). No other tool call: no Bash, no jq, no Read.
2. Below the block write at most 2 plain lines: the verdict and the one next step. No heading, table or bullets. Inside the block never fix, shorten, reorder or annotate a line; comments go only in these 2 lines. a line ending in `…` stays cut. Do not hard-wrap output.
3. The page is plain text with no escape bytes. Do not add any.

## Fallback

Use this when the markers hold the unexpanded injection line (Cortex Code expands no dynamic injection) or hold `BORG-LINK-UNAVAILABLE`. Make ONE Bash call, `NO_COLOR=1 borg link [<repository>]`, then paint its output by the rules above. If that call fails too (non-zero exit, `borg` missing), Read `references/fallback.md` (relative to this skill's base directory) and follow it. Read it only then.

## Questions

When the user asks about the board instead of asking to see it ("why is X blocked?", "what waits on me?"), Read `references/questions.md` (relative to this skill's base directory) and answer in prose from its `--json` read. The paint path is for seeing the page; this path is for answers.

`--refresh` and `--brief` need the host: if asked, tell the user to run `borg link --brief` / `--refresh` there. `--full` prints every stack and directive in the CLI's own page.

Read-only in spirit: never write `registry.json` or any `state.json`.
