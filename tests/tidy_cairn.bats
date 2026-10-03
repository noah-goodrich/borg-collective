#!/usr/bin/env bats
# `borg tidy --cairn-leftovers [--dry-run]` end to end under real zsh, in a sandbox that overrides HOME,
# XDG_CONFIG_HOME AND XDG_STATE_HOME. All three: borg.zsh derives the state root from XDG_STATE_HOME and
# the config root from XDG_CONFIG_HOME independently, so overriding one leaks the other to the real machine.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state"
    STATE="$XDG_STATE_HOME/borg"
    mkdir -p "$BORG_DIR" "$STATE/cairn-inbox"
    echo {projects:{}} > "$BORG_REGISTRY"
    echo hit > "$BORG_DIR/cairn-hits.log"
    echo 1 > "$STATE/.cairn-last-write"
    echo x > "$STATE/cairn-inbox/item.json"
}

@test "tidy --cairn-leftovers --dry-run lists targets and deletes nothing" {
    run zsh "$BORG" tidy --cairn-leftovers --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would remove"* ]] || false
    [ -f "$BORG_DIR/cairn-hits.log" ]
    [ -d "$STATE/cairn-inbox" ]
    [ ! -e "$STATE/tidy-backups" ]
}

@test "tidy --cairn-leftovers backs up then deletes, and the AC3 verify clause counts zero" {
    run zsh "$BORG" tidy --cairn-leftovers
    [ "$status" -eq 0 ]
    [ ! -e "$BORG_DIR/cairn-hits.log" ]
    [ ! -e "$STATE/cairn-inbox" ]
    [ ! -e "$STATE/.cairn-last-write" ]
    [ -f "$BORG_DIR/registry.json" ]
    run bash -c "ls \"$BORG_DIR\" \"$STATE\" | grep -c cairn || true"
    [ "$output" = "0" ]
    run bash -c "cat \"$STATE\"/tidy-backups/*/config/cairn-hits.log"
    [ "$output" = "hit" ]
    run bash -c "cat \"$STATE\"/tidy-backups/*/state/cairn-inbox/item.json"
    [ "$output" = "x" ]
}

@test "tidy --cairn-leftovers is idempotent" {
    run zsh "$BORG" tidy --cairn-leftovers
    [ "$status" -eq 0 ]
    run zsh "$BORG" tidy --cairn-leftovers
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to clean"* ]] || false
}

@test "tidy rejects an unknown flag instead of falling into the interactive archive path" {
    run zsh "$BORG" tidy --cairn-leftovers --nope
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown flag"* ]] || false
}
