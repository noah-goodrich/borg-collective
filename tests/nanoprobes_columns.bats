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

# --- collapse duplicate agent ids (reader-side) ---

drow() {
    jq -nc --arg id "$1-0000-0000-0000-000000000000" --arg s "$2" --arg f "$3" \
        '{id:$id,agent_type:"borg-nanoprobe",summary:$s,finished_at:$f,transcript_path:"/nonexistent/x.jsonl"}' \
        >> "$BORG_DIR/agents.jsonl"
}

@test "nanoprobes: empty-summary newest row collapses onto the older row text" {
    drow dddd4444 "handback text" "2026-10-11T10:00:00Z"
    drow dddd4444 "" "2026-10-11T10:00:09Z"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c dddd4444)" -eq 1 ]
    [[ "$output" == *"handback text"* ]] || false
    [[ "$output" == *"2026-10-11T10:00:09Z"* ]] || false
}

@test "nanoprobes: resumed id with two summaries shows the newest" {
    drow eeee5555 "first run" "2026-10-11T10:00:00Z"
    drow eeee5555 "resumed run" "2026-10-11T11:00:00Z"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c eeee5555)" -eq 1 ]
    [[ "$output" == *"resumed run"* ]] || false
    [[ "$output" != *"first run"* ]] || false
}

@test "nanoprobes: 60 distinct ids with duplicates list 50 distinct" {
    for i in $(seq 100 159); do
        drow "id$i" "s$i" "2026-10-11T10:00:00Z"
        drow "id$i" "s$i" "2026-10-11T10:00:00Z"
    done
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c '^  id[0-9]')" -eq 50 ]
    [ "$(printf '%s\n' "$output" | grep '^  id[0-9]' | awk '{print $1}' | sort -u | wc -l)" -eq 50 ]
}

@test "nanoprobes: a non-object line is tolerated" {
    echo "not json at all" >> "$BORG_DIR/agents.jsonl"
    echo "[1,2]" >> "$BORG_DIR/agents.jsonl"
    drow ffff6666 "kept" "2026-10-11T10:00:00Z"
    drow ffff7777 "other" "2026-10-11T10:00:01Z"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"ffff6666"* ]] || false
    [[ "$output" == *"ffff7777"* ]] || false
}

@test "nanoprobes: same id in agents.jsonl and agents.jsonl.1 collapses" {
    drow gggg8888 "old text" "2026-10-10T10:00:00Z"
    mv "$BORG_DIR/agents.jsonl" "$BORG_DIR/agents.jsonl.1"
    drow gggg8888 "new text" "2026-10-11T10:00:00Z"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c gggg8888)" -eq 1 ]
    [[ "$output" == *"new text"* ]] || false
}

# Run _borg_agents_collapse directly: extract the function from borg.zsh and feed it stdin.
collapse() {
    zsh -c 'eval "$(sed -n "/^_borg_agents_collapse() {/,/^}/p" "$1")"; _borg_agents_collapse' _ "$BORG"
}

@test "nanoprobes: a junk line between two valid rows does not hide the older row" {
    drow hhhh1111 "older" "2026-10-10T10:00:00Z"
    echo "not json at all" >> "$BORG_DIR/agents.jsonl"
    drow hhhh2222 "newer" "2026-10-11T10:00:00Z"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"hhhh1111"* ]] || false
    [[ "$output" == *"hhhh2222"* ]] || false
}

@test "collapse: unparseable and non-object lines are dropped" {
    run collapse <<< $'junk\n[1,2]\n{"id":"a","summary":"x"}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "$output" == *'"id":"a"'* ]] || false
}

@test "collapse: interleaved ids keep first-seen newest-first order" {
    run collapse <<< $'{"id":"b","summary":"b1"}\n{"id":"a","summary":"a1"}\n{"id":"b","summary":"b0"}\n{"id":"c","summary":"c1"}\n{"id":"a","summary":"a0"}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 3 ]
    [ "$(printf '%s\n' "${lines[@]}" | jq -r .id | tr -d '\n')" = "bac" ]
}

@test "collapse: evidence fields come from the newest non-empty-summary row" {
    run collapse <<< $'{"id":"a","summary":"","finished_at":"T2"}\n{"id":"a","summary":"real","evidence_found":true,"evidence_score":7,"finished_at":"T1"}\n{"id":"a","summary":"old","evidence_found":false,"evidence_score":1}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "$(printf '%s' "$output" | jq -r .summary)" = "real" ]
    [ "$(printf '%s' "$output" | jq -r .evidence_score)" = "7" ]
    [ "$(printf '%s' "$output" | jq -r .evidence_found)" = "true" ]
    [ "$(printf '%s' "$output" | jq -r .finished_at)" = "T2" ]
}

@test "collapse: missing-id and empty-id rows pass through" {
    run collapse <<< $'{"summary":"noid"}\n{"id":"","summary":"emptyid"}\n{"id":"a","summary":"x"}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 3 ]
    [[ "$output" == *noid* ]] || false
    [[ "$output" == *emptyid* ]] || false
}

@test "collapse: an id whose rows all have empty summaries shows its newest row" {
    run collapse <<< $'{"id":"a","summary":"","finished_at":"T2"}\n{"id":"a","summary":"","finished_at":"T1"}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "$(printf '%s' "$output" | jq -r .finished_at)" = "T2" ]
}
