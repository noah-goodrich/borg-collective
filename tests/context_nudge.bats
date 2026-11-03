#!/usr/bin/env bats
# #503 Tier 1: hooks/tool-count-nudge.sh nudges on CONTEXT SIZE read from the file bin/borg-statusline writes, and falls
# back to the 75-call count when that file is missing. Every case runs in a scratch HOME and cache.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/tool-count-nudge.sh"
STATUSLINE="${BATS_TEST_DIRNAME}/../bin/borg-statusline"

setup() {
    setup_temp_dirs
    export XDG_CACHE_HOME="${BATS_TEST_TMPDIR}/cache"
    mkdir -p "$XDG_CACHE_HOME/borg/context"
    unset BORG_CONTEXT_NUDGE_TOKENS
}

_context() {
    printf '{"session_id":"%s","total_input_tokens":%s,"used_percentage":50}\n' "$1" "$2" \
        > "$XDG_CACHE_HOME/borg/context/$1.json"
}

_fire() {
    run bash -c "printf '%s' '{\"session_id\":\"$1\"}' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "context nudge: 130k tokens nudges, and the message names the size" {
    _context s1 130000
    _fire s1
    local ctx
    ctx="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')"
    [[ "$ctx" == *"context is 130k tokens"* ]]
    [[ "$ctx" == *"/borg-review"* && "$ctx" == *"/borg-link-up"* && "$ctx" == *"fresh session"* ]]
    [ "${#ctx}" -lt 400 ]
}

@test "context nudge: 60k tokens stays silent, however many calls" {
    _context s2 60000
    for _ in $(seq 1 80); do _fire s2; [ -z "$output" ]; done
}

@test "context nudge: a missing context file falls back to the 75-call count" {
    printf '74' > "$XDG_CACHE_HOME/borg/tool-count-s3"
    _fire s3
    [[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" == *"75+ tool calls"* ]]
}

@test "context nudge: a present context file replaces the call count" {
    _context s4 60000
    printf '74' > "$XDG_CACHE_HOME/borg/tool-count-s4"
    _fire s4
    [ -z "$output" ]
}

@test "context nudge: nudges once at 120k, again at +40k, and not in between" {
    _context s5 125000
    _fire s5; [ -n "$output" ]
    _context s5 150000
    _fire s5; [ -z "$output" ]
    _context s5 159999
    _fire s5; [ -z "$output" ]
    _context s5 160000
    _fire s5; [ -n "$output" ]
    _fire s5; [ -z "$output" ]
    _context s5 205000
    _fire s5; [[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" == *"205k"* ]]
}

@test "context nudge: a compaction (context shrinks) re-arms the nudge" {
    _context s6 170000
    _fire s6; [ -n "$output" ]
    _context s6 30000
    _fire s6; [ -z "$output" ]
    _context s6 125000
    _fire s6; [ -n "$output" ]
}

@test "context nudge: BORG_CONTEXT_NUDGE_TOKENS moves the threshold" {
    export BORG_CONTEXT_NUDGE_TOKENS=50000
    _context s7 60000
    _fire s7; [ -n "$output" ]
}

@test "context nudge: a garbage context file or a bad threshold falls back to the count, never errors" {
    printf 'not json' > "$XDG_CACHE_HOME/borg/context/s8.json"
    _fire s8; [ -z "$output" ]
    _context s9 130000
    export BORG_CONTEXT_NUDGE_TOKENS=lots
    _fire s9; [ -z "$output" ]
}

@test "context nudge: a session id cannot escape the context directory" {
    _context s10 130000
    run bash -c "printf '%s' '{\"session_id\":\"../../etc/x\"}' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "context nudge: the statusline's own output feeds the hook end to end" {
    export PATH="$HOME/bin:$PATH"
    printf '{"session_id":"e2e","model":{"display_name":"Opus"},"context_window":{"used_percentage":65.5,"total_input_tokens":131000}}' \
        | bash "$STATUSLINE" > /dev/null
    [ "$(jq -r '.total_input_tokens' "$XDG_CACHE_HOME/borg/context/e2e.json")" = "131000" ]
    _fire e2e
    [[ "$output" == *"131k"* ]]
}
