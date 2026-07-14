# Project Plan: Usage Guardian — Phase 1 (Observe-Only)
*Established: 2026-07-08*
*Shipped: 2026-07-14 — PRs #66/#67/#68/#69/#70/#71/#75 merged to main*

## Objective
Ship a launchd poller (`bin/borg-usage-watch`) that samples Claude Code's rate-limit headroom via
`claude -p "/usage"` and records `(timestamp, session_pct, week_pct, resets_at)` to a structured log — taking **no
action**. This produces the burn-rate dataset needed to defensibly set the checkpoint threshold, and proves the
detection path survives launchd's stripped environment, before any drone-checkpointing behaviour is built.

## Acceptance Criteria

- [x] `bin/borg-usage-watch --once` polls `/usage`, parses `session_pct` / `week_pct` / `resets_at`, and appends one
      JSON sample per poll to `~/.local/state/borg/usage-samples.jsonl`.
  - Verify: `bin/borg-usage-watch --once --debug` then `tail -1 ~/.local/state/borg/usage-samples.jsonl | jq .` shows
    numeric `session_pct` + non-empty `resets_at`.
- [x] **Fail-closed parse.** Empty, non-numeric, or absent `/usage` output yields state `UNKNOWN`: no sample row is
      written, a warning is logged, and the exit code is 0.
  - Verify: `bats tests/usage_watch.bats` — a mock `claude` on `PATH` that prints nothing must produce `UNKNOWN`,
    never `session_pct=0`.
- [x] **Format-drift tripwire.** The parse regex is pinned against a captured fixture, so a Claude Code release that
      reformats the `/usage` line fails the suite loudly instead of silently disarming the guardian.
  - Verify: `tests/fixtures/usage-output.txt` exists and `bats tests/usage_watch.bats` asserts the regex against it.
- [x] **Idle gate.** When no tmux pane is running a `claude` process, the poll is skipped entirely (no CLI spawn, no
      `$0` record appended to `token-spend.jsonl`).
  - Verify: bats test with a stubbed pane-lister returning nothing asserts `claude` is never invoked.
- [x] **launchd-safe environment.** `launchd/com.stillpoint-labs.borg.usage-watch.plist` sets `USER`, `HOME`, and
      `PATH` under `EnvironmentVariables`, and `install.sh` registers the agent via the existing `sed` template +
      `launchctl bootstrap` pattern.
  - Verify: `grep -A2 '<key>USER</key>' launchd/com.stillpoint-labs.borg.usage-watch.plist` and
    `grep USAGE_WATCH_BIN install.sh`. Without `USER`, `/usage` prints nothing and exits 0 — this is the trap the
    spike found.
- [x] **Observe-only.** The guardian takes no action: no `tmux send-keys`, no checkpoint, no dispatch veto.
  - Verify: `grep -c 'send-keys' bin/borg-usage-watch` returns 0.
- [x] (nothing-breaks) The full suite stays green and the new script passes shellcheck.
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

## Additional Work Shipped (beyond the original criteria)

The build hardened well past the observe-only skeleton across a run of follow-up PRs:

- **Never-silent contract (#68).** Criterion 2's original wording said a bad parse writes *no* row. The shipped code
  instead writes an **explicit `parse_failed` / idle / error row on every poll** — silence in the samples log is now
  itself the failure signal. This directly closes the plan's own "a blind guardian is indistinguishable from a
  healthy one" risk. Deliberate strengthening, not a deviation from intent.
- **launchd PATH resolution (#67).** Resolve the native `claude` install from `$HOME/.local/bin` under launchd's
  stripped `PATH`; fail loud (nonzero exit + ERROR row) when the binary is missing, rather than going quietly blind.
- **Spend-log hygiene (#70).** Invoke the internal poll with `BORG_NO_SPEND_RECORD=1` so the poller stops flooding
  `~/.claude/token-spend.jsonl` with `$0` records.
- **Session-hook muting (#75).** Invoke the poll probe with `BORG_NO_SESSION_HOOKS=1` so the internal `/usage`
  session does not fire SessionStart/Stop hooks (which would corrupt registry/presence state).
- **`borg doctor` + install verification (#69).** Added alongside, and it caught two unrelated dead launchd agents
  (notifyd/cortex-wake exiting 127) which were fixed in #71 (`BASH_SOURCE` in a zsh script).

Final verification at assimilation (2026-07-14): `bats tests/usage_watch.bats` 24/24 pass, `bats tests/*.bats`
422/422 pass, `shellcheck bin/borg-usage-watch` + `hooks/*.sh` clean.

## Still Open After This Assimilation (do NOT infer these are done)

- **`docs/plans/directives/2026-07-08-usage-guardian-build.md`** — the larger directive this plan is Phase 1 of.
  Phase 2 (the `>=85%` checkpoint sweep, `>=92%` dispatch hard-stop) is unbuilt, plus its two "Also do" items remain
  undone: `borg-resume`'s disclaimer is still stale ("not predictable from inside a session") and `borg-resume` has
  no source under `skills/` (canonical-source violation).
- **The actual point of Phase 1: collect a week of real burn-rate data** before anyone tunes the 85% threshold.
