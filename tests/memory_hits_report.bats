#!/usr/bin/env bats
# Tests for bin/memory-hits-report — reads/session for Claude Code project-memory files.
#
# Contract: reads $BORG_DIR/memory-hits.log for the numerator, counts real session transcript
# files (.jsonl, excluding -/ and -private-tmp/ pollution) modified within the window for the
# denominator, and prints a PASS/FAIL verdict against the pre-registered 0.2 reads/session bar.

load test_helper/setup

REPORT="${BATS_TEST_DIRNAME}/../bin/memory-hits-report"

setup() {
    setup_temp_dirs
    mkdir -p "$HOME/.claude/projects/-Users-noah-dev-cairn"
    mkdir -p "$HOME/.claude/projects/-"
    mkdir -p "$HOME/.claude/projects/-private-tmp"
}

_seed_session() {
    local proj="$1" id="${2:-$(uuidgen 2>/dev/null || echo sess-$RANDOM)}"
    mkdir -p "$HOME/.claude/projects/$proj"
    printf '{}' > "$HOME/.claude/projects/$proj/$id.jsonl"
}

_seed_hit() {
    local session="$1" project="$2"
    mkdir -p "$BORG_DIR"
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$session" "$project" "MEMORY.md" "100" \
        >> "$BORG_DIR/memory-hits.log"
}

@test "reports no-data message when the hit log does not exist" {
    run bash "$REPORT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no data yet"* ]] || false
}

@test "computes ratio and PASSes when reads/session is at least 0.2" {
    for i in 1 2 3 4 5; do _seed_session "-Users-noah-dev-cairn" "sess-$i"; done
    _seed_hit "sess-1" "cairn"
    _seed_hit "sess-2" "cairn"

    run bash "$REPORT" --days 30
    [ "$status" -eq 0 ]
    [[ "$output" == *"reads:    2"* ]] || false
    [[ "$output" == *"sessions: 5"* ]] || false
    [[ "$output" == *"0.400 reads/session"* ]] || false
    [[ "$output" == *"PASS"* ]] || false
}

@test "FAILs when reads/session is below 0.2" {
    for i in 1 2 3 4 5 6 7 8 9 10; do _seed_session "-Users-noah-dev-cairn" "sess-$i"; done
    _seed_hit "sess-1" "cairn"

    run bash "$REPORT" --days 30
    [ "$status" -eq 0 ]
    [[ "$output" == *"0.100 reads/session"* ]] || false
    [[ "$output" == *"auto-memory is a second write-only store"* ]] || false
}

@test "excludes the -/ and -private-tmp/ pollution dirs from the session denominator" {
    _seed_session "-Users-noah-dev-cairn" "real-1"
    _seed_hit "real-1" "cairn"
    printf '{}' > "$HOME/.claude/projects/-/pollution-1.jsonl"
    printf '{}' > "$HOME/.claude/projects/-private-tmp/pollution-2.jsonl"

    run bash "$REPORT" --days 30
    [[ "$output" == *"sessions: 1"* ]] || false
}

@test "reports n/a ratio when there is hit data but zero sessions in window" {
    _seed_hit "orphan-session" "cairn"

    run bash "$REPORT" --days 30
    [ "$status" -eq 0 ]
    [[ "$output" == *"n/a"* ]] || false
}

@test "breaks down reads by project" {
    for i in 1 2; do _seed_session "-Users-noah-dev-cairn" "sess-$i"; done
    _seed_hit "sess-1" "ingle"
    _seed_hit "sess-1" "ingle"
    _seed_hit "sess-2" "troth"

    run bash "$REPORT" --days 30
    [[ "$output" == *"ingle"*"2"* ]] || false
    [[ "$output" == *"troth"*"1"* ]] || false
}

@test "defaults to a 30-day window when no --days argument is given" {
    _seed_session "-Users-noah-dev-cairn" "sess-1"
    _seed_hit "sess-1" "cairn"

    run bash "$REPORT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"last 30 days"* ]] || false
}
