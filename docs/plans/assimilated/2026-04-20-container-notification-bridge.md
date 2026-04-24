# Directive: Container Notification Bridge
*Established: 2026-04-20*
*Shipped: 2026-04-23 — v0.7.6 (scope expanded mid-flight to swap the notifier itself)*

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

- [x] **Container-origin `waiting` transition fires a host popup.** From inside the ingle or reveal
      devcontainer, triggering Claude to request input causes a `terminal-notifier` popup on the
      host within 2 seconds.
  - Verify: from inside `reveal-reveal-app-1`, run a Claude Code session and ask it for permission;
    observe popup on host naming `reveal`.
  - *Shipped evidence: `notifyd.log` shows `notify reveal (window=reveal)` entries; post-osa-swap
    smoke test with container-origin jq injection on `cairn` rendered a visible popup.*

- [x] **Host-origin notifications unchanged.** Orchestrator `borg` session still notifies via
      existing `notify.sh` path — no double-fire, no regression.
  - Verify: in orchestrator tmux pane, let a turn end; exactly one popup appears (not two).
  - *Shipped evidence: commit `2b96d82` added a `notify_origin` tag to registry writes;
    `bin/borg-notifyd` suppresses host-origin transitions. Smoke-tested: jq injection with
    `notify_origin=host` produces no daemon log entry.*

- [x] **Daemon is managed by launchd, not `borg init`.** `launchctl list | grep borg.notifyd` shows
      a running agent; killing it respawns.
  - Verify: `launchctl print gui/$UID/com.stillpoint-labs.borg.notifyd` shows `state = running`;
    `pkill -f notifyd` → re-check shows a new PID.
  - *Shipped evidence: this session killed PID 98594; launchd respawned as 15947.*

- [x] **`notify.sh` no-ops inside containers.** `[[ -f /.dockerenv ]] && exit 0` guard prevents
      `command not found` swallow-failures.
  - Verify: `docker exec reveal-reveal-app-1 bash /home/dev/.claude/hooks/notify.sh <<<'{"cwd":"/workspace"}'`
    returns 0 silently, no stderr.
  - *Shipped: `hooks/notify.sh:7`.*

- [x] **Only *transitions* fire, not every write.** Repeated `waiting` writes from a stuck session
      produce at most one popup per transition.
  - Verify: `jq '.projects.ingle.status = "waiting"'` twice in a row on the registry produces
    exactly one popup.
  - *Shipped: `bin/borg-notifyd` `check()` tracks `last_status[$project]` and gates on
    `prev != "waiting"`.*

- [~] **Clicking the popup focuses the right tmux window.** Same `notify-focus.sh` handoff as
      host-side.
  - Verify: click the ingle popup → Ghostty activates → tmux window `ingle` is focused.
  - **REGRESSED on 2026-04-23 when the notifier was swapped from `terminal-notifier` to
    `osascript display notification`.** AppleScript's `display notification` has no click-action
    API, so clicking the popup no longer runs `notify-focus.sh`. Mitigation shipped: the tmux
    visual bell in `hooks/notify.sh` still highlights the target window, and the existing
    `Ctrl+Space >` hotkey (runs `borg next --switch`) jumps to the most pressing project in one
    keystroke. Follow-up candidate: restore click-to-focus via the Shortcuts CLI (signed by
    Apple, supports tap actions) or a small notarizable Swift helper.

- [x] **Regression guard: `install.sh` is idempotent.** Re-running `./install.sh` after the daemon
      is already installed does not error, does not duplicate the launchd agent.
  - Verify: `./install.sh && ./install.sh && launchctl list | grep -c notifyd` returns `1`.
  - *Shipped: `install.sh` does `launchctl bootout || true` then `launchctl bootstrap`; plist
    regenerated via `sed > PLIST_DEST` on each run.*

- [x] **Notifications actually render on screen.** *(Added mid-directive on 2026-04-23 when
      diagnosis revealed `terminal-notifier` had been silently dropped by macOS 26 Notification
      Center for both host- and container-origin turns — the original directive assumed host
      delivery already worked.)* Both host- and container-origin `waiting` transitions produce
      a visible notification banner.
  - Verify: a host Claude turn produces exactly one popup; a container-origin transition
    produces exactly one popup; neither is silently dropped.
  - *Shipped evidence: after `terminal-notifier` → `osascript` swap (commit `9fccf0a`), Noah
    visually confirmed "I'm seeing notifications again."*

## Scope Boundaries

- **NOT** fixing the stale `status: idle` + non-null `waiting_reason` + `last_activity: null`
  inconsistency observed on ingle/reveal. File a separate directive. If trivially fixed in
  passing, fine; don't chase it.
- **NOT** changing `borg-notify.sh` logic. It writes the registry; that's its job.
  *(Amended on 2026-04-23: `borg-notify.sh` gained a `notify_origin` tag to support the
  host double-fire suppression added in this directive. Strictly in service of criterion 2,
  not a scope expansion.)*
- **NOT** adding a Linux/Windows notification path. macOS only — matches the rest of borg.
- **NOT** building a notification history/log UI. Log file for debugging only.
- **NOT** handling the turn-end (Stop hook) notification from inside containers in this directive.
  If the daemon pattern works for permission-waiting, turn-end can be added trivially later but
  isn't in scope now.
- **If done early:** write a `borg notifyd status` subcommand that prints current daemon state +
  last-fired notification. Do not expand scope.
  *(Not done; deferred.)*

## Ship Definition

- Daemon script committed at `bin/borg-notifyd` (zsh).
- LaunchAgent plist committed at `launchd/com.stillpoint-labs.borg.notifyd.plist`.
- `install.sh` installs the plist to `~/Library/LaunchAgents/` and bootstraps the agent.
- `hooks/notify.sh` has the `/.dockerenv` guard.
- Manual smoke test (criteria 1, 2, 6) passes.
  *(Shipped: criteria 1 and 2 smoke-tested; criterion 6 regressed — see amended status above.)*
- Committed to main, borg version bumped (v0.7.3), CHANGELOG/release notes updated.
  *(Shipped as v0.7.6 — original v0.7.3 target was superseded by intervening releases. No
  CHANGELOG.md exists in the repo; release notes live in the GitHub release auto-generated by
  the release workflow: https://github.com/noah-goodrich/borg-collective/releases/tag/v0.7.6)*

## Timeline

Target: 1 focused session, ~2-3 hours.

Daemon is ~40 lines of zsh + a launchd plist template; the real work is the smoke-test loop
(edit daemon → `launchctl bootout/bootstrap` → trigger from container → observe). No new
dependencies — `fswatch` is already available via Homebrew; add a presence check in `install.sh`.

*Actual: landed across two sessions — initial daemon on 2026-04-20, closure on 2026-04-23 when
the host double-fire and the underlying terminal-notifier breakage were addressed together.*

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

4. **(Identified in flight) Unmaintained notifier binary.** `terminal-notifier` 2.0.0 is ad-hoc
   signed with no TeamIdentifier and has been unmaintained upstream since 2018. On macOS 26
   (Darwin 25), Notification Center silently drops its posts. This surfaced as "daemon log says
   fired, user saw nothing." Resolved by swapping to `osascript display notification`, which
   posts via Apple-signed System Events. Follow-up if click-to-focus is needed: Shortcuts CLI
   or a notarizable Swift helper.

## Key Files

```
bin/borg-notifyd                                       ← create: host daemon (fswatch loop)
launchd/com.stillpoint-labs.borg.notifyd.plist         ← create: LaunchAgent template
hooks/notify.sh                                        ← edit: add /.dockerenv guard
install.sh                                             ← edit: install plist + bootstrap agent
hooks/borg-notify.sh                                   ← unchanged (registry write logic is correct)
```

*Actual shipped files expanded during closure session (2026-04-23):*
```
lib/borg-hooks.sh        ← new helpers: _borg_is_container, _borg_osa_notify
hooks/borg-notify.sh     ← added notify_origin tag for host double-fire suppression
bin/borg-notifyd         ← reads notify_origin; only fires for container-origin; uses osa helper
hooks/notify.sh          ← swapped terminal-notifier call for _borg_osa_notify
```

## Additional Work Shipped

Work outside the original directive scope that rode along because it was entangled with the
closure or cleared the path to green CI:

- **`9f4670e` — `refactor(briefing): use heredoc for morning briefing prompt`.** Converted the
  escape-heavy double-quoted `briefing_prompt` string in `cmd_init` to a
  `read -r -d '' ... <<EOF` heredoc so nested quotes (like `"Next Session"`) no longer need
  backslash escaping.

- **`9fccf0a` — `fix(notify): swap terminal-notifier for osascript`.** Addresses the underlying
  notification blackhole on the host side (see amended criterion 6 and new criterion 8).
  Introduces `_borg_osa_notify` in `lib/borg-hooks.sh`.

- **`3b60cac` — `refactor(notify): tighten _borg_osa_notify after simplify pass`.** Param-expansion
  instead of sed subshells for AppleScript escaping, dropped dead `${1:-Claude Code}` default,
  shortened daemon missing-lib error to match existing style.

- **`9ea93fa` — `chore(lint): drop unreachable head|tail from bash-guard RO case`.** Removed
  duplicate RO-case entries (SC2221/SC2222) and annotated intentional single-quoted grep regex
  literals (SC2016) in `hooks/bash-guard.sh`. CI lint job had been failing on these pre-existing
  warnings across v0.7.3–0.7.5 ships; green again from v0.7.6 forward.
