# Directive: a session's in-flight fan-out is visible to its peers

*Filed: 2026-10-07 · Status: Proposed · Owner: Noah*

**tl;dr** — A long-running Workflow is invisible to every session but its own, so two sessions research the same
question and neither finds out. It happened twice on 2026-10-07, once for ~2.2M tokens. `borg-dispatch-guard.sh`
already intercepts every `Agent|Workflow` call; have it also write one line per dispatch to a shared state file, and
surface that file in `ListAgents`' neighbourhood and in `borg link`.

- Plan-slug: `2026-10-07-in-flight-fanout-visibility`

## Problem

- **Two sessions answered the same question, neither aware of the other.** On 2026-10-07 the Queen ran a 6-agent
  workflow (`marche-migration-state`, ~645K tokens) on the DE plugin migration's plan, waves, live state and
  Jira/Notion shape. `claude-marche-43` was already 1h53m into `sync-de2182-proposal` (~1.6M tokens) covering
  substantially the same ground. Roughly 2.2M tokens, one answer.
- **The same failure, same day, different pair.** The dbt drone independently drafted a finding on `Ontra-ai/dbt#1332`
  that the Queen had also produced, for the same reason.
- **Nothing in borg carries the signal.** `.borg/state.json` holds status, not subject. The `next:` line the
  SessionStart hook surfaces comes from `.borg/checkpoints/*.md`, written by `/borg-link-up` at session END — which is
  the wrong moment by hours. Both collisions happened mid-session, long before either side would checkpoint.
- **`ListAgents` shows liveness, not subject.** It reports `claude-marche-43 · interactive · idle`. "Idle" was true —
  the session was at its prompt while a background workflow burned 1.6M tokens. The roster cannot distinguish a session
  doing nothing from a session 5/6 through a fan-out.
- **Discipline does not close it.** `docs/` already carries the finding that capture is not enforcement. A memory
  telling the operator to check first only fires if it is read at the right moment, which is exactly what failed.

## Solution

Extend `hooks/borg-dispatch-guard.sh`, which is already registered `PreToolUse (matcher Agent|Workflow)` and already
sees every dispatch. It currently exits 0 on nearly every path; add a write before those exits.

On each `Agent|Workflow` dispatch, append one line to
`${XDG_STATE_HOME:-$HOME/.local/state}/borg/in-flight.jsonl`, matching the existing `prefer-tool.jsonl` convention:

```json
{"ts":"2026-10-07T21:12:04Z","session":"691ab464","project":"dev","tool":"Workflow",
 "name":"marche-migration-state","desc":"Find the DE plugin migration plan ...","agents":6,"pid":20799}
```

`name` and `desc` come free: `meta.name` and `meta.description` are mandatory in every workflow script, so no author
discipline is required and nothing new has to be remembered. For the `Agent` tool, `description` plays the same role.

Two readers make it useful:

- **`borg link`** gains one line per project in the overview when a fan-out is open and younger than the TTL:
  `▸ claude-marche — 1h53m into sync-de2182-proposal (5/6)`.
- **A `borg in-flight` subcommand** prints the same thing on demand, so a session about to fan out can check in one
  call rather than reading a JSONL by hand.

Staleness is handled on read, never by a cleanup hook: a row older than `BORG_INFLIGHT_TTL_SEC` (default 7200) is
ignored, so a crashed session leaves no tombstone and no Stop-hook bookkeeping is needed.

## Acceptance criteria

- [ ] A `Workflow` dispatch appends exactly one well-formed JSON line to `in-flight.jsonl`. Verify: dispatch a
      two-agent workflow, then `tail -1` the file and pipe it through `jq -e` — it parses and carries `name` and
      `desc` matching the script's `meta`.
- [ ] An `Agent` dispatch does the same with `tool":"Agent"` and the agent's `description`. Verify: same shape.
- [ ] The guard still fails OPEN. Verify: make the state directory unwritable, dispatch, and confirm the tool call is
      allowed and the hook exits 0. The write must never be able to block dispatch — that contract is the whole reason
      this hook is safe to extend.
- [ ] The existing >=92% veto is unchanged. Verify: the hook's current test suite passes untouched, and an armed
      near-cap session still denies with its reason on stderr.
- [ ] `borg link` shows an open fan-out on another project and omits one older than the TTL. Verify: write two rows by
      hand, one fresh and one backdated past `BORG_INFLIGHT_TTL_SEC`, and confirm only the fresh one renders.
- [ ] `borg in-flight` prints the open rows and exits 0 when there are none.
- [ ] No row carries prompt text. Verify: grep the emitted line for the workflow's script body — absent.

## Non-Goals

- **No cross-session locking.** This reports; it never blocks a second session from working the same question. Two
  sessions on one question is sometimes correct (adversarial review), and a lock would break that.
- **No new hook.** `borg-dispatch-guard.sh` already runs on exactly the right matcher. A second hook on the same event
  is more surface for no gain.
- **No Stop/SubagentStop cleanup.** TTL-on-read is cheaper and survives crashes, which a cleanup hook does not.
- **No prompt capture.** `meta.name` and `meta.description` only. Prompts carry customer data and this file is shared
  across every session on the machine.

## Alternatives Considered

- **Write the lane into `.borg/state.json` or the registry.** Rejected: borg owns those files, and the `next:` line
  that would surface it is written at session end by `/borg-link-up` — hours after the window in which it would have
  helped.
- **Rely on an operator memory to call `ListAgents` first.** Filed as `feedback-listagents-before-fanout`, and worth
  keeping, but it is the same shape as the rules this repo has already found go unapplied. It is a complement, not
  the fix.
- **Extend `ListAgents` itself to report the subject.** The right end state, but it is Claude Code's tool, not borg's.
  This directive puts the data somewhere borg controls; if the tool later carries it, this becomes redundant and gets
  retired.
- **The merge-tree hub.** Already exists as the cross-repo command centre and is the natural long-term home. Rejected
  for now as more work than the problem needs — revisit once the JSONL has proven the signal is worth reading.

## Risks

- **A shared file across sessions is a contention surface.** Mitigated by append-only `>>` of a single line, which is
  atomic under PIPE_BUF on local filesystems, and by the fail-open contract.
- **The signal gets ignored anyway.** Writing it is not reading it. The `borg link` surfacing is the part that makes it
  land; a JSONL nobody renders is the same failure one layer down.
- **Noise.** Every `Agent` dispatch writes a row, including one-agent lookups. If the file turns out to be mostly
  noise, filter on `agents >= 3` at write time rather than adding a reader-side threshold.

## Decisions requested

1. Filter at write time or render time? Writing everything keeps the data honest; filtering keeps the file small.
2. Does `borg in-flight` earn its own subcommand, or is the `borg link` line enough?
