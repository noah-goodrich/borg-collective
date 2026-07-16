---
name: borg-resume
description: Auto-resume a workflow (or long task) that was paused or killed by a session/usage limit. Use when a Workflow fails or pauses with a "session limit" / "usage limit" / "resets <time>" error — it schedules a one-shot trigger to re-run the workflow with resumeFromRunId after the limit resets, so cached completed agents return instantly and only the unfinished steps re-run. Also use when the user says "resume after reset", "auto-resume the workflow", or "pick it back up when the limit clears".
---

# borg-resume — self-healing resume for limit-paused workflows

Turns an ungraceful "session limit" workflow crash into a **scheduled, no-work-lost resume**. This is graceful
**recovery**, and it is the backstop for a limit hit *between* guardian polls — not the whole story. Prevention is a
separate layer: the **usage guardian** (`bin/borg-usage-watch`) polls `claude -p "/usage"` out-of-band for
server-authoritative headroom and checkpoints active drones before the cap is reached. The headroom is not exposed to
*in-process* hooks or workflows, but a subprocess reads it for free — so the limit **is** predictable from outside the
run, just not from within it. This skill catches only what slips between polls.

## When to fire this

Any time a background Workflow (or long delegated run) comes back **failed or paused with a usage-limit signal** — the
notification says things like `You've hit your session limit`, `usage limit`, or `resets 7:10am America/Denver`. The
completed `agent()` calls are already cached under the run id, so nothing is lost — it just needs to be picked back up.

## What to do

1. **Get the two coordinates** from the Workflow launch/failure output:
   - `scriptPath` — the persisted `.../workflows/scripts/<name>-wf_....js` path (every Workflow invocation prints it).
   - `runId` — the `wf_...` id of the run that hit the limit.
   If either is missing, ask the user rather than guessing.

2. **Compute the resume time.** The limit error states the reset (e.g. "resets 7:10am America/Denver"). Pick a time a few
   minutes AFTER the reset. If it's unknown, default to +60 minutes. Get "now" from the environment if you need to convert
   (`TZ=<zone> date`); never fabricate a timestamp.

3. **Schedule a one-shot resume trigger** that fires into THIS session at the resume time. Use the `create_trigger` tool
   (or `send_later`) with `run_once_at` = the resume time and this prompt:

   > Usage limit has reset — resume the paused workflow with no rework:
   > `Workflow({ scriptPath: "<scriptPath>", resumeFromRunId: "<runId>" })`
   > Completed agents return cached; only the unfinished steps re-run. Then carry on where we left off.

4. **Tell the user**: which workflow, the `runId`, and the exact time it will auto-resume. Do NOT poll for the reset —
   the trigger handles it.

## Notes

- `resumeFromRunId` re-runs only the changed/unfinished `agent()` calls; completed ones are cached, so the resume is cheap
  and loses no work.
- **If the SCRIPT crashed (not the harness)** — e.g. a null-deref like `design.options` because an `agent()` returned
  `null` when the limit hit — fix the script's resilience FIRST, then resume: guard every required downstream result and,
  when one is missing, `return { paused: true, at: '<phase>' }` instead of dereferencing. That way a limit ends the run
  cleanly with the cache intact, rather than a raw crash. This is the workflow-authoring convention that pairs with this
  skill.
- This is graceful **recovery**, and remains the backstop for a limit hit *between* guardian polls. Prevention now exists
  as a separate layer — the usage guardian (`bin/borg-usage-watch`) reads server-authoritative headroom via
  `claude -p "/usage"` in a subprocess and checkpoints active drones before the cap. So the account limit is no longer
  unpredictable from outside the session; this skill catches only what slips through between polls.
