# Project Plan: Usage Guardian — Phase 1 (Observe-Only)
*Established: 2026-07-08*

## Objective
Ship a launchd poller (`bin/borg-usage-watch`) that samples Claude Code's rate-limit headroom via
`claude -p "/usage"` and records `(timestamp, session_pct, week_pct, resets_at)` to a structured log — taking **no
action**. This produces the burn-rate dataset needed to defensibly set the checkpoint threshold, and proves the
detection path survives launchd's stripped environment, before any drone-checkpointing behaviour is built.

## Acceptance Criteria

- [ ] `bin/borg-usage-watch --once` polls `/usage`, parses `session_pct` / `week_pct` / `resets_at`, and appends one
      JSON sample per poll to `~/.local/state/borg/usage-samples.jsonl`.
  - Verify: `bin/borg-usage-watch --once --debug` then `tail -1 ~/.local/state/borg/usage-samples.jsonl | jq .` shows
    numeric `session_pct` + non-empty `resets_at`.
- [ ] **Fail-closed parse.** Empty, non-numeric, or absent `/usage` output yields state `UNKNOWN`: no sample row is
      written, a warning is logged, and the exit code is 0.
  - Verify: `bats tests/usage_watch.bats` — a mock `claude` on `PATH` that prints nothing must produce `UNKNOWN`,
    never `session_pct=0`.
- [ ] **Format-drift tripwire.** The parse regex is pinned against a captured fixture, so a Claude Code release that
      reformats the `/usage` line fails the suite loudly instead of silently disarming the guardian.
  - Verify: `tests/fixtures/usage-output.txt` exists and `bats tests/usage_watch.bats` asserts the regex against it.
- [ ] **Idle gate.** When no tmux pane is running a `claude` process, the poll is skipped entirely (no CLI spawn, no
      `$0` record appended to `token-spend.jsonl`).
  - Verify: bats test with a stubbed pane-lister returning nothing asserts `claude` is never invoked.
- [ ] **launchd-safe environment.** `launchd/com.stillpoint-labs.borg.usage-watch.plist` sets `USER`, `HOME`, and
      `PATH` under `EnvironmentVariables`, and `install.sh` registers the agent via the existing `sed` template +
      `launchctl bootstrap` pattern.
  - Verify: `grep -A2 '<key>USER</key>' launchd/com.stillpoint-labs.borg.usage-watch.plist` and
    `grep USAGE_WATCH_BIN install.sh`. Without `USER`, `/usage` prints nothing and exits 0 — this is the trap the
    spike found.
- [ ] **Observe-only.** The guardian takes no action: no `tmux send-keys`, no checkpoint, no dispatch veto.
  - Verify: `grep -c 'send-keys' bin/borg-usage-watch` returns 0.
- [ ] (nothing-breaks) The full suite stays green and the new script passes shellcheck.
  - Verify: `bats tests/*.bats` all pass; `shellcheck bin/borg-usage-watch`.

## Scope Boundaries
- NOT building: the 85% checkpoint sweep. Its delivery mechanism (`tmux send-keys` into a *busy* pane) is unproven
  and probably unreliable — the `borg:8` zombie is the precedent. Phase 2, gated on a delivery spike.
- NOT building: the `>=92%` dispatch hard-stop. A launchd job cannot veto an in-process `Agent` call; that needs a
  `PreToolUse` hook reading guardian state. Separate component, separate plan.
- NOT building: the `token-spend.jsonl` `$0`-record filter, or the `borg-resume` disclaimer correction and its
  ownership import. Tracked in the build directive; both are independent of this poller.
- If done early: ship, don't expand. The next thing is a *week of data*, not more code.

## Ship Definition
Committed on `feat/usage-guardian-observe` → PR opened → CI passes (bats + shellcheck, ubuntu + macos) → merged.

## Timeline
Target: this session (~1-2 hours). One script, one plist, one `install.sh` block, one bats file. The prior art
(`bin/borg-cortex-watch`) supplies the skeleton verbatim.

## Risks
- **The plist is where this dies.** `com.stillpoint-labs.borg.cortex-wake.plist` sets no `EnvironmentVariables` and
  `borg-cortex-watch:14` hard-resets `PATH`. Cloning that pattern reproduces exactly the silent-blindness bug the
  spike found. The script must also self-heal (`USER="${USER:-$(id -un)}"`), since a plist is easy to get wrong.
- **A blind guardian is indistinguishable from a healthy one.** `/usage` exits 0 while printing nothing. Without the
  `UNKNOWN` state being first-class and logged, a permanently broken poller looks like a quiet, well-behaved one.
- **Threshold false-confidence.** The 85% figure in the directive rests on a *single* burn-rate observation
  (~1%/4 min). This phase exists precisely so nobody hard-codes it on that basis. Do not tune until the log has a
  week in it.
