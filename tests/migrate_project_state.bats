#!/usr/bin/env bats
# `borg tidy --migrate-project-state [--dry-run]` end to end. setup_temp_dirs redirects HOME and all
# three XDG dirs, so nothing here can reach the real machine. Planner cases: test_project_core.py.

load test_helper/setup

setup() {
    setup_temp_dirs
    mkdir -p "$BORG_DIR" "$XDG_STATE_HOME/borg"
    PROJ="$BATS_TEST_TMPDIR/dev/proj"
    mkdir -p "$PROJ/.borg"
    printf '{"status":"idle"}' > "$PROJ/.borg/state.json"
    printf '{"projects":{"proj":{"path":"%s","repo":null}}}' "$PROJ" > "$BORG_REGISTRY"
}

borg() { zsh "${BATS_TEST_DIRNAME}/../borg.zsh" "$@"; }

@test "migrate-project-state copies to the state root and removes the legacy file" {
    run borg tidy --migrate-project-state
    [ "$status" -eq 0 ]
    [ ! -e "$PROJ/.borg" ]
    run bash -c "cat '$XDG_STATE_HOME'/borg/projects/local-*/state.json"
    [ "$output" = '{"status":"idle"}' ]
    run bash -c "ls '$XDG_STATE_HOME'/borg/tidy-backups/*/projects/local-*/state.json"
    [ "$status" -eq 0 ]
}

@test "migrate-project-state second run says nothing to migrate" {
    run borg tidy --migrate-project-state
    [ "$status" -eq 0 ]
    run borg tidy --migrate-project-state
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to migrate"* ]]
}

@test "migrate-project-state --dry-run prints the plan and touches nothing" {
    run borg tidy --migrate-project-state --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would copy"* ]]
    [ -e "$PROJ/.borg/state.json" ]
    [ ! -e "$XDG_STATE_HOME/borg/projects" ]
    [ ! -e "$XDG_STATE_HOME/borg/tidy-backups" ]
}

@test "migrate-project-state refuses a git-backed entry with a null repo, naming backfill-repo" {
    git -C "$PROJ" init -q
    run borg tidy --migrate-project-state
    [ "$status" -eq 2 ]
    [[ "$output" == *"backfill-repo"* ]]
    [ -e "$PROJ/.borg/state.json" ]
    [ ! -e "$XDG_STATE_HOME/borg/projects" ]
}

@test "migrate-project-state --path migrates an unregistered state.json" {
    STRAY="$BATS_TEST_TMPDIR/dev/stray"
    mkdir -p "$STRAY/.borg"
    printf '{"s":1}' > "$STRAY/.borg/state.json"
    run borg tidy --migrate-project-state --path "$STRAY/.borg/state.json"
    [ "$status" -eq 0 ]
    [ ! -e "$STRAY/.borg" ]
}
