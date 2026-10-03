#!/usr/bin/env bats
# `borg tidy --migrate-state [--dry-run]` end to end against the sandbox (HOME and all three XDG
# dirs are redirected by setup_temp_dirs). Planner cases live in borg_core/statemigrate/test_core.py.

load test_helper/setup

setup() {
    setup_temp_dirs
    mkdir -p "$BORG_DIR" "$XDG_STATE_HOME/borg"
    OLD="$BORG_DIR"
    NEW="$XDG_STATE_HOME/borg"
}

borg() { zsh "${BATS_TEST_DIRNAME}/../borg.zsh" "$@"; }

@test "migrate-state moves an old-only file, keeps STAYS files, removes the old copy" {
    printf '{"a":1}' > "$OLD/cortex-wakes.json"
    printf '# keep\n' > "$OLD/config.zsh"
    run borg tidy --migrate-state
    [ "$status" -eq 0 ]
    [ "$(cat "$NEW/cortex-wakes.json")" = '{"a":1}' ]
    [ ! -e "$OLD/cortex-wakes.json" ]
    [ "$(cat "$OLD/config.zsh")" = '# keep' ]
    [ ! -e "$NEW/config.zsh" ]
}

@test "migrate-state appends old history before new and backs the old file up first" {
    printf 'old\n' > "$OLD/agents.jsonl"
    printf 'new\n' > "$NEW/agents.jsonl"
    run borg tidy --migrate-state
    [ "$status" -eq 0 ]
    [ "$(cat "$NEW/agents.jsonl")" = "$(printf 'old\nnew')" ]
    [ ! -e "$OLD/agents.jsonl" ]
    run bash -c "cat '$NEW'/tidy-backups/*/agents.jsonl"
    [ "$output" = old ]
}

@test "migrate-state keeps the NEW json state when both exist" {
    printf '{"v":"old"}' > "$OLD/usage-guardian.json"
    printf '{"v":"new"}' > "$NEW/usage-guardian.json"
    run borg tidy --migrate-state
    [ "$status" -eq 0 ]
    [ "$(cat "$NEW/usage-guardian.json")" = '{"v":"new"}' ]
    [ ! -e "$OLD/usage-guardian.json" ]
}

@test "migrate-state is idempotent: the second run is a no-op" {
    printf 'a\n' > "$OLD/memory-hits.log"
    run borg tidy --migrate-state
    [ "$status" -eq 0 ]
    run borg tidy --migrate-state
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to migrate"* ]]
    [ "$(cat "$NEW/memory-hits.log")" = a ]
}

@test "migrate-state --dry-run prints the plan and touches nothing" {
    printf 'a\n' > "$OLD/agents.jsonl"
    run borg tidy --migrate-state --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would move"*"agents.jsonl"* ]]
    [ -e "$OLD/agents.jsonl" ]
    [ ! -e "$NEW/agents.jsonl" ]
    [ ! -e "$NEW/tidy-backups" ]
}

@test "migrate-state leaves the old copy when verification fails" {
    printf '{broken' > "$OLD/cortex-wakes.json"
    run borg tidy --migrate-state
    [ "$status" -eq 1 ]
    [ -e "$OLD/cortex-wakes.json" ]
}
