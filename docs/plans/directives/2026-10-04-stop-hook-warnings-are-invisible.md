# Directive: Stop-hook warnings are invisible
*Filed: 2026-10-04*
*Decided by Noah 2026-10-04 (directive triage, #266): leave open. AC5: Noah watching for the live render.*

**tl;dr** — `hooks/borg-link-up.sh` is a Stop hook. Every warning it prints goes to stderr and it then exits 0, and
for a hook that exits 0 Claude Code sends stderr to the debug log only: not the user, not Claude. So the "uncommitted
changes" warning, the "No checkpoint in the last hour" nudge and the "Directive reconciliation?" list have most likely
never reached anyone. Found by a blind design reviewer on 2026-10-03. The fix is one JSON object on stdout carrying
the text in `systemMessage`. It does NOT make Claude continue.

## Problem

### Evidence

`grep -n '>&2' hooks/borg-link-up.sh` on `main` at `06ae9d7` returned three groups, all ANSI-coloured, all followed by
the script's unconditional `exit 0`:

1. `▸ WARNING: <project> has uncommitted changes` / `Run /simplify then commit before your next session.`
2. `▸ No checkpoint in the last hour for <project>` / `Run /borg-link-up next session to save state ...`
3. `▸ Directive reconciliation? Committed files overlap with:` plus a `  - <directive>.md` list

The registration is a `Stop` hook for both Claude Code and CoCo (header of the script; `borg setup` installs it).

### The contract (confirmed 2026-10-04 against https://code.claude.com/docs/en/hooks)

- **Exit code 0, stderr**: "Stderr from a hook that exits 0 goes to the debug log only, never the transcript, and
  Claude never sees it." (section "Exit code 0"). Plain stdout from a non-context event is also only written to the
  debug log; the events whose plain stdout reaches Claude are `UserPromptSubmit`, `UserPromptExpansion`,
  `SessionStart` and `PostModelSwitch`. `Stop` is not among them.
- **Showing the user a message**: "To surface a message to the user on any platform, return `systemMessage` in JSON
  output." `systemMessage` is a universal field: "Warning message shown to the user" (JSON output table). Some events
  discard it, and each event's section says so; the `Stop` section does not list it as discarded.
- **JSON parsing rule**: stdout is parsed as JSON only when, ignoring surrounding whitespace, it starts with `{` and
  ends with `}`. Anything else is plain text (ignored for Stop). A parse failure is a non-blocking `hook error` notice,
  so stdout must hold exactly ONE object and nothing else.
- **Making Claude see it** (NOT what we want): `Stop` honours `decision: "block"` + `reason`, exit 2 with stderr, and
  `hookSpecificOutput.additionalContext`. All three keep the conversation going (capped at 8 consecutive
  continuations, guarded by the `stop_hook_active` input). Firing one on every turn is a loop by construction.
- `systemMessage`, like all hook strings, is capped at 10,000 characters.

Unverified by experiment: the docs say `systemMessage` is shown to the user and that Stop does not discard it; nobody
has yet watched it render in a live session. AC5 below is that check.

## Solution

`borg-link-up.sh` accumulates each applicable warning into one plain-text string (no ANSI; terminals render the
`systemMessage` themselves) and, only when the string is non-empty, prints `{"systemMessage": "..."}` via `jq -n --arg`
as the last thing before `exit 0`. No warnings means no stdout at all. State writes, exit code and every other
behaviour are unchanged.

## Acceptance criteria

1. **Each warning is delivered as `systemMessage`.** *Verify:* `bats tests/lifecycle.bats` has one case per condition
   (uncommitted, no recent checkpoint, directive overlap) asserting stdout is valid JSON whose only key is
   `systemMessage` and whose text contains the warning.
2. **One object, all warnings.** *Verify:* the "all three conditions" case in `tests/lifecycle.bats` asserts
   `jq -s length` is 1 and the message carries all three.
3. **No ANSI, no stderr, exit 0, silent when clean.** *Verify:* the same cases assert no ESC byte in stdout or the
   message, an empty stderr file, rc 0; and the "nothing to warn about" case asserts empty stdout.
4. **The tests can fail.** *Verify:* restoring the pre-fix script (`git show origin/main:hooks/borg-link-up.sh`) turns
   the four positive cases red; recorded in the PR.
5. **It renders.** *Verify (manual, one time):* after `borg setup` redeploys the hook, end a Claude Code session in a
   dirty repo and see the `systemMessage` text in the terminal. If it does not render, this directive's premise about
   Stop is wrong and the fallback is re-filed here before anything else is built on it.
6. **Suite green.** *Verify:* `make test && make test-bats && make lint`.

## Other hooks with the same shape

Audit: `grep -n '>&2' hooks/*.sh`, each event checked against the "Exit code 2 behavior per event" table.

- `hooks/borg-nanoprobe-log.sh` (SubagentStop): NANOPROBE EVIDENCE WARNING and ZERO-COMMIT messages go to stderr, exit
  0. Same invisible shape. NOT fixed here: it has two warnings and a different consumer (the orchestrator is the reader
  who needs it), and SubagentStop's `systemMessage` handling is not confirmed. Follow-up.
- `hooks/borg-plan-promote.sh` (PreToolUse): prints `[borg] auto-promoted in-session plan ...` to stderr and exits 0.
  PreToolUse exit-0 stderr is not in the shown-to-user rows of that table. It is an informational courtesy, not a
  safety nudge. Follow-up, lowest priority.
- `hooks/bash-guard.sh`, `borg-dispatch-guard.sh`, `borg-supabase-guard.sh` (PreToolUse): stderr paired with exit 2,
  which blocks and routes stderr to Claude. Correct; not affected.

## Non-goals

- Do not make Claude continue: no `decision: "block"`, no exit 2, no `additionalContext`. These nudges are for the
  human at the end of a turn.
- Do not add new warnings or change when the existing three fire.
- Do not change the registry/state.json writes, the clock-divergence logic or the orchestrator-mode early exit.
- Do not fix the two follow-up hooks above in this change.

## Deploy note

`hooks/` are copied to `~/.claude/hooks` by `borg setup`; run it after merge or the fix is not live. The claude-plugins
copy is build output (`scripts/build-plugin.sh`); `borg-link-up.sh` is one of the hooks that script inlines
`lib/borg-hooks.sh` into, so rebuild the plugin from source rather than editing it there.

## Regression found 2026-10-04

The `systemMessage` fix (#258) made the three `borg-link-up.sh` warnings visible, and because Stop fires after every
assistant turn they then repeated after every reply: alert spam against the interrupt-budget evidence. Fixed by
showing each distinct warning at most once per session. Key: `session_id` plus sha12 of (message + fingerprint, where
the uncommitted-changes fingerprint is the porcelain file list, so a new dirty file re-fires). Stored one key per
line in `<state root>/stop-warnings/<session_id>` (`_borg_state_root`, machine-local; not the config dir, not the
repo). Every failure fails open toward visibility: no `session_id` or an unwritable store means the warning shows.
Audit of the siblings: `borg-nanoprobe-log.sh` (SubagentStop) fires once per subagent completion and its messages
name the agent id, so no dedupe; `borg-plan-promote.sh` (PreToolUse) is gated on no existing `PROJECT_PLAN.md`, so
its notice is one-shot by construction. Pinned by the "stop dedupe" cases in `tests/lifecycle.bats`.
