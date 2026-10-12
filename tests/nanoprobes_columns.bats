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

@test "nanoprobes: an empty-agent_type row is hidden from the list and from nanoprobe-log" {
    row dddd4444 "/nonexistent/x.jsonl"
    printf '{"id":"eeee5555-0000-0000-0000-000000000000","agent_type":"","summary":"away recap","finished_at":"2026-10-11T11:00:00Z","transcript_path":""}\n' >> "$BORG_DIR/agents.jsonl"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"dddd4444"* ]] || false
    [[ "$output" != *"eeee5555"* ]] || false
    [[ "$output" != *"away recap"* ]] || false
    run zsh "$BORG" nanoprobe-log eeee5555
    [ "$status" -ne 0 ]
    run zsh "$BORG" nanoprobe-log dddd4444
    [ "$status" -eq 0 ]
}

@test "nanoprobes: lists typed, ? and no-key rows, hides the empty one, tolerates a non-object line" {
    f="$BORG_DIR/agents.jsonl"
    printf '[1,2]\n' >> "$f"
    printf '{"id":"aaaa0001-0000-0000-0000-000000000000","summary":"nokey-sum","finished_at":"2026-10-11T10:01:00Z","transcript_path":""}\n' >> "$f"
    printf '{"id":"aaaa0002-0000-0000-0000-000000000000","agent_type":"?","summary":"q-sum","finished_at":"2026-10-11T10:02:00Z","transcript_path":""}\n' >> "$f"
    printf '{"id":"aaaa0003-0000-0000-0000-000000000000","agent_type":"","summary":"empty-sum","finished_at":"2026-10-11T10:03:00Z","transcript_path":""}\n' >> "$f"
    printf '{"id":"aaaa0004-0000-0000-0000-000000000000","agent_type":"borg-nanoprobe","summary":"typed-sum","finished_at":"2026-10-11T10:04:00Z","transcript_path":""}\n' >> "$f"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaaa0001"* ]] || false
    [[ "$output" == *"aaaa0002"* ]] || false
    [[ "$output" == *"aaaa0004"* ]] || false
    [[ "$output" != *"aaaa0003"* ]] || false
}

@test "nanoprobes: an empty-agent_type row that lives only in the rotated agents.jsonl.1 is hidden" {
    printf '{"id":"bbbb0001-0000-0000-0000-000000000000","agent_type":"","summary":"rotated-empty","finished_at":"2026-10-10T10:00:00Z","transcript_path":""}\n' > "$BORG_DIR/agents.jsonl.1"
    row bbbb0002 "/nonexistent/x.jsonl"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"bbbb0002"* ]] || false
    [[ "$output" != *"bbbb0001"* ]] || false
}
