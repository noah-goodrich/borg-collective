# Directive: Build the Usage Guardian

*Filed: 2026-07-08 · Status: OPEN (Phase 1 shipped; Phase 2 pending data) · Gated by: nothing (spike returned GO)*
*Source: `docs/research/2026-07-08-usage-guardian-detection-spike.md`*

> ## Data-readiness note — 2026-07-14 (before tuning any threshold, read this)
>
> Phase 1 (the observe-only poller) shipped and has run since Jul 9. A review of
> `~/.local/state/borg/usage-samples.jsonl` (3080 rows, ~6 days) found the data **not yet
> sufficient to tune the 85% checkpoint threshold**, but clarified what is and isn't a blocker:
>
> - **Only ONE near-cap episode exists.** All 15 samples ≥85% are from Jul 9; every other day has
>   zero. This is still the single-observation trap the Risks section names — do NOT tune on it.
> - **Burn accelerates near the cap.** That one trajectory climbed ~1%/min in the 85→93 band —
>   roughly **4× the ~1%/4min** the spike assumed. An 85% trigger gives *less* lead time than the
>   directive imagined; factor this in when Phase 2 sets the sweep threshold + timing.
> - **Detection near the cap is reliable — the error rate was a red herring.** ~19% of rows were
>   `parse_failed`, but 582/591 were the benign 0%-idle variant (a bare `Current session: 0% used`
>   with no reset clause). That parser bug is **fixed** (PR #80, `bin/borg-usage-watch`), with a
>   fixture + regression test. **No near-cap sample was ever lost** — high-burn windows always
>   carry the reset clause and parsed fine. So the guardian is trustworthy at the dangerous end.
>
> **Net:** the remaining Phase-2 blocker is simply *collecting more near-cap episodes* (time +
> heavy multi-agent sessions), not a code or reliability problem. Let the (now-cleaner) log fill
> before tuning. The delivery-spike half of Phase 2 (can `tmux send-keys` reach a busy pane?) is
> data-independent and can proceed anytime.

## Why

Long multi-agent sessions hit the 5-hour rate limit mid-flight and drones die without a checkpoint. The detection
spike established that a free, server-authoritative headroom signal exists (`claude -p "/usage"`), so the cap is
**predictable** and the loss is **preventable**. `borg-resume` already handles recovery; this directive builds the
prevention half.

## What to build

A launchd-driven poller that checkpoints active drones before the session window is exhausted.

1. **`bin/borg-usage-watch`** — clone the structure of `bin/borg-cortex-watch` (`--once`, exit 0, atomic state).
   - Poll `claude -p "/usage"`; parse `session_pct`, `week_pct`, and the reset timestamp.
   - **Fail closed:** an empty or non-numeric parse is `UNKNOWN` → take no action, log it, alert after 3 consecutive.
     Never coerce a missing value to `0`.
   - State: `~/.config/borg/usage-guardian.json`, written tmp+`mv`. Record last poll, last pct, and whether the
     checkpoint sweep for the current window has already fired (idempotence — sweep **once per window**, keyed on the
     reset timestamp).
   - Log: append-only, `/var/log/borg/usage-guardian.log`.

2. **`launchd/com.stillpoint-labs.borg.usage-watch.plist`**
   - `StartInterval` 120; drop to 60 when `session_pct >= 70` (either two plists, or have the script early-return on a
     self-managed cadence — prefer the latter, one plist).
   - **`EnvironmentVariables` MUST set `USER`** (plus `HOME`, `PATH`). Without `USER`, `/usage` silently prints nothing
     and exits 0 — the guardian goes blind with no error. This is the #1 trap; assert it in a test.
   - Register in `install.sh` alongside the existing agents.

3. **Actions**
   - `session_pct >= 85` → checkpoint every active drone via the proven launchd→tmux path
     (`tmux send-keys` `/borg-link-up`), the same delivery mechanism `borg-cortex-watch` uses.
   - `session_pct >= 92` → hard-stop new nanoprobe/workflow dispatch.
   - `week_pct >= 90` → warn only. Do not sweep; a checkpoint does not help a 7-day window.
   - Thresholds env-tunable as `BORG_USAGE_CHECKPOINT_PCT` / `BORG_USAGE_HALT_PCT`, following the
     `BORG_REAP_STALE_HOURS` convention.
   - Adopt `lib/reaper.sh`'s safety stance: if a drone cannot be checkpointed cleanly, **log and leave it alone**.

4. **Tests (`bats`)**
   - Regex asserted against a captured `/usage` fixture, so a Claude Code reformat fails the suite loudly rather than
     silently disarming the guardian. This is the standing defence against TUI format drift.
   - Fail-closed behaviour: empty input ⇒ `UNKNOWN`, not `0`.
   - Idempotence: two polls above threshold in one window ⇒ exactly one sweep.
   - The plist carries `USER`.

5. **Instrumentation before tuning**
   - Log `(timestamp, session_pct)` on every poll. The 85% threshold rests on a *single* burn-rate observation
     (~1% / 4 min). Collect a week of real data before anyone moves it.

## Also do

- **Fix `borg-resume`'s premise.** `~/.claude/skills/borg-resume/SKILL.md` asserts the limit "is not predictable from
  inside a session." That is now false — a subprocess reads it for free. Update the disclaimer and point at the
  guardian. Keep the skill otherwise verbatim: its `resumeFromRunId` recovery is correct and remains the backstop for a
  limit hit between polls.
- **Reconcile skill ownership.** `borg-resume` is installed at `~/.claude/skills/borg-resume/` with **no source under
  `borg-collective/skills/`**, violating the canonical-source rule (borg-collective → claude-plugins). Import it.
- **Poll noise.** Each poll appends a `$0` record to `~/.claude/token-spend.jsonl` via the `SessionEnd` hook.
  `--settings '{"hooks":{}}'` does *not* suppress it. Either filter `est_cost_usd > 0` in token-cost analytics, or add
  an env guard the hook honours. Benign; do not let it block the build.

## Do not

- Do not use `--bare` to skip hooks — it forces API-key auth, so `/usage` reports nothing.
- Do not call `/api/oauth/usage` directly. It would mean extracting the OAuth token from the keychain and hand-rolling
  refresh. Shell out to the CLI.
- Do not derive any threshold from `token-spend.jsonl`. It is written at `SessionEnd`, so a running session contributes
  zero — it is structurally blind to the sessions worth protecting.

## Done when

The guardian checkpoints every active drone before a real 5-hour cap, verified once against a live limit approach; the
`bats` suite is green; `install.sh` registers the plist; `borg-resume`'s disclaimer is corrected.
