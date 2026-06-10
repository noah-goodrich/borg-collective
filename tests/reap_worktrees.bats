#!/usr/bin/env bats
# Tests for the nanoprobe worktree reaper in lib/reaper.sh:
#   _borg_worktree_is_stale <repo_path> <worktree_path>
#   _borg_reap_worktrees <repo_path>
#
# Borg-managed worktree slugs replace "/" with "-" in branch names, so all
# slugs here use dashes. Worktree path = $WT_BASE/<repo-name>/<slug>.

load test_helper/setup

REAPER_SH="${BATS_TEST_DIRNAME}/../lib/reaper.sh"

setup() {
    setup_temp_dirs

    export REPO="${BATS_TEST_TMPDIR}/repo"
    export WT_BASE="${BATS_TEST_TMPDIR}/borg-worktrees"
    export BORG_WORKTREE_STATE_DIR="$WT_BASE"

    mkdir -p "$REPO" "$WT_BASE"
    git -C "$REPO" init -q
    git -C "$REPO" config user.email "test@test.com"
    git -C "$REPO" config user.name "Test"
    echo "init" > "$REPO/file.txt"
    git -C "$REPO" add file.txt
    git -C "$REPO" commit -q -m "initial"
}

_repo_name() { printf '%s' "${REPO##*/}"; }

_make_worktree() {
    local slug="$1"
    local wt="${WT_BASE}/$(_repo_name)/${slug}"
    mkdir -p "$WT_BASE/$(_repo_name)"
    git -C "$REPO" worktree add -q "$wt" -b "$slug"
    printf '%s' "$wt"
}

_merge_branch() {
    local branch="$1"
    local default_branch
    default_branch=$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null) || default_branch="main"
    git -C "$REPO" checkout -q "$default_branch"
    git -C "$REPO" merge -q --no-ff "$branch" -m "merge $branch"
}

# ─── _borg_worktree_is_stale ─────────────────────────────────────────────────

@test "_borg_worktree_is_stale returns 0 (stale) for a missing directory" {
    run bash -c ". '$REAPER_SH'; _borg_worktree_is_stale '$REPO' '/nonexistent/wt'"
    [ "$status" -eq 0 ]
}

@test "_borg_worktree_is_stale returns 1 (keep) for a fresh unmerged worktree" {
    wt=$(_make_worktree "feat-keep-me")

    run bash -c "
        BORG_REAP_STALE_HOURS=9999
        . '$REAPER_SH'
        _borg_worktree_is_stale '$REPO' '$wt'
    "

    git -C "$REPO" worktree remove --force "$wt" 2>/dev/null || true

    [ "$status" -ne 0 ]
}

@test "_borg_worktree_is_stale returns 0 (stale) for an age-expired worktree" {
    wt=$(_make_worktree "feat-old-branch")
    touch -t 200001010000 "$wt"

    run bash -c "
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_worktree_is_stale '$REPO' '$wt'
    "

    git -C "$REPO" worktree remove --force "$wt" 2>/dev/null || true

    [ "$status" -eq 0 ]
}

@test "_borg_worktree_is_stale honors BORG_REAP_STALE_HOURS override (keep under large threshold)" {
    wt=$(_make_worktree "feat-override-test")
    touch -t 200001010000 "$wt"

    run bash -c "
        BORG_REAP_STALE_HOURS=9999999
        . '$REAPER_SH'
        _borg_worktree_is_stale '$REPO' '$wt'
    "

    git -C "$REPO" worktree remove --force "$wt" 2>/dev/null || true

    [ "$status" -ne 0 ]
}

# ─── _borg_reap_worktrees ────────────────────────────────────────────────────

@test "_borg_reap_worktrees is a no-op when state dir does not exist" {
    result=$(bash -c "
        BORG_WORKTREE_STATE_DIR='${BATS_TEST_TMPDIR}/no-such-dir'
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")
    [ -z "$result" ]
}

@test "_borg_reap_worktrees is a no-op when repo subdir is empty" {
    mkdir -p "$WT_BASE/$(_repo_name)"

    result=$(bash -c "
        BORG_WORKTREE_STATE_DIR='$WT_BASE'
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")
    [ -z "$result" ]
}

@test "_borg_reap_worktrees removes an age-expired worktree and prints its path" {
    wt=$(_make_worktree "feat-expired")
    touch -t 200001010000 "$wt"

    result=$(bash -c "
        BORG_WORKTREE_STATE_DIR='$WT_BASE'
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")

    [ -n "$result" ]
    printf '%s' "$result" | grep -q "feat-expired"
    [ ! -d "$wt" ]
}

@test "_borg_reap_worktrees prints 'stale' reason for age-expired worktree" {
    wt=$(_make_worktree "feat-stale-reason")
    touch -t 200001010000 "$wt"

    result=$(bash -c "
        BORG_WORKTREE_STATE_DIR='$WT_BASE'
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")

    printf '%s' "$result" | grep -q "stale"
}

@test "_borg_reap_worktrees skips a worktree with uncommitted changes" {
    wt=$(_make_worktree "feat-dirty")
    echo "dirty" >> "$wt/file.txt"
    touch -t 200001010000 "$wt"

    result=$(bash -c "
        BORG_WORKTREE_STATE_DIR='$WT_BASE'
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")

    [ -z "$result" ]
    [ -d "$wt" ]

    git -C "$REPO" worktree remove --force "$wt" 2>/dev/null || true
}

@test "_borg_reap_worktrees skips a fresh worktree under large threshold" {
    wt=$(_make_worktree "feat-fresh-keep")

    result=$(bash -c "
        BORG_WORKTREE_STATE_DIR='$WT_BASE'
        BORG_REAP_STALE_HOURS=9999999
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")

    [ -z "$result" ]
    [ -d "$wt" ]

    git -C "$REPO" worktree remove --force "$wt" 2>/dev/null || true
}

@test "_borg_reap_worktrees removes merged-branch worktree with 'branch merged' reason" {
    wt=$(_make_worktree "feat-to-merge")
    echo "change" >> "$wt/file.txt"
    git -C "$wt" add file.txt
    git -C "$wt" commit -q -m "change on branch"

    _merge_branch "feat-to-merge"

    result=$(bash -c "
        BORG_WORKTREE_STATE_DIR='$WT_BASE'
        BORG_REAP_STALE_HOURS=9999999
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")

    [ -n "$result" ]
    printf '%s' "$result" | grep -q "branch merged"
    [ ! -d "$wt" ]
}

@test "_borg_reap_worktrees only removes worktrees inside BORG_WORKTREE_STATE_DIR" {
    outside="${BATS_TEST_TMPDIR}/outside-wt"
    mkdir -p "$outside"
    git -C "$REPO" worktree add -q "$outside" -b "feat-outside"

    result=$(bash -c "
        BORG_WORKTREE_STATE_DIR='$WT_BASE'
        BORG_REAP_STALE_HOURS=0
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")

    [ -d "$outside" ]

    git -C "$REPO" worktree remove --force "$outside" 2>/dev/null || true
}

@test "_borg_reap_worktrees prunes git worktree metadata after removal" {
    wt=$(_make_worktree "feat-prune-check")
    touch -t 200001010000 "$wt"

    bash -c "
        BORG_WORKTREE_STATE_DIR='$WT_BASE'
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    "

    wt_count=$(git -C "$REPO" worktree list | grep -c "feat-prune-check" || true)
    [ "$wt_count" -eq 0 ]
}
