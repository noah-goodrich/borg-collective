# Directive: Container Notification Bridge
*Established: 2026-04-20*

## Objective

Close the notification blackhole for container-based Claude Code sessions by adding a host-side
launchd daemon that watches `~/.config/borg/registry.json` and fires `terminal-notifier` whenever
any project transitions into `status=waiting`, so parallel container work surfaces the same macOS
popup + tmux-bell experience the host orchestrator already gets.

## Context

Container-based Claude sessions (e.g. `ingle`, `reveal` running inside their devcontainers) cannot
fire macOS notifications directly. The existing `notify.sh` hook calls `terminal-notifier`, a
macOS-only binary that does not exist inside Linux containers — invocation fails silently (`|| true`
swallows), and no popup or tmux bell reaches the host. Parallel work stalls without the developer
knowing.

The `borg-notify.sh` hook already writes `status=waiting` to the host-visible registry
(`~/.config/borg/registry.json`) via the bind-mounted `~/.claude/` directory. The gap is a
host-side *consumer* of those state transitions. This directive adds one.

## Acceptance Criteria

- [ ] **Container-origin `waiting` transition fires a host popup.** From inside the ingle or reveal
      devcontainer, triggering Claude to request input causes a `terminal-notifier` popup on the
      host within 2 seconds.
  - Verify: from inside `reveal-reveal-app-1`, run a Claude Code session and ask it for permission;
    observe popup on host naming `reveal`.

- [ ] **Host-origin notifications unchanged.** Orchestrator `borg` session still notifies via
      existing `notify.sh` path — no double-fire, no regression.
  - Verify: in orchestrator tmux pane, let a turn end; exactly one popup appears (not two).

- [ ] **Daemon is managed by launchd, not `borg init`.** `launchctl list | grep borg.notifyd` shows
      a running agent; killing it respawns.
  - Verify: `launchctl print gui/$UID/com.stillpoint-labs.borg.notifyd` shows `state = running`;
    `pkill -f notifyd` → re-check shows a new PID.

- [ ] **`notify.sh` no-ops inside containers.** `[[ -f /.dockerenv ]] && exit 0` guard prevents
      `command not found` swallow-failures.
  - Verify: `docker exec reveal-reveal-app-1 bash /home/dev/.claude/hooks/notify.sh <<<'{"cwd":"/workspace"}'`
    returns 0 silently, no stderr.

- [ ] **Only *transitions* fire, not every write.** Repeated `waiting` writes from a stuck session
      produce at most one popup per transition.
  - Verify: `jq '.projects.ingle.status = "waiting"'` twice in a row on the registry produces
    exactly one popup.

- [ ] **Clicking the popup focuses the right tmux window.** Same `notify-focus.sh` handoff as
      host-side.
  - Verify: click the ingle popup → Ghostty activates → tmux window `ingle` is focused.

- [ ] **Regression guard: `install.sh` is idempotent.** Re-running `./install.sh` after the daemon
      is already installed does not error, does not duplicate the launchd agent.
  - Verify: `./install.sh && ./install.sh && launchctl list | grep -c notifyd` returns `1`.

## Scope Boundaries

- **NOT** fixing the stale `status: idle` + non-null `waiting_reason` + `last_activity: null`
  inconsistency observed on ingle/reveal. File a separate directive. If trivially fixed in
  passing, fine; don't chase it.
- **NOT** changing `borg-notify.sh` logic. It writes the registry; that's its job.
- **NOT** adding a Linux/Windows notification path. macOS only — matches the rest of borg.
- **NOT** building a notification history/log UI. Log file for debugging only.
- **NOT** handling the turn-end (Stop hook) notification from inside containers in this directive.
  If the daemon pattern works for permission-waiting, turn-end can be added trivially later but
  isn't in scope now.
- **If done early:** write a `borg notifyd status` subcommand that prints current daemon state +
  last-fired notification. Do not expand scope.

## Ship Definition

- Daemon script committed at `bin/borg-notifyd` (zsh).
- LaunchAgent plist committed at `launchd/com.stillpoint-labs.borg.notifyd.plist`.
- `install.sh` installs the plist to `~/Library/LaunchAgents/` and bootstraps the agent.
- `hooks/notify.sh` has the `/.dockerenv` guard.
- Manual smoke test (criteria 1, 2, 6) passes.
- Committed to main, borg version bumped (v0.7.3), CHANGELOG/release notes updated.

## Timeline

Target: 1 focused session, ~2-3 hours.

Daemon is ~40 lines of zsh + a launchd plist template; the real work is the smoke-test loop
(edit daemon → `launchctl bootout/bootstrap` → trigger from container → observe). No new
dependencies — `fswatch` is already available via Homebrew; add a presence check in `install.sh`.

## Risks

1. **fswatch cadence on bind-mounted files.** The registry is on host APFS (not a bind mount), so
   no grpcfuse weirdness — but if we ever relocate it inside a container volume, the notification
   path breaks silently. Mitigation: daemon logs `watching $BORG_REGISTRY` at startup; smoke test
   asserts it sees a `touch` on the file.

2. **Launchd throttling.** If the daemon crashes repeatedly (bad jq parse, missing `fswatch`),
   launchd will throttle respawns to a 10s minimum. Must add safe startup: validate deps + file
   exists before entering the watch loop; exit 0 (not crash) on transient parse errors.

3. **Transition-only logic requires state.** "Did we already fire for this `waiting`?" means the
   daemon has to remember per-project status across events. In-memory associative array works but
   is lost on respawn — acceptable; worst case is one duplicate popup after a daemon restart.

## Key Files

```
bin/borg-notifyd                                       ← create: host daemon (fswatch loop)
launchd/com.stillpoint-labs.borg.notifyd.plist         ← create: LaunchAgent template
hooks/notify.sh                                        ← edit: add /.dockerenv guard
install.sh                                             ← edit: install plist + bootstrap agent
hooks/borg-notify.sh                                   ← unchanged (registry write logic is correct)
```
