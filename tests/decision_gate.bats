#!/usr/bin/env bats
# Tier 1: hooks/borg-decision-gate.sh (Stop) blocks a final message that asks Noah to decide as plain text when the turn
# made no AskUserQuestion call, and passes everything else. Good and bad transcripts live in tests/fixtures/decision-gate/.
# Why: 2026-10-04, 2026-10-15 and 2026-11-25, terse "Needs Noah: #97" lists instead of AskUserQuestion cards.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-decision-gate.sh"
FIX="${BATS_TEST_DIRNAME}/fixtures/decision-gate"

setup() {
    setup_temp_dirs
}

# _fire <transcript> [stop_hook_active]
_fire() {
    local payload
    payload=$(jq -nc --arg t "$1" --argjson active "${2:-false}" \
        '{hook_event_name:"Stop",session_id:"s1",cwd:"/tmp",transcript_path:$t,stop_hook_active:$active}')
    run bash -c "printf '%s' '$payload' | '$HOOK'"
}

_blocks() {
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]
}

_passes() {
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a Needs Noah list with no AskUserQuestion call is blocked" {
    _fire "$FIX/bad-needs-noah.jsonl"
    _blocks
}

@test "an inline Waits on you after a sentence is blocked" {
    _fire "$FIX/bad-waits-on-you-inline.jsonl"
    _blocks
}

@test "a list of two questions is blocked" {
    _fire "$FIX/bad-question-list.jsonl"
    _blocks
}

@test "an AskUserQuestion in an EARLIER turn does not excuse this one" {
    _fire "$FIX/bad-ask-in-earlier-turn.jsonl"
    _blocks
}

@test "the block reason demands what, why, options with pros and cons, a recommendation first, and a source link" {
    _fire "$FIX/bad-needs-noah.jsonl"
    _blocks
    local reason
    reason=$(printf '%s' "$output" | jq -r .reason)
    [[ "$reason" == *AskUserQuestion* ]]
    [[ "$reason" == *"read nothing this session"* ]]
    [[ "$reason" == *"why it is open"* ]]
    [[ "$reason" == *"pros"* && "$reason" == *"cons"* && "$reason" == *"what choosing it runs"* ]]
    [[ "$reason" == *"(Recommended)"* && "$reason" == *"first"* ]]
    [[ "$reason" == *"source link"* ]]
}

@test "stop_hook_active passes: it never blocks twice in a row" {
    _fire "$FIX/bad-needs-noah.jsonl" true
    _passes
}

@test "a turn that called AskUserQuestion passes even with a Needs Noah recap" {
    _fire "$FIX/good-asked-this-turn.jsonl"
    _passes
}

@test "a report that mentions a past decision and says Needs Noah: none passes" {
    _fire "$FIX/good-report-past-decision.jsonl"
    _passes
}

@test "none variants (Waits on you: nothing, Open questions over None.) pass" {
    _fire "$FIX/good-none-variants.jsonl"
    _passes
}

@test "one closing question is conversation, not a decision list" {
    _fire "$FIX/good-single-closing-question.jsonl"
    _passes
}

@test "quoted and fenced old notes pass" {
    _fire "$FIX/good-quoted-and-fenced.jsonl"
    _passes
}

@test "a plain report passes" {
    _fire "$FIX/good-plain-report.jsonl"
    _passes
}

@test "a turn still in a tool call (no trailing assistant text) passes" {
    _fire "$FIX/good-tool-call-last.jsonl"
    _passes
}

@test "Cortex: history.jsonl beside the .json transcript is read, bad blocks and good passes" {
    _fire "$FIX/cortex-bad.json"
    _blocks
    _fire "$FIX/cortex-good-asked.json"
    _passes
}

@test "fail-open: a missing transcript, empty stdin and garbage stdin all print nothing and exit 0" {
    _fire "/nonexistent/t.jsonl"
    _passes
    run bash -c "printf '' | '$HOOK'"
    _passes
    run bash -c "printf 'not json' | '$HOOK'"
    _passes
}

@test "BORG_NO_SESSION_HOOKS=1 silences it" {
    BORG_NO_SESSION_HOOKS=1 _fire "$FIX/bad-needs-noah.jsonl"
    _passes
}

@test "the plugin registers it on Stop with an empty matcher, and it is copied executable" {
    run grep -c 'hooks/borg-decision-gate.sh' "${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"
    [ "$status" -eq 0 ]
    [ "$output" -ge 2 ]
    [ -x "$HOOK" ]
}
