# Directive: Build the Usage Guardian

*Filed: 2026-07-08 · Status: OPEN (Phase 1 shipped; Phase-2 delivery spike RESOLVED 2026-07-15; sweep now gated only on
threshold-tuning data) · Gated by: nothing (spike returned GO)*
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

> ## Delivery-spike result — 2026-07-15 (RESOLVED: send-keys DOES reach a busy pane)
>
> Ran the by-hand test the prior checkpoints kept deferring: launched a real Claude Code pane
> (v2.1.205) in a throwaway tmux session, drove it to a genuine mid-turn state (long generation,
> `esc to interrupt` showing), and fired the exact delivery the sweep would use. Observed via
> `capture-pane`. The `borg:8` "zombie / probably unreliable" fear is **disproven** — the mechanism
> works, with one non-obvious caveat. Three findings:
>
> 1. **A queued `/`-command executes as a real command.** Typed mid-turn, the message lands in the
>    input box; the TUI shows it inline as a queued message (`❯ /cmd`, box reads "Press up to edit
>    queued messages"). When the current turn ends, it dequeues and runs **through the slash-command
>    pipeline** — proven by an `Unknown command: /spike-probe-BRAVO` response to a deliberately fake
>    command. A real `/borg-link-up` would therefore fire the skill. No corruption, no interrupt,
>    nothing lost.
> 2. **Delivery is deferred-not-immediate — which is correct for a checkpoint.** The sweep does NOT
>    interrupt the in-flight turn; it queues behind it and runs at the *next* turn boundary. That is
>    exactly what you want: `/borg-link-up` should flush state at a clean boundary, not mid-thought.
>    Implication: the guardian must fire *before* the cap with enough headroom for the current turn
>    to finish AND the queued checkpoint turn to run — with burn at ~1%/min near the cap (see the
>    data note above), an 85% trigger is defensible but tight; do not push it later.
> 3. **Bundle text+Enter in ONE `send-keys` is NOT reliable — send Enter SEPARATELY.** A long input
>    sent as `send-keys "<text>" Enter` in one call was treated as a paste: the trailing Enter became
>    a literal newline and did **not** submit. A second, separate `send-keys Enter` submitted/queued
>    it cleanly. (Short strings like cortex-watch's `"wake up!" Enter` likely dodge the paste
>    heuristic, which is why that path has worked — but the sweep must not rely on it.) **Sweep
>    implementation rule:** send the command text, then a separate `Enter` after a short delay
>    (~0.5s). This is strictly safer for any input length.
>
> **Net:** the checkpoint-sweep delivery path is GREEN. Phase 2's remaining blocker is now *only*
> the threshold-tuning data (more near-cap episodes) — no delivery redesign needed. When Phase 2
> builds the sweep, use the separate-Enter form and treat delivery as end-of-turn, not immediate.

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
     **Send the command text and `Enter` as two separate `send-keys` calls** (~0.5s apart), NOT
     bundled — see the 2026-07-15 delivery-spike result above (bundled Enter can land as a literal
     newline on long inputs). Delivery is end-of-turn (queued), not an interrupt — this is correct.
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

- **Fix `borg-resume`'s premise.** ✅ DONE 2026-07-15. The "not predictable from inside a session" disclaimer is
  corrected (intro + Notes) to point at the usage guardian; the `resumeFromRunId` recovery is kept verbatim as the
  between-polls backstop.
- **Reconcile skill ownership.** ✅ DONE 2026-07-15. `borg-resume` imported to `skills/borg-resume/SKILL.md` (canonical
  source); `borg setup` now stamps it `.borg-managed` and `build-plugin.sh` publishes it to the plugin distro.
- **Poll noise.** Each poll appends a `$0` record to `~/.claude/token-spend.jsonl` via the `SessionEnd` hook.
  `--settings '{"hooks":{}}'` does *not* suppress it. Either filter `est_cost_usd > 0` in token-cost analytics, or add
  an env guard the hook honours. Benign; do not let it block the build.

## Do not

- Do not use `--bare` to skip hooks — it forces API-key auth, so `/usage` reports nothing.
- Do not call `/api/oauth/usage` directly. It would mean extracting the OAuth token from the keychain and hand-rolling
  refresh. Shell out to the CLI.
- Do not derive any threshold from `token-spend.jsonl`. It is written at `SessionEnd`, so a running session contributes
  zero — it is structurally blind to the sessions worth protecting.

> ## Sweep-mechanism result — 2026-07-21 (BUILT: default-OFF, threshold-as-config, idempotent)
>
> Phase 2's checkpoint-sweep **mechanism** is built in `bin/borg-usage-watch` (TDD, 12 new bats,
> shellcheck clean). What shipped:
>
> - **Default-OFF master switch** `BORG_USAGE_SWEEP_ENABLED` (default `0`). The guardian stays inert
>   — a threshold breach with the sweep disabled behaves exactly as Phase-1 observe-only (warning +
>   `ok` row, zero tmux writes). The old blanket "no send-keys" test was *replaced* by a behavioural
>   default-OFF test, not deleted.
> - **Threshold is config, not hard-tuned.** `BORG_USAGE_CHECKPOINT_PCT` governs the trigger;
>   default stays 85 and inert. The number is NOT tuned — data-gated per the note above.
> - **Two-step delivery** per the 2026-07-15 spike: command text, then a SEPARATE `Enter` after
>   `BORG_USAGE_SENDKEYS_DELAY` (0.5s). A grep-able source invariant test forbids re-bundling.
> - **Idempotent, once per window.** State at `~/.config/borg/usage-guardian.json` (tmp+rename),
>   keyed on the reset timestamp. A breach with zero panes re-arms rather than consuming the window.
> - **Fail-safe per pane** (reaper stance): one pane's `send-keys` failure is logged and does not
>   abort the others or the poll (exit 0).
> - **Halt (>=92) is signal-only here.** Separate `if` from checkpoint (a 95% session needs both).
>   The dispatch hard-stop VETO remains a separate `PreToolUse`-hook component — still deferred.
>
> **Still deferred (out of this build):** (1) the `>=92` dispatch hard-stop veto hook; (2) live
> end-to-end validation against a real 5-hour cap; (3) actually *arming* the sweep in the plist —
> it ships OFF on purpose until (2) is done and more near-cap episodes accrue.

## Done when

The guardian checkpoints every active drone before a real 5-hour cap, verified once against a live limit approach; the
`bats` suite is green; `install.sh` registers the plist; `borg-resume`'s disclaimer is corrected.

> ## Dispatch-guard result — 2026-07-21 (BUILT: default-OFF, fail-OPEN veto hook)
>
> The `>=92` dispatch hard-stop is built as `hooks/borg-dispatch-guard.sh` — a `PreToolUse` hook
> (matcher `Agent|Workflow`) that DENIES new nanoprobe/workflow dispatch when the guardian's latest
> sample is a fresh ok row at/above the halt threshold (TDD, 18 bats, shellcheck clean):
>
> - **Reads the existing `usage-samples.jsonl` last row** — no poller change, no new state.
> - **Fail-OPEN is the contract.** Every uncertainty exits 0 (allow): disabled, missing/garbage
>   sample, STALE sample (older than `BORG_USAGE_HALT_TTL_SEC`, default 300s — a stopped poller must
>   never freeze dispatch), non-ok row, non-numeric pct, missing `jq`, empty stdin, non-dispatch
>   tool. It denies (exit 2 + reason on stderr) ONLY when armed + fresh + ok + at/above threshold.
> - **Default-OFF** master switch `BORG_USAGE_HALT_ENABLED` (ships inert). Threshold config via
>   `BORG_USAGE_HALT_PCT` (default 92). Tool is `Agent` (confirmed in transcripts), matched with
>   `Workflow`.
> - **Wired** in `scripts/build-plugin.sh` (hooks.json `Agent|Workflow` entry + build-list copy),
>   asserted by a source-parity test so it cannot silently drop. Installs to `~/.claude/hooks` via
>   `borg setup` (glob) and publishes to the plugin distro on build.
>
> **Not done (out of this build):** end-to-end validation that Claude Code actually blocks on the
> hook's exit 2 (bats only asserts the hook emits exit 2 under the right state); and arming it.
> Both fold into the single live-cap validation step below.

**Progress:** ✅ sweep mechanism built + green (2026-07-21, default-OFF). ✅ `>=92` dispatch-guard
veto hook built + green (2026-07-21, default-OFF, fail-OPEN). ⏳ Remaining: ONE live-cap
verification pass (confirms the sweep delivers AND the guard's exit-2 actually blocks), then arm
both halves once data supports the thresholds.
