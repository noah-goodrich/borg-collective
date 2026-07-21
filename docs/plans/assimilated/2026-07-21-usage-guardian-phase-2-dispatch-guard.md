# Project Plan: Usage Guardian Phase 2 — Dispatch Hard-Stop Veto (≥92%)
*Established: 2026-07-21*
*Parent directive: docs/plans/directives/2026-07-08-usage-guardian-build.md*

## Objective
Add the `>=92%` dispatch hard-stop as a `PreToolUse` hook (`hooks/borg-dispatch-guard.sh`, matcher `Agent|Workflow`)
that DENIES new nanoprobe/workflow dispatch when the guardian's latest sample shows `session_pct >= BORG_USAGE_HALT_PCT`
— shipping **default-OFF** and strictly **fail-OPEN** (any uncertainty → allow). Reads the existing
`usage-samples.jsonl`; no poller change.

## Acceptance Criteria
- [ ] **1. Default-OFF.** With `BORG_USAGE_HALT_ENABLED` unset, the hook always allows (exit 0) — even given a fresh
      `session_pct=95` `ok` sample.
  - Verify: `bats tests/dispatch_guard.bats` — fresh 95% row, halt disabled, Agent tool → exit 0.
- [ ] **2. Deny when armed + fresh + over threshold.** Enabled + last sample `status:"ok"` + `session_pct >=`
      `BORG_USAGE_HALT_PCT` + fresh (within TTL) → exit 2 with a stderr reason naming the pct and the reset time.
  - Verify: bats — enabled, fresh 95% row, tool_name `Agent` → exit 2, stderr matches the pct/reset.
- [ ] **3. Fail-OPEN on every uncertainty (safety-critical).** Each of these → exit 0 (allow): stale sample (older
      than `BORG_USAGE_HALT_TTL_SEC`), missing samples file, unparseable/garbage last row, a non-`ok` last row
      (idle/error/suspect), non-numeric `session_pct`, and missing `jq`.
  - Verify: bats — one test per path, each asserts exit 0 with an above-threshold-or-absent value present.
- [ ] **4. Below threshold allows.** Enabled + fresh `ok` row + `session_pct < BORG_USAGE_HALT_PCT` → exit 0.
  - Verify: bats — enabled, fresh 80% row → exit 0.
- [ ] **5. Scope + config.** Only gates `Agent`/`Workflow`; any other `tool_name` (e.g. `Bash`) → exit 0 regardless of
      usage. Threshold is config via `BORG_USAGE_HALT_PCT` (default 92).
  - Verify: bats — fresh 99% row + tool_name `Bash` → exit 0; a `BORG_USAGE_HALT_PCT=50` + fresh 60% `Agent` → exit 2.
- [ ] **6. Wiring + nothing breaks.** `build-plugin.sh` emits a `PreToolUse` entry with matcher `Agent|Workflow` →
      `borg-dispatch-guard.sh`; the hook is executable; `shellcheck` clean; full `dispatch_guard.bats` green.
  - Verify: `bats tests/dispatch_guard.bats && shellcheck hooks/borg-dispatch-guard.sh` + a source-parity test grepping
    `build-plugin.sh` for the `Agent|Workflow` matcher entry.

## Scope Boundaries
- NOT arming it: ships default-OFF (like the sweep). Enabling waits on live-cap validation + data.
- NOT modifying the poller: reads the existing `usage-samples.jsonl` last row; introduces no new state file.
- NOT the live end-to-end validation that Claude Code actually blocks on exit 2 (real-world check, later — bats can
  only assert the hook emits exit 2 under the right state).
- NOT tuning the 92 threshold (data-gated).
- If done early: ship, don't expand. Next is live-cap validation, then arming both halves.

## Ship Definition
PR opened → CI passes (bats + shellcheck, ubuntu + macOS) → squash-merged. Directive updated to mark the veto-hook
half done; borg-verify gate before merge.

## Timeline
Target: this session. Estimated effort: ~1–2 hours (one hook script + its bats + a `build-plugin.sh` wiring edit + a
plugin republish).

## Risks
- **Fail-open correctness is paramount.** A false deny wedges ALL dispatch. Mitigation: default-OFF master switch + TTL
  freshness gate + exhaustive per-path fail-open tests. When in doubt, the hook allows.
- **Tool-name drift.** Dispatch is the `Agent` tool today; if Claude Code renames it (`Task`), the matcher misses and
  the veto silently no-ops (fails OPEN — safe, but ineffective). Mitigation: match `Agent|Workflow`; note as a tripwire
  for the live-validation step.
- **Exit-2 blocking contract.** Depends on Claude Code honoring PreToolUse exit 2 as deny. Mitigation: default-OFF means
  a wrong contract is inert; the live-cap validation step confirms real blocking before arming.
