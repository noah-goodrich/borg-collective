#!/usr/bin/env bats
# The scan never registers a repository under a temp root (#424: a Cortex session in /private/tmp became "tmp").

load test_helper/setup

setup() {
    setup_temp_dirs
    export BORG="${BATS_TEST_DIRNAME}/../borg.zsh"
    mkdir -p "$BORG_DIR" "$HOME/.claude" "$BATS_TEST_TMPDIR/stubbin" "$BATS_TEST_TMPDIR/tmproot/scratch" \
        "$BATS_TEST_TMPDIR/elsewhere/real-repo"
    printf '#!/bin/sh\nexit 1\n' > "$BATS_TEST_TMPDIR/stubbin/tmux"
    chmod +x "$BATS_TEST_TMPDIR/stubbin/tmux"
    export PATH="$BATS_TEST_TMPDIR/stubbin:$PATH"
}

@test "scan temp roots: the default list names /tmp, /private/tmp, /var/folders and TMPDIR" {
    unset BORG_SCAN_TEMP_ROOTS
    TMPDIR=/somewhere/custom/ run run_zsh_fn registry borg_scan_temp_roots
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "/tmp" ]
    [ "${lines[1]}" = "/private/tmp" ]
    [ "${lines[2]}" = "/var/folders" ]
    [ "${lines[3]}" = "/somewhere/custom" ]
}

@test "scan temp roots: a path under a temp root is skipped, a sibling is not" {
    run_zsh_fn registry borg_registry_init
    export BORG_SCAN_TEMP_ROOTS="$BATS_TEST_TMPDIR/tmproot"
    run run_zsh_fn registry borg_scan_path_should_skip "$BATS_TEST_TMPDIR/tmproot/scratch"
    [ "$status" -eq 0 ]
    mkdir -p "$BATS_TEST_TMPDIR/tmproot-sibling"
    run run_zsh_fn registry borg_scan_path_should_skip "$BATS_TEST_TMPDIR/tmproot-sibling"
    [ "$status" -eq 1 ]
}

@test "scan temp roots: a literal /private/tmp path is skipped even when it exists" {
    unset BORG_SCAN_TEMP_ROOTS
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_scan_path_should_skip "/private/tmp"
    [ "$status" -eq 0 ]
}

@test "scan: a session pointing under a temp root is not registered, one elsewhere is" {
    export BORG_SCAN_TEMP_ROOTS="$BATS_TEST_TMPDIR/tmproot"
    printf '%s\n' \
        "- | $BATS_TEST_TMPDIR/tmproot/scratch | note" \
        "- | $BATS_TEST_TMPDIR/elsewhere/real-repo | note" > "$HOME/.claude/session-log.md"
    BORG_DEBUG=1 run zsh "$BORG" scan --no-llm
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping temp path $BATS_TEST_TMPDIR/tmproot/scratch"* ]] || false
    run jq -r '.repositories | keys | join(",")' "$BORG_REGISTRY"
    [ "$output" = "real-repo" ]
}
