# Directive: Cortex Auto-Wake
*Established: 2026-05-01*

## Objective

Eliminate the manual `wake up!` typing required after Cortex hits its session allocation cap.
Add a host-side daemon that watches Cortex panes for the rate-limit message, schedules a
wake-up at the reset time, and auto-sends `wake up!` via tmux when the window opens — with a
desktop notification on resume.

## Context

Observed pattern in snowfort's Cortex Code session (left pane, window 2), captured
2026-05-01 via `tmux capture-pane -p -t 2.1 -S -8000`:

1. Cortex emits the cap message and stops accepting requests.
2. The session **does not die** — it just refuses until the window resets.
3. The user types literal `> wake up!`; Cortex resumes mid-task with full prior context.
   No state loss.

### Captured evidence

Three cap-hits in ~8000 lines of scrollback, each followed by manual `wake up!`:

**First cap-hit and resume (mid-ruff workflow):**

```
✓  BASH  cd /Users/noah/dev/snowfort/packages/snowfort-audit &&
        PATH=".venv/bin:$PATH" ruff check --fix te...
  └─ Found 2 errors (2 fixed, 0 remaining).

 × You have reached the maximum number of requests for your
   subscription. Your limit will reset in 5 hours.

> wake up!

✓  BASH  cd /Users/noah/dev/snowfort/packages/snowfort-audit &&
        PATH=".venv/bin:$PATH" make check 2>&1 | t...
```

**Second cap-hit and resume (mid-pytest):**

```
✓  BASH  cd /Users/noah/dev/snowfort/packages/snowfort-audit && python3
        -m pytest tests/unit/test_cortex_g...

 × You have reached the maximum number of requests for your
   subscription. Your limit will reset in 5 hours.

> wake up!

✓  READ  /Users/noah/dev/snowfort/packages/snowfort-audit/docs/directives/PROJECT_PLAN.md
```

**Third cap-hit (pane idle when captured):**

```
✓  BASH  cd /Users/noah/dev/snowfort/packages/snowfort-audit && python3
        -m pytest tests/ -x -q 2>&1 | tail...

 × You have reached the maximum number of requests for your
   subscription. Your limit will reset in 5 hours.
```

### What the evidence tells us

- **Cap message format is consistent.** Pattern-matching on
  `× You have reached the maximum number of requests for your subscription. Your limit
  will reset in N hours.` is reliable. Detector should also accept "N minutes" as a
  defensive variant.
- **`> wake up!` is the literal manual trigger.** Auto-wake daemon needs to send that
  exact string plus Enter via `tmux send-keys`. No magic.
- **Cortex resumes with no state loss.** Post-wake, work continues mid-task with no
  re-priming — the scrollback shows it picking up the same workflows (ruff → `make
  check`; pytest → directive read). **This is the load-bearing detail:** no
  checkpoint-on-approach is needed because there is nothing to checkpoint. The Explore
  agent's initial guess (token-budget tracking, checkpoint-on-approach) was wrong;
  reality is simpler.

What's missing is just the alarm clock. This directive builds it. Generalizes naturally
to any future provider with similar pause-and-resume cap behavior, but is scoped to
Cortex for now.

## Acceptance Criteria

- [ ] **Detector watches all Cortex panes.** A `borg cortex-watch` daemon (via launchd) reads
      tmux pane output for any pane whose `pane_current_command` is `cortex`. Pattern-matches
      `Your limit will reset in N hours` (and `N minutes` if Cortex emits that variant).
  - Verify: trigger a forced rate-limit error in a test cortex pane; daemon log records the
    pane id and computed `reset_at` within 10 seconds.

- [ ] **State file records pending wakes.** `~/.config/borg/cortex-wakes.json` stores
      `{ pane_id, project, reset_at, detected_at }` entries. Atomic writes (tmp + rename).
  - Verify: trigger detection; `jq '.wakes[]' ~/.config/borg/cortex-wakes.json` shows the
    entry; restart the daemon, the file persists, the wake still fires.

- [ ] **Scheduler fires `wake up!` at reset_at.** Within 60 seconds of `reset_at`, a
      `borg cortex-resume <pane_id>` runs: `tmux send-keys -t <pane> "wake up!" Enter`, posts
      a macOS notification (`<project> cortex resumed at HH:MM`), and removes the entry from
      the state file.
  - Verify: with a synthetic entry whose `reset_at` is 90s in the future, observe the resume
    message land in the target pane and the notification appear.

- [ ] **`borg ls` shows pause status.** Projects with a paused Cortex session display
      `⏸ resumes in 2h 14m` (countdown auto-recalculates per render).
  - Verify: with a pending wake on snowfort, `borg ls` shows the pause indicator and a
    plausible countdown.

- [ ] **Idempotent install.** `install.sh` installs the launchd plist, bootstraps the daemon,
      and re-running does not duplicate.
  - Verify: `./install.sh && ./install.sh && launchctl list | grep -c borg.cortex-wake`
    returns `1`.

- [ ] **Edge cases handled.** Already-passed reset (daemon was offline), daemon restart
      mid-pause, cortex pane that closed before reset, multiple simultaneous paused panes.
  - Verify: kill the daemon, advance the clock past a recorded reset, restart the daemon —
    it fires the missed wake within 60 seconds of restart. Close a paused pane — daemon
    drops the orphaned entry on next sweep.

- [ ] **Manual override.** `borg cortex-resume <project>` works as a CLI for the impatient
      developer who wants to wake before the recorded `reset_at`.
  - Verify: with snowfort paused, `borg cortex-resume snowfort` immediately sends `wake up!`
    and clears the state entry.

## Scope Boundaries

- **NOT** building checkpoint-on-approach. Cortex preserves state across the pause; nothing
  to lose. Confirmed by reading the actual scrollback — context survives intact.
- **NOT** building token-budget tracking or proactive throttling. React to the cap message;
  don't predict.
- **NOT** generalizing to Claude Code in this directive. Claude has different cap behavior
  and may need different mechanics. File a follow-up if/when it becomes relevant.
- **NOT** making the daemon remotely manageable. One developer, one Mac.
- **NOT** writing the wake message to a log for analytics. The macOS notification + state
  file pruning is enough.
- **NOT** auto-restarting Cortex if the session itself crashes (different problem).

## Ship Definition

- `bin/borg-cortex-watch` (zsh) — daemon: scans tmux panes, detects rate-limit message,
  records to state file, fires due wakes.
- `launchd/com.stillpoint-labs.borg.cortex-wake.plist` — LaunchAgent template.
- `borg.zsh` — new `cmd_cortex_resume` (also wired into `borg ls` for pause display).
- `install.sh` — installs and bootstraps the agent.
- Manual smoke test on snowfort: trigger a cap hit, observe detection + scheduled wake +
  auto-resume + notification.
- Borg version bump and release.

## Timeline

Target: 1 focused session, ~2-3 hours. The detector loop is ~30 lines of zsh + launchd plist.
The bulk of the work is the smoke-test loop and edge-case handling (especially
already-passed reset on daemon restart).

## Risks

1. **Detection latency.** If the daemon polls panes every N seconds, a cap hit can sit
   unnoticed for up to N. Acceptable trade-off — the wake is hours later anyway. Default to
   30s poll cadence; tune if needed.

2. **Pane-id stability across tmux server restart.** Pane ids change if tmux is restarted.
   State file should also store `(session, window, pane_index)` as a fallback identifier and
   re-resolve if the recorded id is gone.

3. **Cortex message text could change.** The detector is pattern-matched on a string Cortex
   emits. If Cortex updates the message format, detection silently fails. Mitigation: emit
   a daemon log warning if any cortex pane sees output but no rate-limit message has been
   detected for >24h (suggests pattern drift). Low-priority — fix when it breaks.

4. **Wake message arrives mid-typing.** If Noah is typing into the pane when the wake fires,
   the `wake up!` injection could merge with his text. Mitigation: detector only schedules a
   wake if the pane was last writing the cap message; if the user has typed since the cap
   message, assume they handled it manually and drop the entry.

5. **launchd throttling.** Same risk as `borg-notifyd` — bad daemon startup → 10s minimum
   respawn. Same mitigation: validate deps + state file readability before entering the
   poll loop; exit 0 (not crash) on transient errors.

## Key Files

```
bin/borg-cortex-watch                                    ← create: daemon
launchd/com.stillpoint-labs.borg.cortex-wake.plist       ← create: LaunchAgent
borg.zsh                                                 ← edit: cmd_cortex_resume + ls integration
install.sh                                               ← edit: install/bootstrap agent
~/.config/borg/cortex-wakes.json                         ← runtime state (created on first detect)
```

## Related

This directive is one of two outcomes of a longer architectural conversation on 2026-05-01
about managing long-running sessions. The companion directive,
`2026-05-01-directive-orphan-prevention.md`, addresses the *across-session* discontinuity
case (orphaned standing work). This one addresses the *within-session* discontinuity case
(token-cap pause). Both belong in borg's lifecycle surface area.
