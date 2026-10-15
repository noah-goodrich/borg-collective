#!/usr/bin/env sh
# shellcheck shell=bash  # lint as bash: both bash (hooks) and zsh source this file
# lib/reaper.sh — shared reaper predicate for borg hooks and the zsh CLI.
#
# Sourceable from both bash (hooks) and zsh (lib/registry.zsh). Provides:
#   BORG_REAP_STALE_HOURS — staleness threshold in hours (default 12)
#   _borg_should_reap <status> <last_activity_iso> <has_live_window: 1|0>
#   _borg_worktree_is_stale <repo_path> <worktree_path>
#   _borg_reap_worktrees <repo_path>   (BORG_REAP_DRY_RUN=1: print, remove nothing; BORG_REAP_GH=1: allow gh)

BORG_REAP_STALE_HOURS="${BORG_REAP_STALE_HOURS:-12}"

# ── Session staleness predicate ───────────────────────────────────────────────

# Predicate: should this repository's active/waiting status be reaped to idle?
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
# default branch OR when its last activity (tip commit / index mtime) is older than
# BORG_REAP_STALE_HOURS and it has no unpushed commits. Only worktrees under the borg state dir are ever
# touched — non-borg worktrees are completely ignored.

# DERIVED, NEVER HARDCODED. This default shipped as a literal `/Users/noah/...` on 2026-06-10
# (6501294) and was wrong on the machine it shipped from -- $HOME is /Users/<user> -- so
# `_borg_reap_worktrees` hit its `[ -d "$wt_base" ] || return 0` guard on every repo and the
# hourly LaunchAgent was a no-op for ~3.5 months while 15 real worktrees accumulated under the
# correct path. Nothing in borg.zsh, install.sh or any hook sets this variable: the only
# assignments in the tree are in tests, which is precisely why the suite stayed green. Same class
# as the BORG_REGISTRY and XDG_CONFIG_HOME entries in docs/agents/learned.md and hooks/CLAUDE.md -- a test that
# supplies the value the production path is supposed to derive proves nothing about production.
#
# The expression is byte-identical to the one install.sh uses for its usage-watch paths and to
# cmd_doctor's `state_dir` in borg.zsh, so the reaper cannot read a directory `borg doctor` does not
# report on. NAMED, NOT PINNED: `docs/plans/directives/2026-08-31-retire-the-line-pin.md` retires
# `file:NNN` from prose repo-wide, and this comment earned the lesson the hard way -- the first
# draft pinned two line numbers, and review found the same pin resolving to 2496 on this branch and
# 2482 on another, both correct for where they were read. Grep the expression instead.
BORG_WORKTREE_STATE_DIR="${BORG_WORKTREE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/borg/worktrees}"

# The ref a branch is judged against: refs/remotes/origin/<default> when it resolves (the local default
# branch can lag origin by many commits), else the local default branch. Prints the ref name.
# Args: <repo_path>
_borg_default_ref() {
    local repo="$1" db
    db=$(git -C "$repo" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    if [ -z "$db" ]; then
        db=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null) || db="main"
    fi
    if git -C "$repo" rev-parse --verify -q "refs/remotes/origin/${db}^{commit}" >/dev/null 2>&1; then
        printf 'refs/remotes/origin/%s\n' "$db"
    else
        printf '%s\n' "$db"
    fi
}

# THE "is merged" predicate, shared by the stale check and the reason string so they cannot disagree.
# Args: <repo_path> <branch>
# Returns 0 and prints "ancestor" or "squash" when the branch is merged; returns 1 (prints nothing) otherwise.
#   1. ancestor: the branch tip is reachable from the default ref (merge commits, fast-forwards).
#   2. squash: `git merge-tree --write-tree <default> <branch>` yields exactly the default ref's tree, i.e. the
#      branch adds nothing. This repo squash-merges every PR, so (1) never fires for it. A conflict or a
#      different tree means NOT merged (the safe direction); an old git without --write-tree falls through.
#   3. gh (only when BORG_REAP_GH=1, never from hooks): a merged PR exists for the branch. Any failure = no.
# A branch whose tip equals the default tip is a fresh branch with no work, never "merged".
_borg_branch_merged() {
    local repo="$1" branch="$2" dref br_sha d_sha d_tree m_tree
    dref=$(_borg_default_ref "$repo")
    br_sha=$(git -C "$repo" rev-parse "$branch" 2>/dev/null) || return 1
    d_sha=$(git -C "$repo" rev-parse "$dref" 2>/dev/null) || return 1
    [ -n "$br_sha" ] && [ -n "$d_sha" ] && [ "$br_sha" != "$d_sha" ] || return 1

    if git -C "$repo" merge-base --is-ancestor "$branch" "$dref" 2>/dev/null; then
        printf 'ancestor\n'
        return 0
    fi

    d_tree=$(git -C "$repo" rev-parse "${dref}^{tree}" 2>/dev/null) || d_tree=""
    m_tree=$(git -C "$repo" merge-tree --write-tree "$dref" "$branch" 2>/dev/null | sed -n 1p) || m_tree=""
    if [ -n "$d_tree" ] && [ "$m_tree" = "$d_tree" ]; then
        printf 'squash\n'
        return 0
    fi

    if [ "${BORG_REAP_GH:-}" = "1" ]; then
        local n
        n=$(cd "$repo" 2>/dev/null && gh pr list --state merged --head "$branch" --json number --jq length 2>/dev/null) \
            || n=""
        case "$n" in ''|*[!0-9]*) ;; *) if [ "$n" -ge 1 ]; then printf 'squash\n'; return 0; fi;; esac
    fi
    return 1
}

# Predicate: is this worktree stale?
# Args: <repo_path> <worktree_path>
# Returns 0 (stale) when the branch has been merged into the default branch (i.e.
# the branch has unique commits AND all of them are now reachable from the default
# branch), OR when its last activity (the newer of the branch-tip commit time and the per-worktree
# index mtime) is older than BORG_REAP_STALE_HOURS and the branch has no unpushed commits.
# Returns 1 (keep) for fresh or unmerged worktrees.
_borg_worktree_is_stale() {
    local repo="$1" wt="$2"
    [ -d "$wt" ] || return 0

    local wt_branch
    wt_branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null) || return 1

    if _borg_branch_merged "$repo" "$wt_branch" >/dev/null; then
        return 0
    fi

    local default_branch
    default_branch=$(_borg_default_ref "$repo")

    # Never reap on age while the branch holds work that exists nowhere else: commits not on
    # its upstream, or (no upstream) commits not on the default branch.
    local ahead
    if git -C "$wt" rev-parse --verify -q '@{u}' >/dev/null 2>&1; then
        ahead=$(git -C "$wt" rev-list --count '@{u}..HEAD' 2>/dev/null) || ahead=1
    else
        ahead=$(git -C "$wt" rev-list --count "${default_branch}..HEAD" 2>/dev/null) || ahead=1
    fi
    case "$ahead" in ''|*[!0-9]*) return 1;; esac
    [ "$ahead" -gt 0 ] && return 1

    # Activity = newest of the branch tip's committer time and the per-worktree index mtime.
    # The worktree directory's own mtime is NOT used: it changes only when direct entries are
    # added or removed, so commits and subdirectory edits never touched it.
    local threshold="${BORG_REAP_STALE_HOURS:-12}"
    local ct idx imtime last now age_h
    ct=$(git -C "$wt" log -1 --format=%ct 2>/dev/null)
    case "$ct" in ''|*[!0-9]*) ct=0;; esac
    idx=$(git -C "$wt" rev-parse --git-path index 2>/dev/null)
    case "$idx" in ''|/*) ;; *) idx="$wt/$idx";; esac
    imtime=$(stat -c %Y "$idx" 2>/dev/null || stat -f %m "$idx" 2>/dev/null)
    case "$imtime" in ''|*[!0-9]*) imtime=0;; esac
    last=$ct
    [ "$imtime" -gt "$last" ] && last=$imtime
    [ "$last" -gt 0 ] || return 1
    now=$(date +%s)
    age_h=$(( (now - last) / 3600 ))
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

    # zsh re-declaring an already-set `local` PRINTS `name=value` to stdout, which would corrupt the
    # path<TAB>reason record stream: declare everything once, here, never inside the loop. zsh also
    # treats an unmatched glob as fatal, so enable nullglob there (a no-op elsewhere).
    local wt reason wt_branch kind
    [ -n "${ZSH_VERSION:-}" ] && setopt localoptions nullglob
    for wt in "$wt_base"/*/; do
        wt="${wt%/}"
        [ -d "$wt" ] || continue

        # --no-optional-locks: a plain status may rewrite the index, bumping the very mtime the
        # staleness check reads, so the reaper own probe would count as activity.
        if git -C "$wt" --no-optional-locks status --porcelain 2>/dev/null | grep -q .; then
            continue
        fi

        if _borg_worktree_is_stale "$repo" "$wt"; then
            wt_branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

            kind=$(_borg_branch_merged "$repo" "$wt_branch") || kind=""
            case "$kind" in
                ancestor) reason="branch merged";;
                squash) reason="branch merged (squash)";;
                *) reason="stale (>${BORG_REAP_STALE_HOURS:-12}h)";;
            esac

            if [ "${BORG_REAP_DRY_RUN:-}" = "1" ]; then
                printf '%s\t%s\n' "$wt" "$reason"
                continue
            fi
            if git -C "$repo" worktree remove --force "$wt" 2>/dev/null; then
                printf '%s\t%s\n' "$wt" "$reason"
            fi
        fi
    done

    [ "${BORG_REAP_DRY_RUN:-}" = "1" ] && return 0
    git -C "$repo" worktree prune 2>/dev/null || true

    if [ -d "$wt_base" ]; then
        set -- "$wt_base"/*/
        [ -e "$1" ] || rmdir "$wt_base" 2>/dev/null || true
    fi
}

# ── Registry top-level key (projects -> repositories, EXPAND phase) ───────────
#
# The registry file's entry map is mid-rename from `projects` to `repositories`. Readers accept either
# and writers keep the key the file already has (MIGRATE phase; a new file starts with `projects`). THE
# shell-side decision lives here (the Python side's is borg_core.paths.normalize_registry): this jq filter
# maps a document that has `repositories` onto `.projects`, so every downstream filter keeps reading
# `.projects`, and the one zsh writer (`_borg_registry_write`) renames back to the key on disk.
# `repositories` wins when both are present. It lives in this file only because this is the one
# file already sourced by the zsh CLI, the bash hooks and (inlined) the plugin build.
#
# Direct-file readers prefix their filter:  jq "$BORG_REGISTRY_NORM_JQ | .projects[...]" "$file"
BORG_REGISTRY_NORM_JQ='if type == "object" and has("repositories") then (.projects = .repositories | del(.repositories)) else . end'

# Print <file> (default $BORG_REGISTRY) as JSON with the entry map under `.projects`. Byte-identical to
# `cat` unless the file mentions "repositories", so the common (old-key) path forks nothing extra.
borg_registry_normalized() {
    local _f="${1:-$BORG_REGISTRY}"
    case "$(< "$_f")" in
        *'"repositories"'*) jq "$BORG_REGISTRY_NORM_JQ" "$_f" ;;
        *) /bin/cat "$_f" ;;
    esac
}
