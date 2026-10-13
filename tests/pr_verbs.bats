#!/usr/bin/env bats
# `borg pr` dispatches to borg_core.gh.cli. The logic is pinned by borg_core/gh/test_cli.py; this file pins
# only the zsh wiring and the help text.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
}

@test "borg pr gate --help dispatches to the gh module and exits 0" {
    run "$BORG_CMD" pr gate --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg pr"* ]] || false
    [[ "$output" == *"cancelled without ever getting a runner"* ]] || false
}

@test "borg pr merge-train --help says agents must never run it" {
    run "$BORG_CMD" pr merge-train --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"must never call it"* ]] || false
}

@test "borg help lists pr and its merge-train warning" {
    run "$BORG_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pr <verb>"* ]] || false
    [[ "$output" == *"NEVER agents"* ]] || false
}

@test "borg pr runs the real gate against a fake gh on PATH" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/sh\necho %s\n' "'{\"statusCheckRollup\":[],\"headRefOid\":\"abc\",\"mergeStateStatus\":\"CLEAN\",\"state\":\"OPEN\"}'" > "$BATS_TEST_TMPDIR/bin/gh"
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$BORG_CMD" pr gate 5 --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"verdict": "green"'* ]] || false
}
