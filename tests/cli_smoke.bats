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
    [[ "$output" == *"THE BORG COLLECTIVE"* ]]
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
    [[ "$output" == *"unknown command"* ]]
}

@test "borg help lists setup command" {
    run "$BORG_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"setup"* ]]
}

@test "borg help lists all core commands" {
    run "$BORG_CMD" help
    [[ "$output" == *"init"* ]]
    [[ "$output" == *"next"* ]]
    [[ "$output" == *"ls"* ]]
    [[ "$output" == *"scan"* ]]
    [[ "$output" == *"add"* ]]
    [[ "$output" == *"rm"* ]]
    [[ "$output" == *"refresh"* ]]
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
    [[ "$output" == "$expected" ]]
}

@test "borg --version prints VERSION file contents" {
    run "$BORG_CMD" --version
    [ "$status" -eq 0 ]
    version_file="$(dirname "$BORG_CMD")/VERSION"
    expected="$(tr -d '[:space:]' < "$version_file")"
    [[ "$output" == "$expected" ]]
}

@test "borg -V prints VERSION file contents" {
    run "$BORG_CMD" -V
    [ "$status" -eq 0 ]
    version_file="$(dirname "$BORG_CMD")/VERSION"
    expected="$(tr -d '[:space:]' < "$version_file")"
    [[ "$output" == "$expected" ]]
}

@test "borg help lists version command" {
    run "$BORG_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"version"* ]]
}
