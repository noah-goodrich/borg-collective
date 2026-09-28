#!/usr/bin/env sh
# shellcheck shell=bash  # lint as bash: both bash (hooks) and zsh source this file
# lib/reaper.sh — shared reaper predicate for borg hooks and the zsh CLI.
#
# Sourceable from both bash (hooks) and zsh (lib/registry.zsh). Provides:
#   BORG_REAP_STALE_HOURS — staleness threshold in hours (default 12)
#   _borg_should_reap <status> <last_activity_iso> <has_live_window: 1|0>
#   _borg_worktree_is_stale <repo_path> <worktree_path>
#   _borg_reap_worktrees <repo_path>

BORG_REAP_STALE_HOURS="${BORG_REAP_STALE_HOURS:-12}"

# ── Session staleness predicate ───────────────────────────────────────────────

# Predicate: should this project's active/waiting status be reaped to idle?
# Args: <status> <last_activity_iso> <has_live_window: 1|0>
# Returns 0 (reap) when status is active/waiting AND no live window AND
# last_activity is missing or older than BORG_REAP_STALE_HOURS. Returns 1 (keep).
_borg_should_reap() {
    local st="$1" last="$2" live="${3:-0}"
    if [ "$st" != "active" ] && [ "$st" != "waiting" ]; then
        return 1
    fi
    if [ "$live" = "1" ]; then
        return 1
    fi
    local threshold="${BORG_REAP_STALE_HOURS:-12}"
    if [ -z "$last" ] || [ "$last" = "null" ]; then
        return 0
    fi
    local epoch_ts epoch_now age_h
    epoch_ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last" +%s 2>/dev/null \
        || TZ=UTC date -d "$last" +%s 2>/dev/null) || return 0
    epoch_now=$(date +%s)
    age_h=$(( (epoch_now - epoch_ts) / 3600 ))
    [ "$age_h" -ge "$threshold" ]
}

# ── Nanoprobe worktree reaper ─────────────────────────────────────────────────
#
# Borg-managed worktrees live at:
#   ${XDG_STATE_HOME:-$HOME/.local/state}/borg/worktrees/<repo-basename>/<slug>
#
# A worktree is considered stale when its branch has been merged into the repo's
# default branch OR when the worktree directory's mtime is older than
# BORG_REAP_STALE_HOURS. Only worktrees under the borg state dir are ever
# touched — non-borg worktrees are completely ignored.

# DERIVED, NEVER HARDCODED. This default shipped as a literal `/Users/noah/...` on 2026-06-10
# (6501294) and was wrong on the machine it shipped from -- $HOME is /Users/noahgoodrich -- so
# `_borg_reap_worktrees` hit its `[ -d "$wt_base" ] || return 0` guard on every repo and the
# hourly LaunchAgent was a no-op for ~3.5 months while 15 real worktrees accumulated under the
# correct path. Nothing in borg.zsh, install.sh or any hook sets this variable: the only
# assignments in the tree are in tests, which is precisely why the suite stayed green. Same class
# as the BORG_REGISTRY and XDG_CONFIG_HOME entries under Learned in CLAUDE.md -- a test that
# supplies the value the production path is supposed to derive proves nothing about production.
#
# The expression is byte-identical to the one install.sh uses for its usage-watch paths and to
# cmd_doctor's `state_dir` in borg.zsh, so the reaper cannot read a directory `borg doctor` does not
# report on. NAMED, NOT PINNED: `docs/plans/directives/2026-08-31-retire-the-line-pin.md` retires
# `file:NNN` from prose repo-wide, and this comment earned the lesson the hard way -- the first
# draft pinned two line numbers, and review found the same pin resolving to 2496 on this branch and
# 2482 on another, both correct for where they were read. Grep the expression instead.
BORG_WORKTREE_STATE_DIR="${BORG_WORKTREE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/borg/worktrees}"

# Predicate: is this worktree stale?
# Args: <repo_path> <worktree_path>
# Returns 0 (stale) when the branch has been merged into the default branch (i.e.
# the branch has unique commits AND all of them are now reachable from the default
# branch), OR when the worktree directory mtime is older than BORG_REAP_STALE_HOURS.
# Returns 1 (keep) for fresh or unmerged worktrees.
_borg_worktree_is_stale() {
    local repo="$1" wt="$2"
    [ -d "$wt" ] || return 0

    local wt_branch
    wt_branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null) || return 1

    local default_branch
    default_branch=$(git -C "$repo" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
        | sed 's|refs/remotes/origin/||')
    if [ -z "$default_branch" ]; then
        default_branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null) || default_branch="main"
    fi

    local wt_sha default_sha
    wt_sha=$(git -C "$repo" rev-parse "$wt_branch" 2>/dev/null) || true
    default_sha=$(git -C "$repo" rev-parse "$default_branch" 2>/dev/null) || true

    if [ -n "$wt_sha" ] && [ -n "$default_sha" ] && [ "$wt_sha" != "$default_sha" ]; then
        if git -C "$repo" merge-base --is-ancestor "$wt_branch" "$default_branch" 2>/dev/null; then
            return 0
        fi
    fi

    local threshold="${BORG_REAP_STALE_HOURS:-12}"
    local mtime now age_h
    mtime=$(stat -c %Y "$wt" 2>/dev/null || stat -f %m "$wt" 2>/dev/null)
    case "$mtime" in ''|*[!0-9]*) return 1;; esac
    now=$(date +%s)
    age_h=$(( (now - mtime) / 3600 ))
    [ "$age_h" -ge "$threshold" ]
}

# Remove stale borg-managed worktrees for a given repo.
# Args: <repo_path>
# Prints one line per removed worktree to stdout: "<worktree_path>\t<reason>"
# Never touches worktrees outside BORG_WORKTREE_STATE_DIR.
# Never removes a worktree with uncommitted changes (git status --porcelain non-empty).
# Safe to call even when the state dir or repo subdir does not exist.
_borg_reap_worktrees() {
    local repo="$1"
    local repo_name
    repo_name="${repo##*/}"
    local wt_base="${BORG_WORKTREE_STATE_DIR}/${repo_name}"

    [ -d "$wt_base" ] || return 0

    local wt reason
    for wt in "$wt_base"/*/; do
        [ -d "$wt" ] || continue

        if git -C "$wt" status --porcelain 2>/dev/null | grep -q .; then
            continue
        fi

        if _borg_worktree_is_stale "$repo" "$wt"; then
            local wt_branch
            wt_branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

            local default_branch
            default_branch=$(git -C "$repo" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
                | sed 's|refs/remotes/origin/||')
            if [ -z "$default_branch" ]; then
                default_branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null) || default_branch="main"
            fi

            local wt_sha default_sha
            wt_sha=$(git -C "$repo" rev-parse "$wt_branch" 2>/dev/null) || true
            default_sha=$(git -C "$repo" rev-parse "$default_branch" 2>/dev/null) || true

            if [ -n "$wt_sha" ] && [ -n "$default_sha" ] && [ "$wt_sha" != "$default_sha" ] && \
                    git -C "$repo" merge-base --is-ancestor "$wt_branch" "$default_branch" 2>/dev/null; then
                reason="branch merged"
            else
                reason="stale (>${BORG_REAP_STALE_HOURS:-12}h)"
            fi

            if git -C "$repo" worktree remove --force "$wt" 2>/dev/null; then
                printf '%s\t%s\n' "$wt" "$reason"
            fi
        fi
    done

    git -C "$repo" worktree prune 2>/dev/null || true

    if [ -d "$wt_base" ]; then
        set -- "$wt_base"/*/
        [ -e "$1" ] || rmdir "$wt_base" 2>/dev/null || true
    fi
}
