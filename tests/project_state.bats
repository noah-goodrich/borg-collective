#!/usr/bin/env bats
# AC5 step a: the per-project state-file resolver, one per language, byte-identical paths.
#
#   <state root>/projects/<repo12>-<path12>/state.json   (local-<path12> outside a git repo)
#
# Python (borg_core/paths.py), bash (lib/borg-hooks.sh) and zsh (lib/state-root.zsh) are computed for
# the same inputs and compared. XDG_STATE_HOME is left unset so the state root is derived from the
# sandboxed HOME, not supplied by the harness.

load test_helper/setup

ROOT="${BATS_TEST_DIRNAME}/.."

setup() {
    setup_temp_dirs
    unset XDG_STATE_HOME
    export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
    REPO="$BATS_TEST_TMPDIR/main"
    WT="$BATS_TEST_TMPDIR/wt"
    PLAIN="$BATS_TEST_TMPDIR/plain dir"
    mkdir -p "$REPO" "$PLAIN"
    git -C "$REPO" init -q
    git -C "$REPO" commit -q --allow-empty -m x
    git -C "$REPO" worktree add -q "$WT" -b wtb
}

_py() {
    PYTHONPATH="$ROOT" python3 -c 'import sys; from borg_core.paths import project_state_file as f; print(f(sys.argv[1]))' "$1"
}
_bash() { bash -c 'source "$1/lib/borg-hooks.sh" && _borg_project_state_file "$2"' _ "$ROOT" "$1"; }
_zsh() { zsh -c 'source "$1/lib/state-root.zsh" && _borg_project_state_file "$2"' _ "$ROOT" "$1"; }

_agree() {
    local p b z
    p="$(_py "$1")"
    b="$(_bash "$1")"
    z="$(_zsh "$1")"
    [ "$p" = "$b" ]
    [ "$b" = "$z" ]
    [[ "$p" == "$HOME/.local/state/borg/projects/"*"/state.json" ]]
}

@test "all three languages agree: main checkout" { _agree "$REPO"; }
@test "all three languages agree: linked worktree" { _agree "$WT"; }
@test "all three languages agree: non-git directory" { _agree "$PLAIN"; }
@test "all three languages agree: path with spaces, trailing slash" { _agree "$PLAIN/"; }
@test "all three languages agree: a symlink to a directory" {
    ln -s "$REPO" "$BATS_TEST_TMPDIR/ln"
    _agree "$BATS_TEST_TMPDIR/ln"
}
@test "all three languages agree: a nonexistent directory" { _agree "$BATS_TEST_TMPDIR/nope/"; }

@test "worktree and main checkout share the repo half, differ in the path half" {
    a="$(basename "$(dirname "$(_bash "$REPO")")")"
    b="$(basename "$(dirname "$(_bash "$WT")")")"
    [ "$a" != "$b" ]
    [ "${a%%-*}" = "${b%%-*}" ]
    [ "${a%%-*}" != "local" ]
}

@test "the same directory resolves the same path through a symlink and a trailing slash" {
    ln -s "$REPO" "$BATS_TEST_TMPDIR/ln"
    [ "$(_bash "$REPO")" = "$(_bash "$BATS_TEST_TMPDIR/ln/")" ]
}

@test "resolving creates nothing" {
    _bash "$REPO" > /dev/null
    [ ! -e "$HOME/.local/state/borg" ]
}
