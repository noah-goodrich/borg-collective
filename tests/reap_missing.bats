#!/usr/bin/env bats
# `borg reap` lists registry entries whose directory is gone, and `--drop-missing` removes exactly those (#424).

load test_helper/setup

setup() {
    setup_temp_dirs
    export BORG="${BATS_TEST_DIRNAME}/../borg.zsh"
    mkdir -p "$BORG_DIR" "$BATS_TEST_TMPDIR/here" "$BATS_TEST_TMPDIR/main"
}

@test "reap: lists a missing directory with the drop hint and changes nothing" {
    printf '{"projects":{"here":{"path":"%s/here"},"gone":{"path":"%s/gone"}}}' \
        "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" > "$BORG_REGISTRY"
    run zsh "$BORG" reap
    [ "$status" -eq 0 ]
    [[ "$output" == *"missing: gone ($BATS_TEST_TMPDIR/gone)"* ]] || false
    [[ "$output" != *"missing: here"* ]] || false
    [[ "$output" == *"run borg reap --drop-missing to remove them"* ]] || false
    run jq -r '.projects | keys | join(",")' "$BORG_REGISTRY"
    [ "$output" = "gone,here" ]
}

@test "reap --drop-missing: removes exactly the missing entries, prints each, deletes nothing on disk" {
    printf '{"projects":{"here":{"path":"%s/here"},"gone":{"path":"%s/gone"},"desk":{"path":null,"source":"desktop"}}}' \
        "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" > "$BORG_REGISTRY"
    run zsh "$BORG" reap --drop-missing
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dropped"*"gone"*"$BATS_TEST_TMPDIR/gone"* ]] || false
    [[ "$output" != *"--drop-missing to remove"* ]] || false
    run jq -r '.projects | keys | join(",")' "$BORG_REGISTRY"
    [ "$output" = "desk,here" ]
    [ -d "$BATS_TEST_TMPDIR/here" ]
}

@test "reap: a worktree entry is missing only when its own path is gone" {
    printf '{"projects":{"main":{"path":"%s/main"},"wt-live":{"path":"%s/here","repo":"main"},"wt-dead":{"path":"%s/dead-wt","repo":"main"}}}' \
        "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" > "$BORG_REGISTRY"
    run zsh "$BORG" reap
    [[ "$output" == *"missing: wt-dead"* ]] || false
    [[ "$output" != *"missing: wt-live"* ]] || false
    [[ "$output" != *"missing: main"* ]] || false
    rmdir "$BATS_TEST_TMPDIR/main"
    run zsh "$BORG" reap
    [[ "$output" == *"missing: main"* ]] || false
    [[ "$output" != *"missing: wt-live"* ]] || false
}

@test "reap: a registry with no missing entries prints nothing extra" {
    printf '{"projects":{"here":{"path":"%s/here"}}}' "$BATS_TEST_TMPDIR" > "$BORG_REGISTRY"
    run zsh "$BORG" reap
    [ "$status" -eq 0 ]
    [[ "$output" != *"missing"* ]] || false
    [[ "$output" != *"drop-missing"* ]] || false
    run zsh "$BORG" reap --drop-missing
    [ "$status" -eq 0 ]
    [[ "$output" != *"Dropped"* ]] || false
}

@test "reap --drop-missing: keeps the repositories key a migrated file already has" {
    printf '{"repositories":{"here":{"path":"%s/here"},"gone":{"path":"%s/gone"}}}' \
        "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" > "$BORG_REGISTRY"
    run zsh "$BORG" reap --drop-missing
    [ "$status" -eq 0 ]
    run jq -r '(keys | join(",")) + ":" + (.repositories | keys | join(","))' "$BORG_REGISTRY"
    [ "$output" = "repositories:here" ]
}

@test "reap: an unknown argument is refused" {
    run zsh "$BORG" reap --nope
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown argument"* ]] || false
}
