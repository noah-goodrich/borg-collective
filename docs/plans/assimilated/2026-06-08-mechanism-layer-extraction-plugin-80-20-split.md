# Project Plan: Mechanism-Layer Extraction — Plugin is the 80%, CLI is the 20%
*Established: 2026-06-08*
*Shipped: 2026-06-09 — PR #41 merged to main*

## Objective
Establish the mechanism-layer pattern that lets the distributable plugin carry the shareable 80% as a
self-contained unit while `borg`/`drone` demote to a thin personal 20% client — proven end-to-end on the
**reaper slice**: one mechanism home consumed by the CLI + lifecycle hook + skill, the plugin self-contained
(no machine-local reach-ins), and drift made structurally impossible via a single source of truth.

## Context
Two copies of borg-collective exist and are drifting: this repo (`~/dev/borg-collective`, the personal CLI +
stateful hooks + lib, deployed via `install.sh` + `borg setup` to `~/.claude`) and the distributable plugin
(`~/dev/claude-plugins/borg-collective`, skills + stateless hooks, shipped via the noah-local marketplace).
Two concrete violations of the intended 80/20 boundary motivate this work:
1. The plugin's `hooks/notify.sh:9` sources `$HOME/.claude/lib/borg-hooks.sh` — a distributable artifact
   depending on machine-local state. A fresh plugin install (no `borg setup`) gets a broken hook.
2. Skills are hand-copied between the two repos — guaranteed drift (the `borg-link` SKILL.md reaper-predicate
   prose already documents a rule the code has since changed).

The reaper is the proof slice: its predicate is mirrored in three places, it has full test coverage
(`tests/reap.bats`, 222 green), and it touches all three consumer types (CLI, hook, skill).

## Acceptance Criteria
- [x] **One mechanism home.** `_borg_should_reap` + the reap overlay live in exactly one implementation file.
      The zsh CLI **sources** it (function call, no subprocess fork on the display path); the lifecycle hook
      and the `borg-link` skill consume it; `borg-link/SKILL.md` no longer restates the predicate logic.
  - Verify: `grep -rl '_borg_should_reap' lib hooks` returns one implementation file (plus its test);
    `grep -c 'no live window\|BORG_REAP_STALE' skills/borg-link/SKILL.md` shows the prose points at the
    mechanism rather than re-specifying it.
- [x] **Plugin self-contained.** No distributed hook or skill references `$HOME/.claude` or `~/.claude`; all
      paths are `${CLAUDE_PLUGIN_ROOT}`-relative.
  - Verify: `grep -rn 'HOME/.claude\|~/.claude' ~/dev/claude-plugins/borg-collective/` returns nothing.
- [x] **Single source, no hand-copy.** Content duplicated between the source repo and the plugin (skills +
      the shared mechanism) is symlinked or build-generated, not hand-copied.
  - Verify: the sync mechanism (symlink or build script) exists and is documented; `diff -r` of source vs
    distributed copies is identical (or the build regenerates them byte-for-byte).
- [x] **CLI is a client for the slice.** `borg reap` calls the shared mechanism with its inline duplicate
      predicate removed; any skill that acted via the `borg` CLI now invokes a bundled script instead.
  - Verify: `borg reap` manual smoke succeeds; `grep -n 'should_reap' borg.zsh lib/registry.zsh` shows no
    duplicated predicate body.
- [x] **No regressions, fresh-install safe.** Full test suite green and a plugin hook runs without
      `~/.claude/lib` present.
  - Verify: `bats tests/` (≥222 pass, 0 fail); simulate a missing `~/.claude/lib` and confirm the relevant
    plugin hook exits cleanly (no source error).

## Scope Boundaries
- NOT building: migration of other verbs (scan, scoring, search, add/rm) into the mechanism layer — each is a
  follow-on directive parented to this plan once the pattern is proven on reap.
- NOT building: an MCP server for the mechanism. Bundled-script + sourced-lib first; MCP is the documented
  upgrade path for verbs that must compose outside borg or be called as model tools.
- NOT building: merging the two repos, or any change to `drone` / container orchestration (it stays 100% in
  the personal 20%).
- If done early: ship the reaper slice clean; file the next verb as a parented directive, don't expand this
  plan.

## Ship Definition
CLI tool: committed to `main` + `bats tests/` green + manual `borg reap` smoke + fresh-install hook check
(no `~/.claude/lib`) + help text and docs reflect the new mechanism-home layout. No version bump unless the
plugin packaging changes the marketplace manifest.

## Timeline
Target: ~1.5–2 sessions.
Estimated effort: shared mechanism file + keep tests green (~45m), flip the three reaper consumers (~1h),
plugin self-containment fix for the slice (~45m), single-source/build mechanism + docs (~1h).
The slice is small; the care is in sequencing — land the shared file with tests green *before* flipping any
consumer.

## Risks
- **Fork-on-display.** If the CLI invokes the mechanism as a subprocess instead of sourcing it, `borg next` /
  `borg ls` go O(forks) per project on every render. The CLI must source the shared lib; only hooks/skills
  that can't source it may shell out.
- **Symlink vs packaging.** A symlinked single-source may not survive marketplace packaging; if so, this
  forces a small build/generate step rather than a symlink — handle within criterion 3.
- **Behavior drift in next/ls.** Demoting the CLI to a mechanism client risks a subtle status-overlay change
  in `borg next` / `borg ls`; the 222-test net (especially `tests/reap.bats` and `tests/state.bats`) is the
  guard — keep them passing unchanged.
- **The `notify.sh` reach-in fix** may reveal the hook genuinely needs a helper that only the personal install
  provides; if so, the bundled mechanism must carry a self-contained fallback so the plugin works standalone.

## Additional Work Shipped
- `lib/reaper.sh` — new POSIX-compatible single home for `_borg_should_reap` + `BORG_REAP_STALE_HOURS`
- `scripts/sync-plugin.sh` — skill distribution sync script; prevents hand-copy drift going forward
- `tests/reap.bats` — 10 test cases covering `_borg_should_reap` + `borg_reap_overlay`
- `tests/test_helper/setup.bash` — updated to copy `reaper.sh` so hook tests resolve the shared lib
- `hooks/borg-link-up.sh` — captures cairn write stderr (was discarding it); failure log now contains
  timestamp + error message
- `hooks/borg-link-down.sh` — fixed `cairn status` (nonexistent) → `cairn health` in failure nudge
- `skills/borg-link/SKILL.md` — inline predicate prose replaced with pointer to `lib/reaper.sh`
- `docs/plans/directives/2026-06-06-reaper-utc-timezone-offset.md` — filed TZ-offset bug in reaper
