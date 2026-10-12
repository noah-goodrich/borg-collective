#!/usr/bin/env bats
# Squash-merge awareness and --dry-run for lib/reaper.sh. This repo squash-merges every PR, so a
# merged branch is never an ancestor of the default branch; the reaper must still see it as merged.

load test_helper/setup

REAPER_SH="${BATS_TEST_DIRNAME}/../lib/reaper.sh"

setup() {
    setup_temp_dirs
    export REPO="${BATS_TEST_TMPDIR}/repo"
    export ORIGIN="${BATS_TEST_TMPDIR}/origin.git"
    export WT_BASE="${BATS_TEST_TMPDIR}/borg-worktrees"
    export BORG_WORKTREE_STATE_DIR="$WT_BASE"
    mkdir -p "$WT_BASE"
    git init -q --bare -b main "$ORIGIN"
    git init -q -b main "$REPO"
    printf 'one\ntwo\nthree\n' > "$REPO/file.txt"
    git -C "$REPO" add file.txt
    git -C "$REPO" commit -q -m initial
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q -u origin main
    git -C "$REPO" remote set-head origin main
}

_make_worktree() {
    local slug="$1" wt="${WT_BASE}/repo/$1"
    mkdir -p "$WT_BASE/repo"
    git -C "$REPO" worktree add -q "$wt" -b "$slug"
    printf '%s' "$wt"
}

_commit_in() {
    printf '%s\n' "$3" > "$1/$2"
    git -C "$1" add "$2"
    git -C "$1" commit -q -m "edit $2"
}

# Squash-merge <branch> into main and push to origin (the branch commits never become ancestors).
_squash_merge() {
    git -C "$REPO" merge -q --squash "$1"
    git -C "$REPO" commit -q -m "squash $1"
    git -C "$REPO" push -q origin main
}

# Run the reaper with optional env assignments in $1 (e.g. "BORG_REAP_DRY_RUN=1").
_reap() {
    run bash -c "$1; . '$REAPER_SH'; _borg_reap_worktrees '$REPO'"
}

_gh_stub() {
    mkdir -p "$BATS_TEST_TMPDIR/stub"
    printf '#!/bin/sh\necho "$@" >> "%s/gh.calls"\n%s\n' "$BATS_TEST_TMPDIR" "$1" > "$BATS_TEST_TMPDIR/stub/gh"
    chmod +x "$BATS_TEST_TMPDIR/stub/gh"
}

@test "squash-merged branch with no upstream is reaped as branch merged (squash)" {
    wt=$(_make_worktree feat-sq)
    _commit_in "$wt" new.txt hello
    _squash_merge feat-sq
    _reap ":"
    [ "$status" -eq 0 ]
    printf %s "$output" | grep -q "branch merged (squash)"
    [ ! -d "$wt" ]
}

@test "squash-merge is seen against origin even when the local default branch lags" {
    wt=$(_make_worktree feat-lag)
    _commit_in "$wt" new.txt hello
    _squash_merge feat-lag
    git -C "$REPO" reset -q --hard HEAD~1
    _reap ":"
    printf %s "$output" | grep -q "branch merged (squash)"
    [ ! -d "$wt" ]
}

@test "a branch whose squash merge later conflicts with main is kept" {
    wt=$(_make_worktree feat-conf)
    _commit_in "$wt" file.txt "changed"
    _squash_merge feat-conf
    _commit_in "$REPO" file.txt "changed again"
    git -C "$REPO" push -q origin main
    _reap ":"
    [ -z "$output" ]
    [ -d "$wt" ]
}

@test "an unmerged branch with no upstream is kept" {
    wt=$(_make_worktree feat-open)
    _commit_in "$wt" new.txt hello
    _reap ":"
    [ -z "$output" ]
    [ -d "$wt" ]
}

@test "a dirty squash-merged worktree is still kept" {
    wt=$(_make_worktree feat-dirty)
    _commit_in "$wt" new.txt hello
    _squash_merge feat-dirty
    echo scratch > "$wt/untracked.txt"
    _reap ":"
    [ -z "$output" ]
    [ -d "$wt" ]
}

@test "BORG_REAP_DRY_RUN lists the would-be reap and removes nothing" {
    wt=$(_make_worktree feat-dry)
    _commit_in "$wt" new.txt hello
    _squash_merge feat-dry
    _reap "BORG_REAP_DRY_RUN=1"
    [ "$status" -eq 0 ]
    printf %s "$output" | grep -q "feat-dry.*branch merged (squash)"
    [ -d "$wt" ]
    git -C "$REPO" worktree list | grep -q feat-dry
}

@test "gh is never called unless BORG_REAP_GH=1" {
    _gh_stub "exit 1"
    wt=$(_make_worktree feat-gh)
    _commit_in "$wt" new.txt hello
    _reap "PATH='$BATS_TEST_TMPDIR/stub':\$PATH"
    [ ! -e "$BATS_TEST_TMPDIR/gh.calls" ]
    _reap "BORG_REAP_GH=1; PATH='$BATS_TEST_TMPDIR/stub':\$PATH"
    [ -e "$BATS_TEST_TMPDIR/gh.calls" ]
    [ -d "$wt" ]
}

@test "BORG_REAP_GH=1 reaps when gh reports a merged PR" {
    _gh_stub "echo 1"
    wt=$(_make_worktree feat-ghmerged)
    _commit_in "$wt" new.txt hello
    _reap "BORG_REAP_GH=1; PATH='$BATS_TEST_TMPDIR/stub':\$PATH"
    printf %s "$output" | grep -q "branch merged (squash)"
    [ ! -d "$wt" ]
}
