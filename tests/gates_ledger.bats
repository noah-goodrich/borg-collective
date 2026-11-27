#!/usr/bin/env bats
# Tests for hooks/borg-gates-ledger.sh -- PreToolUse (Edit|Write|MultiEdit): in a session where /borg-review ran in
# gates mode, the first edit is denied until a G1..G5 ledger (or the trivial line) was printed as assistant text.
# Issue #510. Transcripts are synthetic Claude JSONL; the slash-command record shape is the one measured in a real
# headless run (<command-name>/borg-collective:borg-review</command-name> plus <command-args>).

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-gates-ledger.sh"
BASH_BIN=bash
[ -x /bin/bash ] && BASH_BIN=/bin/bash

LEDGER=$'G1 scope:     add a deny case\nG2 evidence:  opened hooks/guard.sh\nG3 adversary: none\nG4 verify:    bash tests/test_guard.sh\nG5 calibrate: small'

setup() {
    setup_temp_dirs
    mkdir -p "$XDG_STATE_HOME"
    T="${BATS_TEST_TMPDIR}/t.jsonl"
    : > "$T"
}

# _user <text>: a real user message
_user() { jq -nc --arg t "$1" '{type:"user",message:{role:"user",content:$t}}' >> "$T"; }
# _slash <skill> <args>: how a slash-invoked skill lands in the transcript
_slash() {
    jq -nc --arg t "<command-message>$1</command-message>
<command-name>/$1</command-name>
<command-args>$2</command-args>" '{type:"user",message:{role:"user",content:$t}}' >> "$T"
}
# _text <text>: an assistant text block
_text() { jq -nc --arg t "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$t}]}}' >> "$T"; }
# _thinking <text>: an assistant thinking block (must NOT count)
_thinking() { jq -nc --arg t "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"thinking",thinking:$t}]}}' >> "$T"; }
# _skill <skill> <args>: a model-issued Skill tool call
_skill() {
    jq -nc --arg s "$1" --arg a "$2" \
        '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",name:"Skill",input:{skill:$s,args:$a}}]}}' >> "$T"
}

# _edit [tool_name] [extra-json]: run the hook the way Claude Code does
_edit() {
    local json extra='{}'
    [ -n "${2:-}" ] && extra="$2"
    json=$(jq -nc --arg tp "$T" --arg tn "${1:-Edit}" --argjson extra "$extra" \
        '{session_id:"s1", transcript_path:$tp, tool_name:$tn, tool_input:{file_path:"/x/a.sh"}} + $extra')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$HOOK' 2>&1" _ "$json"
}

@test "gates mode, no ledger: the edit is denied and the reason says what to print" {
    _slash borg-collective:borg-review 'Apply the gates. Then change hooks/guard.sh'
    _text "I will read the files."
    _edit
    [ "$status" -eq 2 ]
    [[ "$output" == *"G1 scope:"* && "$output" == *"G5 calibrate:"* && "$output" == *"visible text block"* ]]
    [[ "$output" == *"Gates: trivial"* ]]
    [[ "$output" == *"BORG_GATES_LEDGER=0"* ]]
}

@test "gates mode, G1-G5 ledger printed: the edit passes" {
    _slash borg-collective:borg-review 'Apply the gates. Then change hooks/guard.sh'
    _text "$LEDGER"
    _edit
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "gates mode, ledger inside a code fence: the edit passes" {
    _slash borg-collective:borg-review 'Apply the gates.'
    _text $'```\n'"$LEDGER"$'\n```'
    _edit Write
    [ "$status" -eq 0 ]
}

@test "gates mode, the trivial line: the edit passes" {
    _slash borg-collective:borg-review 'Fable mode. Fix the typo in README.md'
    _text $'Gates: trivial — G1+G5 only.'
    _edit MultiEdit
    [ "$status" -eq 0 ]
}

@test "gates mode, an incomplete ledger (G1 and G5 only): denied" {
    _slash borg-collective:borg-review 'Apply the gates.'
    _text $'G1 scope:     x\nG5 calibrate: y'
    _edit
    [ "$status" -eq 2 ]
}

@test "gates mode, the ledger only in thinking: denied" {
    _slash borg-collective:borg-review 'Apply the gates.'
    _thinking "$LEDGER"
    _edit
    [ "$status" -eq 2 ]
}

@test "gates mode, a ledger printed BEFORE the invocation does not count" {
    _text "$LEDGER"
    _slash borg-collective:borg-review 'Apply the gates.'
    _edit
    [ "$status" -eq 2 ]
}

@test "model-issued Skill call with the trigger in args: denied; with a ledger after it: allowed" {
    _user "please go on"
    _skill borg-collective:borg-review "apply the gates"
    _edit
    [ "$status" -eq 2 ]
    _text "$LEDGER"
    _edit
    [ "$status" -eq 0 ]
}

@test "Skill call with empty args takes the trigger from the last user message" {
    _user "fable mode: rename the helper"
    _skill borg-collective:borg-review ""
    _edit
    [ "$status" -eq 2 ]
}

@test "the old /fable-reviewer slash command is gates mode too" {
    _slash borg-collective:fable-reviewer 'Apply the gates.'
    _edit
    [ "$status" -eq 2 ]
}

@test "outside gates mode: plain /borg-review (diagnostic) is untouched" {
    _slash borg-collective:borg-review 'am I going in circles?'
    _edit
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "outside gates mode: no borg-review at all, and the phrase alone is not a trigger" {
    _user "apply the gates to this change"
    _edit
    [ "$status" -eq 0 ]
}

@test "outside gates mode: a different skill whose args say 'apply the gates'" {
    _slash borg-collective:borg-plan 'apply the gates'
    _edit
    [ "$status" -eq 0 ]
}

@test "a non-edit tool is never denied" {
    _slash borg-collective:borg-review 'Apply the gates.'
    _edit Read
    [ "$status" -eq 0 ]
    _edit Bash
    [ "$status" -eq 0 ]
}

@test "a subagent edit is never denied" {
    _slash borg-collective:borg-review 'Apply the gates.'
    _edit Edit '{"agent_id":"a1","agent_type":"borg-collective:borg-grunt"}'
    [ "$status" -eq 0 ]
}

@test "kill switch BORG_GATES_LEDGER=0 allows" {
    _slash borg-collective:borg-review 'Apply the gates.'
    export BORG_GATES_LEDGER=0
    _edit
    [ "$status" -eq 0 ]
}

@test "fail open: missing transcript, unreadable payload, Cortex .json transcript" {
    run bash -c "printf '%s' '{\"tool_name\":\"Edit\",\"transcript_path\":\"/nonexistent/t.jsonl\"}' | '$BASH_BIN' '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    run bash -c "printf '%s' 'not json transcript_path' | '$BASH_BIN' '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    run bash -c "printf '%s' '{}' | '$BASH_BIN' '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    _slash borg-collective:borg-review 'Apply the gates.'
    mv "$T" "${T%.jsonl}.json"
    T="${T%.jsonl}.json"
    _edit
    [ "$status" -eq 0 ]
}

@test "after the denial cap the edit passes, so an unseen ledger cannot wedge a session" {
    _slash borg-collective:borg-review 'Apply the gates.'
    export BORG_GATES_LEDGER_MAX_DENIALS=3
    _edit
    [ "$status" -eq 2 ]
    _edit
    [ "$status" -eq 2 ]
    _edit
    [ "$status" -eq 2 ]
    _edit
    [ "$status" -eq 0 ]
}

@test "a second gates invocation needs its own ledger" {
    _slash borg-collective:borg-review 'Apply the gates.'
    _text "$LEDGER"
    _edit
    [ "$status" -eq 0 ]
    _slash borg-collective:borg-review 'Fable mode, next change'
    _edit
    [ "$status" -eq 2 ]
}

@test "the hook is registered for Edit|Write|MultiEdit in HOOKS_JSON and built by build-plugin.sh" {
    run grep -c 'borg-gates-ledger.sh' "${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"
    [ "$output" -ge 2 ]
    run grep -B5 'borg-gates-ledger.sh",' "${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"
    [[ "$output" == *'"matcher": "Edit|Write|MultiEdit"'* ]] || [[ "$output" == *'Edit|Write|MultiEdit'* ]]
}
