#!/usr/bin/env bats
# borg nanoprobes: model + effort columns read from each run's transcript.

load test_helper/setup

FIX="${BATS_TEST_DIRNAME}/fixtures/nanoprobes"
BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
}

row() {
    printf '{"id":"%s-0000-0000-0000-000000000000","agent_type":"borg-nanoprobe","summary":"s","finished_at":"2026-10-11T10:00:00Z","transcript_path":"%s"}\n' "$1" "$2" >> "$BORG_DIR/agents.jsonl"
}

@test "nanoprobes: header names MODEL and EFFORT columns" {
    row aaaa1111 "$FIX/with-effort.jsonl"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"MODEL"* ]] || false
    [[ "$output" == *"EFFORT"* ]] || false
}

@test "nanoprobes: model and effort come from the first assistant entry" {
    row aaaa1111 "$FIX/with-effort.jsonl"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaaa1111"*"claude-sonnet-5-5"*"high"* ]] || false
    [[ "$output" != *"claude-opus-5-5"* ]] || false
}

@test "nanoprobes: effort absent prints a dash, model still shown" {
    row bbbb2222 "$FIX/no-effort.jsonl"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"bbbb2222"*"claude-haiku-4-5"*" - "* ]] || false
}

@test "nanoprobes: missing transcript prints a row with dashes" {
    row cccc3333 "/nonexistent/x.jsonl"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"cccc3333"* ]] || false
}

@test "nanoprobes: a row carrying model/effort renders them without the transcript" {
    printf '{"id":"dddd4444-0000-0000-0000-000000000000","agent_type":"borg-nanoprobe","summary":"s","finished_at":"2026-10-11T10:00:00Z","transcript_path":"/nonexistent/pruned.jsonl","model":"claude-sonnet-5-5","effort":"high"}\n' >> "$BORG_DIR/agents.jsonl"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"dddd4444"*"claude-sonnet-5-5"*"high"* ]] || false
}

@test "nanoprobes: a Cortex row reads model and effort from the history beside its snapshot path" {
    row eeee5555 "${BATS_TEST_DIRNAME}/fixtures/cortex/subagent-writer.json"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"eeee5555"*"claude-haiku-5-5"*"max"* ]] || false
}

@test "nanoprobes: a Cortex snapshot path with no history prints dashes, not the snapshot" {
    printf '%s\n' '{"title":"t"}' > "${BATS_TEST_TMPDIR}/n.json"
    row ffff6666 "${BATS_TEST_TMPDIR}/n.json"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"ffff6666"*" - "*" - "* ]] || false
}
