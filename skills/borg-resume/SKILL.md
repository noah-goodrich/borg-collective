---
name: borg-resume
description: Manual and fallback path for resuming work that a session/usage limit (or another interruption) paused or killed. Use when a Workflow fails or pauses with a "session limit" / "usage limit" / "resets <time>" error, or when the user says "resume after reset", "auto-resume the workflow", or "pick it back up when the limit clears". It checks the resume watcher first and only schedules an in-session one-shot scheduled resume when no watcher is running.
---

# borg-resume: manual and fallback resume

The primary mechanism is the **resume watcher** (a launchd job running `borg-resume watch --once`), fed by the
`borg-resume` hook ledger. It records every interruption, waits for the reset, and injects one grouped resume prompt
into the right pane after a pre-flight gate and an idle proof. This skill is the manual path and the fallback when that
watcher is absent. Prevention is a separate layer (the usage guardian, `bin/borg-usage-watch`).

## Step 1: ask the watcher first

Always run this before anything else:

`borg-resume status --all --json`

It lists records with `rid`, `sid`, `scope`, `state`, `class`, `resume_at` and `due_in` (seconds), plus `paused` and
`disabled_env`. If the command exits non-zero or `borg-resume` is not on PATH (for example the installed lib is missing
or partial), the watcher is unavailable: tell the user so, and treat it as "no watcher" in Step 2.

**Match a record to your own work.** For a Workflow, match `scope == "workflow:<runId>"` (the `wf_...` id). For anything
else, match `sid` against your session id (`$CLAUDE_CODE_SESSION_ID`; if it is unset, ask rather than guess).

- If a matching record is active (`new`, `scheduled`, `deferred`, `injecting`, `injected`, `confirmed`), **do nothing
  else**. Tell the user which record it is and the time it will resume (from `resume_at`). If `paused` or `disabled_env`
  is true, say injection is switched off and name the switch (below).
- If the only matching records are terminal (`failed`, `stalled`, `capped`, `expired`, `notify_only`, `cancelled`),
  report them to the user and do NOT `CronCreate`; the watcher already made a decision.
- If nothing matches, the hook may not have fired yet; the watcher scan also finds interrupted sessions from
  transcripts. Run `status` once more after the 30 second scan interval, then go to Step 2 only if the watcher is
  unavailable.

## Step 2: fallback only, no working watcher

Use this ONLY when the watcher is unavailable. Check these facts directly, because `status` does not report watcher
health:

- Not macOS, or `launchctl list | grep borg.resume-watch` shows no job (the label carries an install prefix, so match
  the suffix). A user who opted out of the watcher also has no job, so "absent or not loaded" covers the opt-out.
- The job is listed but looks stuck: a non-zero last-exit status in the `launchctl list` row, or the watcher's stderr
  log (`resume-watch.stderr.log` under the borg log dir) is recent and full of errors.
- `status --json` failed in Step 1.

**Do not use the fallback while `paused` or `disabled_env` is true**, even with no watcher. Those are the operator's
explicit off switches; tell the user which one is on instead of scheduling around it.

1. **Get the two coordinates** from the Workflow launch/failure output: `scriptPath` (the persisted
   `.../workflows/scripts/<name>-wf_....js`) and `runId` (the `wf_...` id). If either is missing, ask rather than guess.
2. **Compute the resume time.** Use the reset in the error ("resets 7:10am America/Denver") plus a few minutes. If
   unknown, use +60 minutes. Get "now" from the environment (`TZ=<zone> date`); never fabricate a timestamp.
3. **Schedule it** with `CronCreate` and `recurring: false`, a cron expression pinned to that time (off the :00/:30
   marks), and this prompt:

   > Usage limit has reset. If the run already finished or was resumed, do nothing. Otherwise resume the paused workflow
   > with no rework:
   > `Workflow({ scriptPath: "<scriptPath>", resumeFromRunId: "<runId>" })`
   > Completed agents return cached; only the unfinished steps re-run. Then carry on where we left off.

4. **Tell the user** the workflow, the `runId` and the exact time it will resume. Do not poll for the reset.

Caveats of this fallback:

- **Lost if the session exits.** The `CronCreate` job lives in this session; closing or killing it (or a reboot) means
  nothing fires.
- **The resume prompt runs on the session model.** The resumed workflow's agents keep their own `model:` pins.
- **`RemoteTrigger` cannot resume a LOCAL workflow.** It starts a fresh cloud session with no plugins or local
  files, so the persisted `scriptPath` and cached run are unreachable.

## How each kind of work is resumed

- **Workflows:** re-run with `resumeFromRunId`; completed `agent()` calls return cached and only unfinished steps
  re-run. If the script itself crashed on a `null` agent result, fix the script first (guard required results and
  return `{ paused: true, at: '<phase>' }`), then resume.
- **Main-loop subagents** (Agent tool): continue them with `SendMessage` to the existing agent.
- Workflow agents are never SendMessaged; they only come back through their workflow's `resumeFromRunId`.
- Container sessions stay notify-only.

## CLI verbs (`borg-resume`, also `borg resume`)

- `borg-resume status [--json] [--all]`: records by state, due time, kill-switch state.
- `borg-resume cancel <rid>` (or `--session <sid>`, or `--all`): stop a record from resuming.
- `borg-resume run <rid> [--force]`: make a record due now and run one watcher pass (the full gate still applies).
- `borg-resume ack <rid>`: the resumed model runs this when done; `borg-resume defer <rid> [<until>]` reschedules it.
- `borg-resume pause` / `borg-resume unpause`: create or remove the `DISABLED` sentinel; nothing injects while paused
  (recording continues).

Kill switches: `borg-resume pause` (the `DISABLED` sentinel) stops injection only; `BORG_RESUME_DISABLE=1` stops
everything, including recording.

## Notes

- Native `autoContinueAtUsageLimit` is left as the user has it; the watcher waits 120s after the reset and skips if
  native already resumed the session.
- Design and decisions: docs/plans/directives/2026-10-12-borg-resume-any-interruption.md
