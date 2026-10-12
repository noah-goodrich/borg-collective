#!/usr/bin/env bats
# Fixture provenance + shape checks for the resume design (slice S0a), and the
# spike-resume-payloads.sh harness contract.
#
# Provenance gate: RESUME_REQUIRE_CAPTURED=S4 (or S4,S7) fails unless every fixture that
# slice lists in required_captured is tagged captured. Unset, that gate is informational
# so the seeded synthetic fixtures do not block this slice.

setup() {
    FX="${BATS_TEST_DIRNAME}/fixtures/resume"
    MAN="$FX/fixtures.json"
    HARNESS="${BATS_TEST_DIRNAME}/../scripts/spike-resume-payloads.sh"
    command -v jq >/dev/null || skip "jq not installed"
}

_not_captured() {
    jq -r --arg s "$1" '. as $m | ($m.required_captured[$s] // ["__undeclared__"])[]
        | select(($m.fixtures[.].tag // "missing") != "captured")' "$MAN"
}

@test "manifest parses and every fixture is tagged captured or synthetic" {
    run jq -e '[.fixtures[].tag] | all(. == "captured" or . == "synthetic")' "$MAN"
    [ "$status" -eq 0 ]
}

@test "every manifest entry points at an existing file" {
    local f
    for f in $(jq -r '.fixtures[].file' "$MAN"); do
        [ -f "$FX/$f" ] || { echo "missing $f"; false; }
    done
}

@test "every file under fixtures/resume is listed in the manifest" {
    local listed actual
    listed="$(jq -r '.fixtures[].file' "$MAN" | sort)"
    actual="$(cd "$FX" && find . -type f ! -name fixtures.json | sed 's#^\./##' | sort)"
    [ "$listed" = "$actual" ]
}

@test "required_captured only references declared fixtures" {
    run jq -r '. as $m | $m.required_captured | to_entries[] | .key as $s | .value[]
        | select($m.fixtures[.] == null) | "\($s): \(.)"' "$MAN"
    [ -z "$output" ]
}

@test "jsonl fixtures: every line is a JSON object" {
    local f
    for f in $(jq -r '.fixtures[] | select(.kind=="jsonl") | .file' "$MAN"); do
        run jq -e 'type == "object"' "$FX/$f"
        [ "$status" -eq 0 ] || { echo "bad jsonl $f"; false; }
    done
}

@test "shape: api_error_tail ends in a synthetic error record" {
    run jq -s -e '.[-1] | .type == "assistant" and .isApiErrorMessage == true and (.error | type == "string")' "$FX/main_rate_limit.jsonl"
    [ "$status" -eq 0 ]
}

@test "shape: error followed by bookkeeping records" {
    run jq -s -e '(map(.isApiErrorMessage // false) | index(true)) as $i | $i != null and (length - $i) > 3' "$FX/main_server_error_tail.jsonl"
    [ "$status" -eq 0 ]
}

@test "shape: interrupt markers end the transcript" {
    local f
    for f in interrupt_user interrupt_tool_use; do
        run jq -s -e '.[-1].message.content[0].text | startswith("[Request interrupted by user")' "$FX/$f.jsonl"
        [ "$status" -eq 0 ]
    done
}

@test "shape: subagent first record and meta" {
    run jq -s -e '.[0] | .type == "user" and .isSidechain == true and (.agentId|length>0) and (.sessionId|length>0) and (.cwd|length>0)' "$FX/subagents/agent-a0b6facb8e5d1b6ac.jsonl"
    [ "$status" -eq 0 ]
    run jq -e 'has("agentType") and has("description") and has("model") and has("spawnDepth") and has("toolUseId")' "$FX/subagents/agent-a0b6facb8e5d1b6ac.meta.json"
    [ "$status" -eq 0 ]
}

@test "shape: workflow manifest and journal" {
    run jq -e 'has("runId") and has("scriptPath") and has("script") and has("args")' "$FX/workflows/wf_ab12cd.json"
    [ "$status" -eq 0 ]
    run jq -s -e 'all(has("event")) and (map(.event) | index("started") != null)' "$FX/workflows/wf_ab12cd.journal.jsonl"
    [ "$status" -eq 0 ]
}

@test "shape: hook payloads carry the common fields" {
    local f
    for f in stop_failure_payload session_start_payload; do
        run jq -e 'has("hook_event_name") and has("session_id") and has("cwd") and has("transcript_path")' "$FX/$f.json"
        [ "$status" -eq 0 ]
    done
    run jq -e 'has("error") and has("error_details") and has("last_assistant_message")' "$FX/stop_failure_payload.json"
    [ "$status" -eq 0 ]
}

@test "fixtures are scrubbed: no real user paths" {
    local bad
    bad="$(grep -rEho '/Users/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)?(/[A-Za-z0-9._-]+)?' "$FX" | grep -v '^/Users/noah/dev/example$' | grep -v '^/Users/noah/dev$' || true)"
    [ -z "$bad" ] || { echo "$bad"; false; }
}

@test "provenance gate logic flags synthetic fixtures" {
    run _not_captured S4
    [[ "$output" == *stop_failure_payload* ]]
}

@test "provenance gate logic flags undeclared slices" {
    run _not_captured S99
    [[ "$output" == *__undeclared__* ]]
}

@test "provenance gate: slices in RESUME_REQUIRE_CAPTURED have captured fixtures" {
    [ -n "${RESUME_REQUIRE_CAPTURED:-}" ] || skip "informational: set RESUME_REQUIRE_CAPTURED=S4,S7,... to enforce"
    local s bad=""
    for s in $(printf '%s' "$RESUME_REQUIRE_CAPTURED" | tr ',' ' '); do
        bad="$bad $(_not_captured "$s" | tr '\n' ' ')"
    done
    [ -z "${bad// /}" ] || { echo "not captured:$bad"; false; }
}

@test "harness: executable and parses under /bin/bash -n" {
    [ -x "$HARNESS" ]
    [ -x /bin/bash ] || skip "no /bin/bash"
    /bin/bash -n "$HARNESS"
}

@test "harness hook: appends a line, exits 0, prints nothing" {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    run "$HARNESS" hook StopFailure < "$FX/stop_failure_payload.json"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run jq -e '.ev == "StopFailure" and .payload.session_id != null' "$BORG_SPIKE_DIR/payloads.jsonl"
    [ "$status" -eq 0 ]
}

@test "harness hook: keeps limit sentence, redacts other text and user paths" {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    printf '%s' '{"session_id":"s","cwd":"/Users/someone/dev/secret","prompt":"my private prompt","last_assistant_message":"hit your session limit · resets 7am"}' \
        | "$HARNESS" hook UserPromptSubmit
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" == *"resets 7am"* ]]
    [[ "$output" != *"private prompt"* ]]
    [[ "$output" != *someone* ]]
    [[ "$output" != *secret* ]]
}

@test "harness hook: garbage and empty stdin still exit 0 silently" {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    run bash -c "printf 'not json{' | '$HARNESS' hook Notification"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run bash -c "'$HARNESS' hook Notification < /dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "harness hook: unwritable scratch dir still exits 0" {
    export BORG_SPIKE_DIR="/proc/nonexistent/x"
    run "$HARNESS" hook SessionEnd < "$FX/session_start_payload.json"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "harness settings: temp file wires all events, nothing global touched" {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    run "$HARNESS" settings
    [ "$status" -eq 0 ]
    [ "$output" = "$BORG_SPIKE_DIR/settings.spike.json" ]
    run jq -e '(.hooks | keys | sort) == ["Notification","PostToolUse","PreToolUse","SessionEnd","SessionStart","StopFailure","SubagentStart","SubagentStop"]
        and (.hooks.PreToolUse[0].matcher == "Agent|Workflow")
        and ([.hooks[][0].hooks[0].timeout] | all(. == 5))' "$BORG_SPIKE_DIR/settings.spike.json"
    [ "$status" -eq 0 ]
}

@test "harness is not installed as a live hook" {
    run grep -rl "spike-resume-payloads" "${BATS_TEST_DIRNAME}/../hooks" "${BATS_TEST_DIRNAME}/../install.sh"
    [ -z "$output" ]
}

@test "harness snap: captures a private tmux pane, scrubbed" {
    command -v tmux >/dev/null || skip "tmux not installed"
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    local sock="borgspike$$" pane out
    tmux -L "$sock" new-session -d -s t "echo /Users/someone/dev/secret; sleep 30"
    sleep 0.7
    pane="$(tmux -L "$sock" list-panes -t t -F '#{pane_id}' | head -1)"
    run env BORG_SPIKE_TMUX_SOCK="$sock" "$HARNESS" snap "$pane" demo
    tmux -L "$sock" kill-server 2>/dev/null || true
    [ "$status" -eq 0 ]
    [ -f "$output" ]
    run cat "$output"
    [[ "$output" == *"/Users/noah/dev/example"* ]]
    [[ "$output" != *someone* ]]
}
