# Project Plan: Usage Guardian Phase 2 — Checkpoint-Sweep Mechanism
*Established: 2026-07-21*
*Parent directive: docs/plans/directives/2026-07-08-usage-guardian-build.md*

## Objective
Add the checkpoint-sweep mechanism to `bin/borg-usage-watch`: when enabled, at or above the configured session-%
threshold, deliver `/borg-link-up` to every active Claude pane exactly once per session window — using the proven
separate-Enter delivery — and ship it **default-OFF** so no threshold is hard-tuned before the data exists.

## Acceptance Criteria
- [ ] **1. Default-OFF.** With `BORG_USAGE_SWEEP_ENABLED` unset, a poll at/above threshold behaves exactly as today
      (observe-only warning, an `ok` sample row) and performs **no** `send-keys`.
  - Verify: `bats tests/usage_watch.bats` — new test drives session_pct=90 with sweep disabled, asserts the recorded
    send-keys sink is empty and the observe-only WARNING is still logged.
- [ ] **2. Two-step delivery when enabled.** With the sweep enabled and `session_pct >= BORG_USAGE_CHECKPOINT_PCT`,
      each active Claude pane receives `/borg-link-up` as the command text FIRST, then a SEPARATE `Enter` (never
      bundled in one `send-keys` call).
  - Verify: bats test captures send-keys argv; asserts, per pane, an ordered pair — one call ending in the literal
    `/borg-link-up` (no trailing `Enter`), then one call whose only key arg is `Enter`.
- [ ] **3. Idempotence — one sweep per window.** Two polls above threshold within the same window (same `resets_at`)
      fire exactly ONE sweep; a poll with a changed `resets_at` re-arms and fires again.
  - Verify: bats test — two consecutive enabled above-threshold polls → send-keys sink shows one sweep's worth of
    deliveries; a third poll with a new `resets_at` → a second sweep recorded. State persists in
    `$BORG_USAGE_GUARDIAN_STATE`.
- [ ] **4. Threshold is config, not hard-tuned.** `BORG_USAGE_CHECKPOINT_PCT` governs the trigger; default stays 85
      and the sweep stays OFF by default (the number is inert until deliberately enabled).
  - Verify: bats test sets `BORG_USAGE_CHECKPOINT_PCT=50`, enabled, session_pct=60 → sweep fires; a below-threshold
    reading with the same config → no sweep.
- [ ] **5. Fail-safe per pane (reaper stance).** A failing `send-keys` on one pane is logged and does NOT abort the
      sweep of other panes or the poll; the poll still exits 0.
  - Verify: bats test — send-keys mock fails for pane A, succeeds for pane B; assert both attempted, a WARNING logged
    for A, and the process exits 0.
- [ ] **6. Nothing breaks.** Full `usage_watch.bats` suite green (the blanket "no send-keys" test is REPLACED by
      criterion 1's disabled-state test, not merely deleted), and `shellcheck` is clean on the script.
  - Verify: `bats tests/usage_watch.bats && shellcheck bin/borg-usage-watch`.

## Scope Boundaries
- NOT building: the `>=92%` dispatch hard-stop veto. That needs a `PreToolUse` hook reading guardian state — a
  separate component. This build may write a halt *signal* into guardian state, but the enforcing hook is out of scope.
- NOT building: live end-to-end validation against a real 5-hour cap ("verified once against a live limit approach" in
  the directive). That is a real-world validation step for a later session; this session ships the mechanism + bats.
- NOT changing: the Phase-1 poll/parse/sample logic. Detection, fixtures, and the row schema are frozen.
- NOT tuning: the 85% threshold. Data-gated (one near-cap episode). Default stays 85, sweep default-OFF.
- If done early: ship, don't expand. The next thing is the 92% veto hook or live-cap validation — separate plans.

## Ship Definition
PR opened → CI passes (bats + shellcheck, ubuntu + macos) → squash-merged to `main`. Directive updated to mark the
sweep-mechanism half done and note the two remaining deferred pieces (92% veto hook, live-cap validation).

## Timeline
Target: this session. Estimated effort: ~1–2 hours (6 criteria, TDD, one file + its test + a small install.sh/docs
touch).

## Risks
- **Orchestrator self-sweep.** The orchestrator's own pane is a Claude pane; an enabled sweep queues `/borg-link-up`
  into this very session. Default-OFF is the belt; targeting refinement (exclude by CWD == `$BORG_ORCHESTRATOR_ROOT`)
  is a possible follow-up, noted not built.
- **Wedged panes.** `/borg-link-up` only dequeues at a turn boundary; a truly hung drone won't checkpoint. Accepted —
  log-and-leave, consistent with the reaper stance.
- **Mock fidelity.** Mocking `tmux send-keys` risks the "escape hatch hides the real bug" trap the suite was rewritten
  to avoid. Mitigate by asserting the exact argv sequence and keeping a grep-able source invariant for separate-Enter.
