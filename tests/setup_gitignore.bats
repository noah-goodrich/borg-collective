#!/usr/bin/env bats
# `borg setup` adds .borg/state.json to a repository's .gitignore only when git does not already ignore it.
# The real lib/gitignore.zsh function runs against real git repositories in the sandbox (the regression: a
# repository ignoring .borg/* through a broader rule got a redundant line and an uncommitted change).

load test_helper/setup

setup() {
    setup_temp_dirs
    export REPO="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$REPO"
}

_ensure() {
    run zsh -c "source '$BORG_HOME/lib/gitignore.zsh'; _borg_ensure_state_gitignored '$1'"
}

@test "setup gitignore: git repository with no .gitignore gets the line" {
    git -C "$REPO" init -q
    _ensure "$REPO"
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/.gitignore")" = ".borg/state.json" ]
}

@test "setup gitignore: an exact .borg/state.json line is left unchanged" {
    git -C "$REPO" init -q
    printf '.borg/state.json\n' > "$REPO/.gitignore"
    _ensure "$REPO"
    [ "$status" -eq 1 ]
    [ "$(cat "$REPO/.gitignore")" = ".borg/state.json" ]
}

@test "setup gitignore: a broader .borg/* rule is left unchanged" {
    git -C "$REPO" init -q
    printf '.borg/*\n' > "$REPO/.gitignore"
    _ensure "$REPO"
    [ "$status" -eq 1 ]
    [ "$(cat "$REPO/.gitignore")" = ".borg/*" ]
}

@test "setup gitignore: .borg/ with a !.borg/checkpoints/ negation is left unchanged" {
    git -C "$REPO" init -q
    printf '.borg/\n!.borg/checkpoints/\n' > "$REPO/.gitignore"
    _ensure "$REPO"
    [ "$status" -eq 1 ]
    [ "$(cat "$REPO/.gitignore")" = ".borg/"$'\n'"!.borg/checkpoints/" ]
}

@test "setup gitignore: a non-git directory behaves as before (creates, then literal grep)" {
    _ensure "$REPO"
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/.gitignore")" = ".borg/state.json" ]
    _ensure "$REPO"
    [ "$status" -eq 1 ]
    [ "$(cat "$REPO/.gitignore")" = ".borg/state.json" ]
    printf '.borg/*\n' > "$REPO/.gitignore"
    _ensure "$REPO"
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/.gitignore")" = ".borg/*"$'\n'".borg/state.json" ]
}
