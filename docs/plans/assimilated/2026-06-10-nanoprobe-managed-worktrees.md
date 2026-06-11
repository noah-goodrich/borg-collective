# Directive: Nanoprobe-Managed Git Worktrees (#42)

**Filed:** 2026-06-10
**Issue:** #42
**Status:** done
**Shipped:** 2026-06-11

## Background

The original `isolation: worktree` harness flag caused hard failures when the orchestrator CWD
(`~/dev`) is not a git repo. A WorktreeCreate hook cannot route concurrent spawns to different
repos because the hook payload carries only the orchestrator `session_id` and CWD — no target
repo. Decision is locked: worktrees are nanoprobe-managed, not harness-managed.

## Objectives

1. Nanoprobes create their own worktree in the target repo from their brief.
2. Standard worktree location: `/Users/noah/.local/state/borg/worktrees/<repo>/<slug>`
3. On completion the nanoprobe removes its worktree so repos stay clean.
4. `borg reap-worktrees` cleans up stale borg-managed worktrees (merged branch or age threshold).
5. The orchestrator prompt in `borg init` no longer references `isolation: worktree`.
6. All 2 pre-existing stale worktrees under `.claude/worktrees/` are removed.

## Acceptance Criteria

- [x] `agents/borg-nanoprobe.md` updated with worktree lifecycle instructions
- [x] Worktree path standard documented: `/Users/noah/.local/state/borg/worktrees/<repo>/<slug>`
- [x] `lib/reaper.sh` extended with `_borg_worktree_is_stale` and `_borg_reap_worktrees`
- [x] `borg reap-worktrees` subcommand added to `borg.zsh` and help text
- [x] Bats tests added under `tests/` covering the worktree reaper
- [x] `CLAUDE.md` nanoprobe section updated to describe managed-worktree lifecycle
- [x] `borg init` prompt no longer mentions `isolation: worktree`
- [x] Both stale `.claude/worktrees/` entries removed and `worktree prune` run
- [x] `bats tests/` passes (all suites green)
- [x] `shellcheck` clean on changed shell files
