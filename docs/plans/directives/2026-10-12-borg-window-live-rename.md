# Directive: Make `borg window <project> <short>` rename the live tmux window

*Filed: 2026-10-12 · Status: Proposed · Owner: Noah*

**tl;dr** — `borg window <project> <short>` writes the new name to the registry and prints "Window name for X -> Y", but the live tmux window keeps its old name, so the registry and tmux disagree until someone runs `tmux rename-window` by hand. The fix is for `cmd_window` to rename the project's live window in the borg session by window id, turn `automatic-rename` off, and say what it did, falling back to registry-only when no window is live. A window is found by its old name, the project name, or its `@project_dir` option, so a rerun also heals a registry that already drifted from tmux.

## Problem

- **Observed 2026-10-12.** `borg window <p> borg-probes` and `borg window <p> borg-door` on two live projects printed success and updated `.projects.<p>.tmux_window` in the registry, but the live windows (ids `@2`, `@3`) kept their old names. The orchestrator ran `tmux rename-window -t @2 ...` and `tmux set-window-option -t @2 automatic-rename off` by hand for each.
- **The command only writes the registry.** `cmd_window` (`borg.zsh:627-639`) validates the project, calls `window-name --set` (`borg.zsh:636`), and prints. `cmd_window_name --set` (`borg_core/registry/cli.py:218-224`) validates and calls `shell.registry_merge`; there is no tmux call anywhere on the path. Compare `cmd_color` (`borg.zsh:614-626`), the sibling setter, which does find the live window (`borg_tmux_find_window`, `borg.zsh:621`) and applies the change to it.
- **Nothing documents registry-only as intended.** `CLAUDE.md:108` says "Show or set a project's short tmux window name (registry `tmux_window`)" and `CLAUDE.md:359-360` says it "reads or sets it". The registry is described as the owner of the name (`drone.zsh:464`), but no text says a rename waits for the next `drone up`. And it would not take effect there anyway: `drone up` finds the live window under either form (`drone.zsh:469`, `_drone_find_window` at `drone.zsh:190-196`) and, if one is live, only attaches to it (`drone.zsh:480-483`). A new name is applied only when the old window is gone. So the current behaviour is an omission, not a design.
- **Consequences of the mismatch, all read from code.** Lookups accept the registry name OR the project name (`CLAUDE.md:359-364`), so a window still named after the project survives a rename. A live window under any third name (an older short name, the case here) does not:
  - `drone up` finds neither form (`drone.zsh:469`), takes the "create" path (`drone.zsh:486`, `drone.zsh:565`), and opens a second window under the new name while the old one keeps running. `drone down` (`drone.zsh:589`) then removes only the new window.
  - `borg switch` / `borg next --switch` resolve to the registry name (`borg.zsh:402-405`) and `borg_tmux_switch` fails with "no tmux window named" (`lib/tmux.zsh:42-45`).
  - `borg color` finds no live window (`borg.zsh:621`) and skips applying the color.
  - The reap overlay sees no live window (`lib/registry.zsh:274-276`, `borg_core/link/core.py:238-245`), so a stale active or waiting project is downgraded to idle although its window is open. `hooks/borg-link-down.sh:303` checks only the registry name, with no project-name fallback.
  - `drone ... --all` (`drone.zsh:661-681`) maps each live window name back to a project with `_drone_project_of`, which falls back to the window name itself when the registry has no match (`drone.zsh:181-186`), so the container cycle gets a wrong project name.
  - `borg down` (`borg.zsh:1158-1166`) runs `drone down` with the live window name; `_drone_resolve` (`drone.zsh:100-138`) cannot map a stale third name to a project, so it fails and `borg down` falls back to a bare `tmux kill-window`, skipping `docker compose down` and post-down hooks. Containers keep running. This is the strongest reason to fix it.
  - `drone restart` / `rebuild` with no argument use the current window name (`drone.zsh:697`) and fail the same way.
  - `_borg_next_log` (`borg.zsh:718-722`) maps the current window to a project by registry name, so telemetry loses the active project.
  - `borg-notifyd` (`bin/borg-notifyd:44`) and `borg link` (`borg_core/link/render.py:538`) show the new registry name, so they quietly disagree with the tab the user sees.
- **`automatic-rename` can undo a rename.** `create_2pane_window` turns it off at creation (`drone.zsh:408`), so drone windows are safe. A window created some other way keeps tmux's default and may be renamed back to the running command. tmux's own `rename-window` normally turns the option off for that window, but the observed manual fix set it explicitly, so the rename path pins it explicitly rather than depend on that.

## Solution

Make `cmd_window` finish the job it reports.

1. **Capture the old name first.** Before `--set`, read the project's current `tmux_window` (`borg_registry_get`) so the live window can still be found by the name it has now.
2. **Find the live window, by id.** After a successful `--set`, if the borg session is alive, list `#{window_id} #{window_name}` for the session (split on the first space only, so names with spaces survive). Pick in this order, first hit wins: (a) a window already named `<short>` (the already-renamed case); (b) a window named the old registry name; (c) a window named the project name (the either-form rule, `lib/tmux.zsh:72-80`, where the short name wins when both are live); (d) a window whose `@project_dir` option equals the project path (`drone.zsh:487`), which finds a window under an unrelated third name, including after the registry already changed. Name matching is literal whole-string (`grep -F -x`). If two windows tie at one tier, rename none and warn, since guessing could rename the wrong window. An old registry value that is null, empty or the string `null` is skipped, so only tiers (a), (c) and (d) apply.
3. **Rename and pin.** `tmux rename-window -t <window_id> <short>` then, on this path only, `tmux set-window-option -t <window_id> automatic-rename off`. Targeting by id avoids any name-resolution ambiguity (tmux resolves a name target by exact, then prefix, then fnmatch) and survives the rename.
4. **Report.** Print the existing registry line, then either `Renamed live tmux window <old> -> <short>` or `No matching live tmux window; registry only`. The wording does not promise a later `drone up` will apply it, because `drone up` reuses a live window.
5. **Registry-only when nothing is live, and idempotent.** No session, or no matching window: do not touch tmux, exit 0. If the live window already carries the new name, make no tmux write call at all and report `already named`. A second identical run changes nothing.
6. **Failure does not undo the registry write.** A tmux error prints a warning and exits 0, since the registry is the source of truth. A rerun converges, because the window is then found by tier (d) `@project_dir` even though the registry already holds the new name. `drone up` does not converge it (Non-Goal 5). If the window carries no `@project_dir`, the warning tells the user to run `tmux rename-window` by hand.

Window-scoped state (`@project_dir`, colors) is set on the window, so it survives the rename. The change lives in `borg.zsh` `cmd_window`; the Python registry command stays pure registry I/O. CLAUDE.md gets one sentence, and the three-statement either-form rule is untouched.

## Non-Goals

- Not changing the either-form lookup rule or any of its three statements (`drone.zsh:190`, `lib/tmux.zsh:72`, `borg_core/link/core.py:238`).
- Not renaming a window on `--derive` or from `drone up`; derivation runs when the window is being created anyway.
- Not touching windows in other tmux sessions, or more than one window per project.
- Not changing validation of the new name (`validate_window_name`).
- Not making `drone up` rename or adopt a window left under a third name; that is a separate change.

## Alternatives Considered

- **A: Keep it registry-only and document that it applies on the next `drone up`.** Rejected: it is not true today. `drone up` reuses a live window (`drone.zsh:480-483`), so the rename never lands, and a window under a third name gets a duplicate instead.
- **B: Have `drone up` rename an existing live window to the registry name.** Closes the gap for drone-managed projects but leaves the setter lying in the meantime, and does nothing for windows not opened by drone. Worth considering later as a self-heal on top of this fix.
- **C: Do the rename in `cmd_window_name` (Python).** One call site for both `borg window` and `drone`'s `--derive`/`--set`. Rejected for now: it drags tmux side effects into the registry module that `borg_core/registry` keeps pure, and `drone`'s own `--set` calls (`drone.zsh:216`) run when the window was just created under that name.
- **E: Resolve the live window by `@project_dir` or pane path instead of by old name.** Accepted, as the last tier of the lookup (step 2d). It is the existing window-to-project mechanism (`drone.zsh:487`, `borg.zsh:1162`) and is what lets a rerun heal a drifted window. Not used alone, because windows not opened by drone lack the option, so the name tiers stay first.
- **F: Store the tmux window id in the registry.** Rejected: ids are per tmux server run and die with the server, so a stored id goes stale on every restart and adds a second source of truth to keep in sync.
- **D: Rename by name (`-t session:old`) instead of id.** Simpler, rejected: a name target is resolved by prefix and fnmatch as well as exact match, and two windows can share a name.

## Acceptance criteria

- [ ] A failing repro test exists first, and fails for the right reason.
  - Verify: a bats case in `tests/` (stateful tmux mock like `tests/drone_wname.bats`) with a live window under the old name runs `borg window <p> <short>` and asserts the live window now has the new name. On `main` it fails because no `rename-window` call is made while the registry changed.
- [ ] The live window is renamed by id and pinned.
  - Verify: the mock trace shows `rename-window -t @<id>` and `set-window-option -t @<id> automatic-rename off`, never a name target; a window found under the project name (not the old short name) is renamed too.
- [ ] No live window means registry only.
  - Verify: cases with no tmux session and with no matching window assert zero `rename-window` calls, registry updated, exit 0, and the "registry only" line printed.
- [ ] Idempotent.
  - Verify: running the same command twice yields one `rename-window` call total and no `set-window-option` on the second run; the second run reports `already named`.
- [ ] Already-drifted state heals.
  - Verify: with the registry already holding `<short>` and a live window under a third name carrying `@project_dir`, `borg window <p> <short>` renames that window by id. A window with the third name and no `@project_dir` is left alone with a manual-rename warning.
- [ ] Lookup precedence and edge cases are pinned.
  - Verify: cases for old name and project name both live (the old-name window is renamed per tier order), two windows tied at a tier (none renamed, warning), old registry value null or empty (no error, falls to tiers a/c/d), and a window name containing a space. The stateful mock is extended to honor `-F` and emit `#{window_id}`.
- [ ] Existing `borg window` contract cases cannot touch real tmux.
  - Verify: the cases at `tests/cli_contract.bats:4344-4390` get a tmux mock (as `color` does, `cli_contract.bats:705-709`) with a trace assertion that no `rename-window` call is made.
- [ ] A tmux failure keeps the registry write.
  - Verify: a mock whose `rename-window` fails leaves `tmux_window` updated, prints a warning, exits 0.
- [ ] Output says what happened and the docs match.
  - Verify: the success case asserts the `Renamed live tmux window` line; `CLAUDE.md` `borg window` text mentions the live rename; `make lint && make test && make test-bats` pass with no regression, including the exact command-count assertion in `tests/cli_contract.bats` (no command is added).
