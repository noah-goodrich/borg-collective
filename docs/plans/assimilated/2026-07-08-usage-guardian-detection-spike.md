# Project Plan: Usage-Guardian — Detection Feasibility Spike
*Established: 2026-07-08*

## Objective
Determine whether Claude Code exposes a trustworthy, low-cost, real-time signal of remaining usage in
the current rate-limit window — enough to checkpoint drones *before* the cap — and deliver a go/no-go
recommendation. If go: specify the detection approach and threshold. If no-go: document why, and the
reactive (limit-event) fallback becomes the design. Resume engine is pre-locked: local launchd
(cortex-wake pattern).

## Acceptance Criteria
- [ ] `/usage` parseability probed — is there any non-interactive/programmatic path to "% used" +
      "resets at"?
  - Verify: findings-doc section documents the attempt + a working PoC command, or a documented
    dead-end with the reason.
- [ ] token-spend live-estimate evaluated against a known cap; accuracy / error bounds characterized.
  - Verify: doc section shows the estimate math and identifies where it breaks down.
- [ ] Filesystem / API / env sweep for undocumented usage or limit sources completed.
  - Verify: doc enumerates exactly what was checked (paths, endpoints, env vars) and each result.
- [ ] Prior art documented — the `borg-resume` skill and the `cortex-wake` launchd pattern, and how
      each informs the resume half of the eventual feature.
  - Verify: doc section references both with file paths and the reuse takeaway.
- [ ] Go/no-go recommendation with a chosen detection strategy (predictive vs reactive) and, if go,
      the concrete signal + threshold.
  - Verify: an explicit `VERDICT: GO` / `VERDICT: NO-GO` line in the doc.
- [ ] (nothing-breaks) No changes to shipped borg skills or hooks — spike is read/doc only.
  - Verify: `git status` in `~/dev/borg-collective` shows only the new findings doc (+ this plan).

## Scope Boundaries
- NOT building: the guardian hook / launchd job this session (spike only).
- NOT building: resume automation (engine decided = launchd; deferred to the build directive).
- NOT building: any change to the claude-plugins publishable subset (nothing to promote yet).
- If done early: ship the doc + file the build directive — do not start building.

## Ship Definition
Findings + recommendation doc committed to `~/dev/borg-collective` on branch
`feat/usage-guardian-detection-spike` → PR opened → CI passes → merged · go/no-go stated in the doc ·
if GO, a follow-up build directive filed under `docs/plans/directives/`.

## Timeline
Target: this session (~1-2 hours). Mostly probing + writing; no feature code.

## Risks
- `/usage` may be interactive-only (no scrape without a PTY hack) → predictive path dies, fall to reactive.
- Self-estimation may be unfalsifiable without Anthropic's exact window math → false-confidence trap.
- Even a "go" signal could be fragile across Claude Code updates (TUI format drift) → maintenance tax.
