#!/usr/bin/env bats
# Tests for hooks/borg-workflow-model-guard.sh — PreToolUse (Workflow) guard that denies agent()
# calls carrying neither agentType: nor model:. Heuristic parse, so it must fail OPEN on anything
# it cannot confidently read.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-workflow-model-guard.sh"
BASH_BIN=bash
[ -x /bin/bash ] && BASH_BIN=/bin/bash
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"

setup() {
    setup_temp_dirs
}

# Feed a workflow script (as tool_input.script) to the hook.
_run_script() {
    local json
    json=$(jq -nc --arg s "$1" '{tool_name:"Workflow", tool_input:{script:$s}}')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$HOOK' 2>&1" _ "$json"
}

@test "pinned via agentType is allowed" {
    _run_script "await agent('find x', { label: 'scan', agentType: 'borg-collective:borg-scout' })"
    [ "$status" -eq 0 ]
}

@test "pinned via model is allowed" {
    _run_script "await agent('write', { model: 'sonnet', effort: 'medium' })"
    [ "$status" -eq 0 ]
}

@test "unpinned agent() is denied, naming the label and line and the fix" {
    _run_script $'const a = 1\nawait agent(`do (this)`, { label: \'scan\' })'
    [ "$status" -eq 2 ]
    [[ "$output" == *"line 2 (label 'scan')"* ]] || false
    [[ "$output" == *"agentType"* ]] || false
    [[ "$output" == *"inherit-ok"* ]] || false
}

@test "only the unpinned call among several is named" {
    _run_script $'await agent(\'a\', { agentType: \'borg-collective:borg-scout\' })\nawait agent(\'b\')\nawait agent(\'c\', { model: \'haiku\' })'
    [ "$status" -eq 2 ]
    [[ "$output" == *"line 2"* ]] || false
    [[ "$output" != *"line 1"* ]] || false
    [[ "$output" != *"line 3"* ]] || false
}

@test "inherit-ok comment inside the call is allowed" {
    _run_script "await agent('hard open-ended', { /* inherit-ok */ label: 'think' })"
    [ "$status" -eq 0 ]
}

@test "options passed as a variable fail open" {
    _run_script "const opts = { label: 'x' }; await agent('p', opts)"
    [ "$status" -eq 0 ]
}

@test "spread options fail open" {
    _run_script "await agent('p', { ...base, label: 'x' })"
    [ "$status" -eq 0 ]
}

@test "unbalanced script fails open" {
    _run_script "await agent('p', { label: 'x' "
    [ "$status" -eq 0 ]
}

@test "agent( inside a string or comment is ignored" {
    _run_script $'// agent(\'x\')\nconst s = "agent(y)"'
    [ "$status" -eq 0 ]
}

@test "scriptPath input is read and checked" {
    printf "await agent('p', { label: 'file-stage' })\n" > "${BATS_TEST_TMPDIR}/wf.js"
    local json
    json=$(jq -nc --arg p "${BATS_TEST_TMPDIR}/wf.js" '{tool_name:"Workflow", tool_input:{scriptPath:$p}}')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$HOOK' 2>&1" _ "$json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"file-stage"* ]] || false
}

@test "unreadable scriptPath fails open" {
    run bash -c "printf '%s' '{\"tool_name\":\"Workflow\",\"tool_input\":{\"scriptPath\":\"/nonexistent/wf.js\"}}' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "saved workflow by name is allowed without inspection" {
    run bash -c "printf '%s' '{\"tool_name\":\"Workflow\",\"tool_input\":{\"name\":\"my-flow\",\"script\":\"agent(1)\"}}' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "malformed JSON fails open" {
    run bash -c "printf '%s' '{not json' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "empty stdin fails open" {
    run bash -c "printf '' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "non-Workflow tool is ignored" {
    run bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"script\":\"agent(1)\"}}' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "BORG_WORKFLOW_MODEL_GUARD=0 disables the guard" {
    export BORG_WORKFLOW_MODEL_GUARD=0
    _run_script "await agent('p')"
    [ "$status" -eq 0 ]
}

@test "wiring: build-plugin.sh copies the hook and registers a Workflow PreToolUse matcher" {
    grep -qE '_build_self_contained_hook .*borg-workflow-model-guard\.sh' "$BUILD_PLUGIN"
    run grep -A6 '"matcher": "Workflow"' "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg-workflow-model-guard.sh"* ]] || false
}

@test "routing guide lives in docs/, not agents/ (agents/ files register as spawnable types)" {
    [ -f "${BATS_TEST_DIRNAME}/../docs/agent-routing.md" ]
    [ ! -e "${BATS_TEST_DIRNAME}/../agents/ROUTING.md" ]
}
