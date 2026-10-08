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
    GIT_COMMITTER_DATE="2000-01-01T00:00:00" git -C "$REPO" commit -q -m "initial"
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

# Age a worktree the way real inactivity does: old dir mtime AND old index.
_age_worktree() {
    local wt="$1" idx
    idx=$(git -C "$wt" rev-parse --absolute-git-dir)/index
    touch -t 200001010000 "$wt" "$idx"
}

# Give a worktree's branch an upstream (a bare remote) so it has nothing unpushed.
_push_upstream() {
    local wt="$1"
    [ -d "$BATS_TEST_TMPDIR/remote.git" ] || git init -q --bare "$BATS_TEST_TMPDIR/remote.git"
    git -C "$wt" remote add origin "$BATS_TEST_TMPDIR/remote.git" 2>/dev/null || true
    git -C "$wt" push -q -u origin HEAD
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
    _age_worktree "$wt"

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
    _age_worktree "$wt"

    run bash -c "
        BORG_REAP_STALE_HOURS=9999999
        . '$REAPER_SH'
        _borg_worktree_is_stale '$REPO' '$wt'
    "

    git -C "$REPO" worktree remove --force "$wt" 2>/dev/null || true

    [ "$status" -ne 0 ]
}

# ─── activity-based staleness ────────────────────────────────────────────────

@test "a worktree with an old dir mtime but a recent pushed commit is KEPT" {
    wt=$(_make_worktree "feat-active-pr")
    echo "work" >> "$wt/file.txt"
    git -C "$wt" add file.txt
    git -C "$wt" commit -q -m "recent work"
    _push_upstream "$wt"
    _age_worktree "$wt"
    touch -t 200001010000 "$(git -C "$wt" rev-parse --absolute-git-dir)/index"

    run bash -c "
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_worktree_is_stale '$REPO' '$wt'
    "
    [ "$status" -ne 0 ]
}

@test "a worktree with no recent commit and an old index is reaped as stale" {
    wt=$(_make_worktree "feat-idle")
    _age_worktree "$wt"

    result=$(bash -c "
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")
    printf '%s' "$result" | grep -q "stale"
    [ ! -d "$wt" ]
}

@test "a recently touched index keeps an otherwise old worktree" {
    wt=$(_make_worktree "feat-index-fresh")
    touch -t 200001010000 "$wt"

    run bash -c "
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_worktree_is_stale '$REPO' '$wt'
    "
    [ "$status" -ne 0 ]
}

@test "a stale-aged worktree with unpushed commits is KEPT" {
    wt=$(_make_worktree "feat-unpushed")
    echo "work" >> "$wt/file.txt"
    git -C "$wt" add file.txt
    GIT_COMMITTER_DATE="2000-01-02T00:00:00" git -C "$wt" commit -q -m "old unpushed"
    _age_worktree "$wt"

    result=$(bash -c "
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    ")
    [ -z "$result" ]
    [ -d "$wt" ]
}

@test "a stale-aged worktree ahead of its upstream is KEPT" {
    wt=$(_make_worktree "feat-ahead-upstream")
    _push_upstream "$wt"
    echo "more" >> "$wt/file.txt"
    git -C "$wt" add file.txt
    GIT_COMMITTER_DATE="2000-01-02T00:00:00" git -C "$wt" commit -q -m "old unpushed"
    _age_worktree "$wt"

    run bash -c "
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_worktree_is_stale '$REPO' '$wt'
    "
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
    _age_worktree "$wt"

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
    _age_worktree "$wt"

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
    _age_worktree "$wt"

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
    _age_worktree "$wt"

    bash -c "
        BORG_WORKTREE_STATE_DIR='$WT_BASE'
        BORG_REAP_STALE_HOURS=12
        . '$REAPER_SH'
        _borg_reap_worktrees '$REPO'
    "

    wt_count=$(git -C "$REPO" worktree list | grep -c "feat-prune-check" || true)
    [ "$wt_count" -eq 0 ]
}

# ── The DEFAULT state dir ─────────────────────────────────────────────────────
#
# Every test above exports BORG_WORKTREE_STATE_DIR in setup(), so none of them ever executes
# lib/reaper.sh's fallback -- and production executes nothing BUT the fallback, since no borg.zsh
# path, install.sh line or hook sets the variable. That gap let a literal `/Users/noah/...` default
# ship on a machine whose $HOME is /Users/noahgoodrich and go unnoticed for ~3.5 months with the
# suite green: `_borg_reap_worktrees` returned 0 at its `[ -d "$wt_base" ]` guard for every repo.
#
# These three assert the resolved value with the variable UNSET, which is the only way to test a
# default at all. They deliberately do not call setup()'s exports -- each subshell unsets first.

@test "BORG_WORKTREE_STATE_DIR defaults under \$HOME when unset" {
    result=$(bash -c '
        unset BORG_WORKTREE_STATE_DIR XDG_STATE_HOME
        HOME=/tmp/borg-default-home
        . "$1"
        printf "%s" "$BORG_WORKTREE_STATE_DIR"
    ' _ "$REAPER_SH")

    [ "$result" = "/tmp/borg-default-home/.local/state/borg/worktrees" ]
}

@test "BORG_WORKTREE_STATE_DIR default honors XDG_STATE_HOME" {
    result=$(bash -c '
        unset BORG_WORKTREE_STATE_DIR
        HOME=/tmp/borg-default-home
        XDG_STATE_HOME=/tmp/borg-xdg-state
        . "$1"
        printf "%s" "$BORG_WORKTREE_STATE_DIR"
    ' _ "$REAPER_SH")

    [ "$result" = "/tmp/borg-xdg-state/borg/worktrees" ]
}

@test "BORG_WORKTREE_STATE_DIR default contains no hardcoded home directory" {
    ! grep -qE '/Users/[a-z]+/\.local/state' "$REAPER_SH"
}

@test "the default state dir is the one _borg_reap_worktrees actually scans" {
    # The regression the wrong default caused, reproduced end to end: a worktree that IS under the
    # derived default must be reaped with the variable UNSET. Asserting the string above is not
    # enough -- the bug was that the resolved value and the scanned value were the same wrong path.
    fake_home="${BATS_TEST_TMPDIR}/home"
    derived="${fake_home}/.local/state/borg/worktrees"
    mkdir -p "${derived}/$(_repo_name)"
    wt="${derived}/$(_repo_name)/feat-default-scan"
    git -C "$REPO" worktree add -q "$wt" -b "feat-default-scan"
    _age_worktree "$wt"

    result=$(bash -c '
        unset BORG_WORKTREE_STATE_DIR XDG_STATE_HOME
        HOME="$2"
        BORG_REAP_STALE_HOURS=0
        . "$1"
        _borg_reap_worktrees "$3"
    ' _ "$REAPER_SH" "$fake_home" "$REPO")

    printf '%s' "$result" | grep -q "feat-default-scan"
    [ ! -d "$wt" ]
}
