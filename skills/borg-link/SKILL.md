---
name: borg-link
description: "The front door to the collective. In the Queen session it is the cross-repository overview; in a repository, worktree or named repository, a page on that one directory. Use for status, overview, briefing, \"what's going on\", repository details, \"what changed\", \"catch me up\", \"morning link-up\", \"recon\"."
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
2. Below the block write plain lines that only restate the page. Line 1 restates the page's Waits on you list (under IN FOCUS) and its WAITING ON YOU section: each item by name, or that the page lists nothing. When WAITING ON YOU reads "what waits on you is listed above", it points at that list, so name the items from it. Line 2 restates the page's closing next line. Add no verdict of your own: never write that nothing waits on the user or that nothing is ready unless the WAITING ON YOU section of the page says so, and then attribute it to the page ("the page lists nothing waiting"). No heading, table or bullets. Inside the block never fix, shorten, reorder or annotate a line; comments go only in these lines. a line ending in `…` stays cut. Do not hard-wrap output.
3. The page is plain text with no escape bytes. Do not add any.
4. When the page names decisions that wait on the user, finish with the next section. It is the one thing allowed after the paint; the paint itself makes no other call.

## Decisions that wait on you

After the paint, and only when the page's Waits on you list or WAITING ON YOU names a decision (a question for the user to answer, not a chore such as rotating a token), ask the decisions instead of leaving them as a list. Never answer them yourself and never end the reply with a bare "Needs you" list: the Stop hook (`borg-decision-gate.sh`) blocks that.

1. Make ONE call for the full cards: `borg link --json [<repository>] | jq -c '[.waiting.rows[]? | select(.owner == "YOU") | {project, next_step, decision_card, url}]'`. A row with a `decision_card` is a decision card (title, Context, Why open, Options with Pro, Con and Runs, Recommend). A row with no `decision_card` is a one-line wait: say so in one line ("no card: <title>"), do not invent context for it, and do not ask it.
2. Ask the cards through AskUserQuestion in rounds of 4: at most 4 questions per call, the most urgent first, then the next round after the answers. One question per card. The question text stands alone for a reader who has seen nothing this session: what the thing is, why it is open and the source link. 2 to 4 options per question, the recommendation first and its label ending `(Recommended)`; each option's description holds its pro, its con and what choosing it runs. The header is the repository or ref, 12 characters or fewer.
3. After each round, state in one line per answer what was chosen. Run an option's command only when the user chose that option, and only when it is not a production write; a production write gets its own ask. Offer a checkpoint update when answers settle a card, so the next session does not ask it again.

## Fallback

Use this when the markers hold the unexpanded injection line (Cortex Code expands no dynamic injection) or hold `BORG-LINK-UNAVAILABLE`. Make ONE Bash call, `NO_COLOR=1 borg link [<repository>]`, then paint its output by the rules above. If that call fails too (non-zero exit, `borg` missing), Read `references/fallback.md` (relative to this skill's base directory) and follow it. Read it only then.

## A graph

When the user asks to SEE a graph, dependencies, a stack, a train or a chain, skip the page: make ONE Bash call, `NO_COLOR=1 borg link --stacks [<repository>]` (`--all` adds merged stacks), and paint its output in one fenced block by the paint rules above. Borg board data is never rendered through the Artifact tool, the diagram-design skill or an HTML file: the terminal picture is the answer.

## Since a mark

When the user asks what changed since a mark ("morning link-up", "what changed", "catch me up", "recon"), skip the paint: Read `references/recon.md` (relative to this skill's base directory) and follow it. It runs `borg recon --json`, a different read from the page. Asking to see the board, status or overview stays on the paint path above.

## Questions

When the user asks about the board instead of asking to see it ("why is X blocked?", "what waits on me?"), Read `references/questions.md` (relative to this skill's base directory) and answer in prose from its `--json` read. The paint path is for seeing the page; this path is for answers.

`--refresh` and `--brief` need the host: if asked, tell the user to run `borg link --brief` / `--refresh` there. `--full` prints every stack and directive in the CLI's own page.

Read-only in spirit: never write `registry.json` or any `state.json`.
