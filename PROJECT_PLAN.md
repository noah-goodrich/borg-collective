# Project Plan: drone pane command
*Established: 2026-08-10*

## Objective
Add `drone pane <top|bottom|left|right>` — a general-purpose command to split the current tmux
window's active pane in the given direction, reusing `cmd_toggle`'s existing devcontainer-exec-aware
pane-creation logic (`drone.zsh:861-878`). Ship it as a Claude Code skill (`/pane <direction>`) too,
so it's directly callable from inside a session.

## Acceptance Criteria
- [ ] `drone pane top|bottom|left|right` splits the active pane in the right direction (`-v -b` /
      `-v` / `-h -b` / `-h`) when run inside a tmux session belonging to a registered project.
  - Verify: manual tmux session, run each of the 4 directions, confirm placement.
- [ ] Devcontainer projects: the new pane execs into the container shell (same as `cmd_toggle`'s
      pane creation); non-devcontainer projects just `cd` into the project dir.
  - Verify: manual check inside a devcontainer project vs. a plain project.
- [ ] Invalid direction or no active tmux session produces a clear error, non-zero exit.
  - Verify: `drone pane sideways` → error; run outside tmux → error.
- [ ] New bats coverage for the direction→flags mapping and error cases (establishes a minimal
      tmux-mocking convention — none exists in this repo's tests yet).
  - Verify: `bats tests/drone_pane.bats`, plus full `bats tests/*.bats` stays green.
- [ ] `skills/pane/SKILL.md` — thin wrapper skill (same pattern as `skills/borg-switch/SKILL.md`)
      that runs `drone pane <direction>` via the Bash tool.
  - Verify: skill file follows the existing frontmatter/instruction pattern; manually invoke
    `/pane right` in a session and confirm it shells out correctly.
- [ ] `drone` help text and `CLAUDE.md`'s command table updated to list the new command.
  - Verify: `drone help` shows `pane`; `CLAUDE.md`'s drone command table has it.

## Scope Boundaries
- NOT building: pane-size/percentage flags, saved layout presets, closing/toggling panes (that's
  `cmd_toggle`'s job), a `borg pane` alias.
- If done early: ship as-is, don't add extras.

## Ship Definition
Committed to main + `bats tests/*.bats` green + manual smoke test in a live tmux session (both
devcontainer and plain project) + help text updated.

## Risks
- No existing tmux-mocking bats convention in this repo — first one to add it, worth getting right
  since future tmux-touching tests will likely copy it.
- `cmd_toggle`'s container-exec block assumes a specific pane layout (`pane_top == 0` for main);
  reusing it for an arbitrary "split the active pane" command means being careful not to inherit
  assumptions that only held for the rigid 2/3-pane toggle layout.
