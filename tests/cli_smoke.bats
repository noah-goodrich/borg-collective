#!/usr/bin/env bats

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"
DRONE_CMD="${BATS_TEST_DIRNAME}/../drone.zsh"

setup() {
    setup_temp_dirs
}

@test "borg help exits 0" {
    run "$BORG_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"THE BORG COLLECTIVE"* ]] || false
}

@test "borg --help exits 0" {
    run "$BORG_CMD" --help
    [ "$status" -eq 0 ]
}

@test "borg -h exits 0" {
    run "$BORG_CMD" -h
    [ "$status" -eq 0 ]
}

@test "borg invalid-command exits non-zero" {
    run "$BORG_CMD" invalid-command-xyz
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown command"* ]] || false
}

@test "borg help lists setup command" {
    run "$BORG_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"setup"* ]] || false
}

@test "borg help lists all core commands" {
    run "$BORG_CMD" help
    [[ "$output" == *"init"* ]] || false
    [[ "$output" == *"next"* ]] || false
    [[ "$output" == *"link"* ]] || false
    [[ "$output" == *"scan"* ]] || false
    [[ "$output" == *"add"* ]] || false
    [[ "$output" == *"rm"* ]] || false
    [[ "$output" == *"switch"* ]] || false
}

# The aliases ls/status/hail/brief/briefing/refresh were removed 2026-08-10. These assert the
# removal is real AND that it points somewhere useful — a bare "unknown command" would send years
# of muscle memory into a dead end. Note the previous version of the help test above passed
# vacuously after removal, because `borg help` still contains the strings "ls" and "refresh" inside
# the removed-commands notice; that is why it now asserts on "link" and "switch" instead.
@test "removed link aliases exit non-zero and point at 'borg link'" {
    for alias in ls status hail brief; do
        run "$BORG_CMD" "$alias"
        [ "$status" -ne 0 ]
        [[ "$output" == *"borg link"* ]] || false
    done
}

@test "removed briefing/refresh aliases point at the right link flag" {
    run "$BORG_CMD" briefing
    [ "$status" -ne 0 ]
    [[ "$output" == *"borg link --brief"* ]] || false

    run "$BORG_CMD" refresh
    [ "$status" -ne 0 ]
    [[ "$output" == *"borg link --refresh"* ]] || false
}

# PROBED THROUGH A SHAPE THAT ACTUALLY DISPATCHES, which it was not until 2026-08-26. This case ran
# `borg link --help`, and until S4 `--help` fell into _borg_link_dispatch's lenient `-*)` arm, was
# swallowed, and rendered the whole overview — so the invocation genuinely reached the registry, the
# renderer and the document. S4 gave `--help` an explicit arm that returns at the TOP of the
# function, which silently reduced this case to "the usage line does not say 'unknown command'".
# Measured: replacing the entire overview arm with `die "overview deleted by mutation"` left this
# case AND its cli_contract twin green.
#
# `--local` because a bare `borg link` sweeps every source over the network post-S3; a smoke test
# must not need `gh`. The seeded registry is what makes the render non-trivial — against the empty
# default the overview short-circuits to "No projects registered" and never builds a document.
@test "borg link is still dispatched" {
    printf '%s' '{"projects":{"smoke":{"path":null,"source":"cli","status":"idle","summary":"Smoke."}}}' \
        > "$BORG_REGISTRY"

    run "$BORG_CMD" link --local
    [ "$status" -eq 0 ]
    [[ "$output" == *"THE BORG COLLECTIVE"* ]] || false
    [[ "$output" == *"smoke"* ]] || false
    [[ "$output" != *"unknown command"* ]] || false
    [[ "$output" != *"was removed"* ]] || false
}

# The wording half, kept separate from the liveness half above so neither can stand in for the other.
@test "borg link --help prints usage and never reads as a removed verb" {
    run "$BORG_CMD" link --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage: borg link"* ]] || false
    [[ "$output" != *"unknown command"* ]] || false
    [[ "$output" != *"was removed"* ]] || false
}

@test "drone help exits 0" {
    run "$DRONE_CMD" help
    [ "$status" -eq 0 ]
}

@test "drone invalid-command exits non-zero" {
    run "$DRONE_CMD" invalid-command-xyz
    [ "$status" -ne 0 ]
}

@test "borg version prints VERSION file contents" {
    run "$BORG_CMD" version
    [ "$status" -eq 0 ]
    version_file="$(dirname "$BORG_CMD")/VERSION"
    expected="$(tr -d '[:space:]' < "$version_file")"
    [[ "$output" == "$expected" ]] || false
}

@test "borg --version prints VERSION file contents" {
    run "$BORG_CMD" --version
    [ "$status" -eq 0 ]
    version_file="$(dirname "$BORG_CMD")/VERSION"
    expected="$(tr -d '[:space:]' < "$version_file")"
    [[ "$output" == "$expected" ]] || false
}

@test "borg -V prints VERSION file contents" {
    run "$BORG_CMD" -V
    [ "$status" -eq 0 ]
    version_file="$(dirname "$BORG_CMD")/VERSION"
    expected="$(tr -d '[:space:]' < "$version_file")"
    [[ "$output" == "$expected" ]] || false
}

@test "borg help lists version command" {
    run "$BORG_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"version"* ]] || false
}
